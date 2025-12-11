import { e as escape_html } from "../../../chunks/escaping.js";
import "clsx";
import { c as config } from "../../../chunks/config.js";
function _layout($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    const APP_URL = config.urls.app;
    $$renderer2.push(`<div class="min-h-screen bg-black flex items-center justify-center"><div class="text-center"><div class="animate-spin w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full mx-auto mb-4"></div> <p class="text-zinc-400">Redirecting to Temporal Cloud Console...</p> <p class="text-xs text-zinc-600 mt-2">${escape_html(APP_URL)}</p></div></div>`);
  });
}
export {
  _layout as default
};
