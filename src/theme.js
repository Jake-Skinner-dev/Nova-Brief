// Light / dark theme toggle. The initial theme is set before first paint
// by the inline script in src/partials/head-common.html; this module keeps
// it in sync, persists the choice, and wires every [data-theme-toggle]
// button (there's one in the masthead and one in the mobile drawer).

const KEY = "nova-brief-theme";
const THEME_COLOR = { light: "#FBFAF7", dark: "#131317" };

function readStored() {
  try {
    const v = localStorage.getItem(KEY);
    return v === "dark" || v === "light" ? v : null;
  } catch {
    return null;
  }
}

export function initTheme() {
  const root = document.documentElement;
  const meta = document.querySelector('meta[name="theme-color"]');

  const apply = (t) => {
    root.setAttribute("data-theme", t);
    if (meta) meta.setAttribute("content", THEME_COLOR[t] || THEME_COLOR.light);
    document.querySelectorAll("[data-theme-toggle]").forEach((btn) => {
      btn.setAttribute("aria-pressed", String(t === "dark"));
      btn.setAttribute("aria-label", t === "dark" ? "Switch to light theme" : "Switch to dark theme");
      const label = btn.querySelector("[data-theme-label]");
      if (label) label.textContent = t === "dark" ? "Light mode" : "Dark mode";
    });
  };

  const initial =
    readStored() ||
    root.getAttribute("data-theme") ||
    (window.matchMedia && matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
  apply(initial);

  document.querySelectorAll("[data-theme-toggle]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      try {
        localStorage.setItem(KEY, next);
      } catch {}
      apply(next);
    });
  });

  // Follow the OS if the visitor hasn't made an explicit choice.
  if (!readStored() && window.matchMedia) {
    matchMedia("(prefers-color-scheme: dark)").addEventListener?.("change", (e) => {
      if (!readStored()) apply(e.matches ? "dark" : "light");
    });
  }
}
