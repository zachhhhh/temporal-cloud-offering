import { e as escape_html } from "../../../../chunks/escaping.js";
import "clsx";
import { c as config } from "../../../../chunks/config.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    const APP_URL = config.urls.app;
    $$renderer2.push(`<div class="min-h-screen flex items-center justify-center bg-[#0d0620] text-zinc-300"><div class="text-center space-y-2"><div class="animate-spin w-10 h-10 border-2 border-emerald-400 border-t-transparent rounded-full mx-auto" aria-label="Redirecting to Namespaces"></div> <p>Opening Namespaces in Temporal Cloud Console…</p> <p class="text-xs text-zinc-500">${escape_html(APP_URL)}</p></div></div>`);
  });
}
export {
  _page as default
};
