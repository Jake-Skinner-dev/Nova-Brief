-- =====================================================================
-- NOVA BRIEF - article view counts.
-- Run once in Supabase Studio -> SQL Editor. Safe to re-run.
-- (Also included in brief-supabase-setup.sql for fresh installs.)
--
-- How it works: every article page calls brief_track_view(slug) once per
-- browser session. That bumps a per-day counter. Nothing identifying is
-- stored - just slug + date + count. The public (anon) key can ONLY call
-- the counter function; it cannot read or edit the table. The editor
-- reads the totals in /admin/ via brief_article_view_stats().
-- =====================================================================

create table if not exists public.brief_article_views (
  slug text not null,
  day date not null default ((now() at time zone 'utc')::date),
  views integer not null default 0,
  primary key (slug, day)
);

alter table public.brief_article_views enable row level security;
drop policy if exists "brief_article_views editor read" on public.brief_article_views;
create policy "brief_article_views editor read" on public.brief_article_views
  for select to authenticated using (public.brief_is_editor());

-- Public: count one view. Ignores slugs that aren't a published article, so
-- junk requests can't fill the table.
create or replace function public.brief_track_view(p_slug text)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if not exists (
    select 1 from public.brief_articles a where a.slug = p_slug and a.status = 'published'
  ) then
    return;
  end if;
  insert into public.brief_article_views as v (slug, day, views)
  values (p_slug, (now() at time zone 'utc')::date, 1)
  on conflict (slug, day) do update set views = v.views + 1;
end
$fn$;

revoke all on function public.brief_track_view(text) from public;
grant execute on function public.brief_track_view(text) to anon, authenticated;

-- Editor only: per-article totals.
create or replace function public.brief_article_view_stats()
returns table (slug text, total bigint, views_7d bigint, views_30d bigint)
language plpgsql security definer set search_path = public as $fn$
begin
  if not public.brief_is_editor() then
    raise exception 'not allowed';
  end if;
  return query
    select v.slug,
           sum(v.views)::bigint,
           coalesce(sum(v.views) filter (where v.day >= ((now() at time zone 'utc')::date - 6)), 0)::bigint,
           coalesce(sum(v.views) filter (where v.day >= ((now() at time zone 'utc')::date - 29)), 0)::bigint
    from public.brief_article_views v
    group by v.slug;
end
$fn$;

revoke all on function public.brief_article_view_stats() from public;
grant execute on function public.brief_article_view_stats() to authenticated;

-- Editor only: total views per day for the last N days (for the chart).
create or replace function public.brief_view_daily(p_days integer default 14)
returns table (day date, views bigint)
language plpgsql security definer set search_path = public as $fn$
begin
  if not public.brief_is_editor() then
    raise exception 'not allowed';
  end if;
  return query
    select d::date, coalesce(sum(v.views), 0)::bigint
    from generate_series(
           ((now() at time zone 'utc')::date - (greatest(p_days, 1) - 1)),
           (now() at time zone 'utc')::date,
           interval '1 day') d
    left join public.brief_article_views v on v.day = d::date
    group by d
    order by d;
end
$fn$;

revoke all on function public.brief_view_daily(integer) from public;
grant execute on function public.brief_view_daily(integer) to authenticated;
