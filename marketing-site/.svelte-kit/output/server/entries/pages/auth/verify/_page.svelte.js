import { U as head } from "../../../../chunks/index2.js";
import "@sveltejs/kit/internal";
import "../../../../chunks/exports.js";
import "../../../../chunks/utils.js";
import "clsx";
import "@sveltejs/kit/internal/server";
import "../../../../chunks/state.svelte.js";
import "../../../../chunks/auth.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    head("1xy6sat", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Verifying... | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="min-h-screen bg-[#0d0620] flex items-center justify-center p-4"><div class="w-full max-w-md text-center">`);
    {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<div class="animate-spin w-12 h-12 border-4 border-emerald-400 border-t-transparent rounded-full mx-auto mb-4"></div> <h1 class="text-xl font-semibold text-white">Verifying your sign-in link...</h1> <p class="text-zinc-400 mt-2">Please wait a moment</p>`);
    }
    $$renderer2.push(`<!--]--></div></div>`);
  });
}
export {
  _page as default
};
