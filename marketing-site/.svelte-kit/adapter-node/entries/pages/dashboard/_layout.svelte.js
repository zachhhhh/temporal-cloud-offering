import { X as store_get, Z as unsubscribe_stores } from "../../../chunks/index2.js";
import { a as auth } from "../../../chunks/auth.js";
import { g as goto } from "../../../chunks/client.js";
function _layout($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    var $$store_subs;
    if (typeof window !== "undefined" && !store_get($$store_subs ??= {}, "$auth", auth)) {
      goto();
    }
    $$renderer2.push(`<div class="min-h-screen bg-black flex items-center justify-center"><div class="text-center"><div class="animate-spin w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full mx-auto mb-4"></div> <p class="text-zinc-400">Redirecting to Temporal Cloud...</p></div></div>`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _layout as default
};
