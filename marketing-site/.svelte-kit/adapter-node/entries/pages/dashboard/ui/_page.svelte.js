import { X as store_get, U as head, W as attr, Z as unsubscribe_stores } from "../../../../chunks/index2.js";
import { c as config } from "../../../../chunks/config.js";
import { g as getContext, e as escape_html } from "../../../../chunks/context.js";
import "clsx";
import "@sveltejs/kit/internal";
import "../../../../chunks/exports.js";
import "../../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../../chunks/state.svelte.js";
const getStores = () => {
  const stores$1 = getContext("__svelte__");
  return {
    /** @type {typeof page} */
    page: {
      subscribe: stores$1.page.subscribe
    },
    /** @type {typeof navigating} */
    navigating: {
      subscribe: stores$1.navigating.subscribe
    },
    /** @type {typeof updated} */
    updated: stores$1.updated
  };
};
const page = {
  subscribe(fn) {
    const store = getStores().page;
    return store.subscribe(fn);
  }
};
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    var $$store_subs;
    let namespace, uiUrl;
    namespace = store_get($$store_subs ??= {}, "$page", page).url.searchParams.get("namespace") || "";
    uiUrl = namespace ? `${config.urls.temporalUI}/namespaces/${namespace}` : config.urls.temporalUI;
    head("1t533yk", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Temporal UI | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="h-screen w-full flex flex-col bg-black"><div class="flex items-center justify-between px-4 py-2 bg-zinc-900 border-b border-zinc-800"><div class="flex items-center gap-4"><h1 class="text-sm font-medium text-white">Temporal UI</h1> `);
    if (namespace) {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<span class="text-xs text-zinc-500">Namespace: ${escape_html(namespace)}</span>`);
    } else {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--></div> <a${attr("href", uiUrl)} target="_blank" rel="noopener noreferrer" class="flex items-center gap-2 px-3 py-1.5 text-xs bg-indigo-600 hover:bg-indigo-700 text-white rounded transition-colors"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg> Open Temporal UI</a></div> `);
    {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`<iframe${attr("src", uiUrl)} title="Temporal UI" class="flex-1 w-full border-0" allow="clipboard-read; clipboard-write"></iframe>`);
    }
    $$renderer2.push(`<!--]--></div>`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _page as default
};
