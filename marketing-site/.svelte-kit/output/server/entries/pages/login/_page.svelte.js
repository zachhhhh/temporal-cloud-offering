import { X as store_get, U as head, W as attr, Z as unsubscribe_stores } from "../../../chunks/index2.js";
import "@sveltejs/kit/internal";
import "../../../chunks/exports.js";
import "../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../chunks/state.svelte.js";
import { g as getContext } from "../../../chunks/context.js";
import "clsx";
import { e as escape_html } from "../../../chunks/escaping.js";
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
    let successMessage;
    let email = "";
    let password = "";
    let loading = false;
    successMessage = store_get($$store_subs ??= {}, "$page", page).url.searchParams.get("message") === "account_created" ? "Account created successfully! You can now sign in." : "";
    head("1x05zx6", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Sign In | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="min-h-screen flex items-center justify-center bg-[#0d0620]"><div class="w-full max-w-md p-8 space-y-6 bg-zinc-900/50 rounded-xl border border-zinc-800"><div class="text-center"><h1 class="text-2xl font-bold text-white">Sign in to Temporal Cloud</h1> <p class="mt-2 text-sm text-zinc-400">Access your workflows and namespaces</p></div> `);
    if (successMessage) {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<div class="p-3 text-sm text-emerald-400 bg-emerald-500/10 rounded-lg border border-emerald-500/20">${escape_html(successMessage)}</div>`);
    } else {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> <button class="w-full flex items-center justify-center gap-3 px-4 py-3 text-white bg-zinc-800 hover:bg-zinc-700 rounded-lg border border-zinc-700 transition-colors"><svg class="w-5 h-5" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"></path><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"></path><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"></path><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"></path></svg> Continue with Google</button> <div class="relative"><div class="absolute inset-0 flex items-center"><div class="w-full border-t border-zinc-700"></div></div> <div class="relative flex justify-center text-sm"><span class="px-2 text-zinc-500 bg-[#0d0620]">or continue with email</span></div></div> <form class="space-y-4"><div><label for="email" class="block text-sm font-medium text-zinc-300">Email</label> <input type="email" id="email"${attr("value", email)} required class="mt-1 w-full px-4 py-2 bg-zinc-800 border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" placeholder="you@company.com"/></div> <div><label for="password" class="block text-sm font-medium text-zinc-300">Password</label> <input type="password" id="password"${attr("value", password)} required class="mt-1 w-full px-4 py-2 bg-zinc-800 border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" placeholder="••••••••"/></div> <button type="submit"${attr("disabled", loading, true)} class="w-full py-3 px-4 bg-emerald-600 hover:bg-emerald-500 disabled:bg-emerald-800 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-colors">${escape_html("Sign in")}</button></form> <p class="text-center text-sm text-zinc-500">Don't have an account? <a href="/signup" class="text-emerald-400 hover:text-emerald-300">Sign up</a></p></div></div>`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _page as default
};
