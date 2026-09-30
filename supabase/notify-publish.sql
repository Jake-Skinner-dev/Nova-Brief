-- =====================================================================
-- NOVA BRIEF - instant rebuild trigger.
-- Run once in Supabase Studio -> SQL Editor, after replacing the token
-- placeholder below. Safe to re-run (create-or-replace / drop-if-exists).
--
-- What it does: the moment a brief_articles row becomes 'published'
-- (a fresh insert already published, or an existing row's status flips to
-- 'published'), it pings GitHub to fire the "Rebuild Nova Brief pages"
-- workflow immediately - see .github/workflows/rebuild.yml's
-- repository_dispatch trigger - instead of waiting on the 30-min/several-
-- hour schedule. That workflow still only updates the GitHub repo; you
-- (or a cPanel Cron Job - see brief/README.md) still need to deploy
-- dist/ to the live document root.
--
-- Needs a GitHub Personal Access Token scoped to ONLY this repo
-- (Jake-Skinner-dev/Nova-Brief) with "Contents: Read and write" repo
-- permission. Create one at:
--   https://github.com/settings/personal-access-tokens/new
-- Paste it in place of GITHUB_TOKEN_PLACEHOLDER below before running.
-- It lives inside this function's source in your own Supabase project -
-- nobody without access to this project can see it. Rotate it here
-- (re-run this whole file with the new token) whenever it expires.
-- =====================================================================

create extension if not exists pg_net with schema extensions;

create or replace function public.brief_notify_publish()
returns trigger language plpgsql security definer as $fn$
begin
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    perform net.http_post(
      url := 'https://api.github.com/repos/Jake-Skinner-dev/Nova-Brief/dispatches',
      headers := jsonb_build_object(
        'Authorization', 'Bearer GITHUB_TOKEN_PLACEHOLDER',
        'Accept', 'application/vnd.github+json',
        'Content-Type', 'application/json',
        'User-Agent', 'nova-brief-supabase-trigger'
      ),
      body := jsonb_build_object('event_type', 'brief-published')
    );
  end if;
  return new;
end;
$fn$;

drop trigger if exists brief_articles_notify_publish on public.brief_articles;
create trigger brief_articles_notify_publish
  after insert or update on public.brief_articles
  for each row execute function public.brief_notify_publish();
