import { U as head } from "../../../chunks/index.js";
import { c as config } from "../../../chunks/config.js";
import { e as escape_html } from "../../../chunks/escaping.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    const APP_URL = config.urls.app;
    const LOGIN_URL = `${APP_URL.replace(/\/$/, "")}/auth/signin`;
    head("1x05zx6", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Sign In | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="min-h-screen flex items-center justify-center bg-[#0d0620] text-zinc-300"><div class="text-center space-y-2"><div class="animate-spin w-10 h-10 border-2 border-emerald-400 border-t-transparent rounded-full mx-auto" aria-label="Redirecting to sign in"></div> <p>Sending you to Temporal Cloud sign-in…</p> <p class="text-xs text-zinc-500">${escape_html(LOGIN_URL)}</p></div></div>`);
  });
}
export {
  _page as default
};
