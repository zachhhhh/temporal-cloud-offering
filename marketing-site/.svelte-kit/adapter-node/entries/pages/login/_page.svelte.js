import { U as head, W as attr, $ as attr_class, _ as stringify } from "../../../chunks/index2.js";
import "@sveltejs/kit/internal";
import "../../../chunks/exports.js";
import "../../../chunks/utils.js";
import "@sveltejs/kit/internal/server";
import "../../../chunks/state.svelte.js";
import "../../../chunks/auth.js";
import { e as escape_html } from "../../../chunks/context.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let email = "";
    let loading = false;
    head("1x05zx6", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Sign In | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="min-h-screen bg-[#0d0620] flex items-center justify-center p-4"><div class="w-full max-w-md"><div class="text-center mb-8"><a href="/" class="inline-flex items-center gap-2"><svg class="w-10 h-10" viewBox="0 0 32 32" fill="none"><path d="M16 0C7.163 0 0 7.163 0 16s7.163 16 16 16 16-7.163 16-16S24.837 0 16 0z" fill="white"></path><path d="M16 4c-6.627 0-12 5.373-12 12s5.373 12 12 12 12-5.373 12-12S22.627 4 16 4zm0 2c5.523 0 10 4.477 10 10s-4.477 10-10 10S6 21.523 6 16 10.477 6 16 6z" fill="#0d0620"></path><path d="M16 8v8l6 3" stroke="#0d0620" stroke-width="2" stroke-linecap="round"></path></svg> <span class="text-2xl font-semibold text-white">Temporal Cloud</span></a></div> <div class="bg-zinc-900/50 border border-zinc-800 rounded-2xl p-8"><h1 class="text-xl font-semibold text-white text-center mb-6">Sign in to your account</h1> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> <div class="space-y-3 mb-6"><button${attr("disabled", loading, true)} class="w-full flex items-center justify-center gap-3 px-4 py-3 bg-white hover:bg-gray-100 text-gray-800 font-medium rounded-lg transition-colors disabled:opacity-50"><svg class="w-5 h-5" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"></path><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"></path><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"></path><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"></path></svg> Continue with Google</button></div> <div class="relative mb-6"><div class="absolute inset-0 flex items-center"><div class="w-full border-t border-zinc-700"></div></div> <div class="relative flex justify-center text-sm"><span class="px-2 bg-zinc-900/50 text-zinc-500">or continue with email</span></div></div> <div class="flex mb-4 bg-zinc-800 rounded-lg p-1"><button type="button"${attr_class(`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${stringify(
      "bg-zinc-700 text-white"
    )}`)}>Magic Link</button> <button type="button"${attr_class(`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${stringify("text-zinc-400 hover:text-white")}`)}>Password</button></div> <form class="space-y-4"><div><label for="email" class="block text-sm text-zinc-400 mb-1">Email address</label> <input id="email" type="email"${attr("value", email)} placeholder="you@example.com" class="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"/></div> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> <button type="submit"${attr("disabled", !email, true)} class="w-full py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed">`);
    {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`${escape_html("Send Magic Link")}`);
    }
    $$renderer2.push(`<!--]--></button> `);
    {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<p class="text-xs text-zinc-500 text-center">We'll send you a secure sign-in link. No password needed.</p>`);
    }
    $$renderer2.push(`<!--]--></form> <p class="mt-6 text-center text-xs text-zinc-500">By signing in, you agree to our <a href="/terms" class="text-indigo-400 hover:underline">Terms of Service</a> and <a href="/privacy" class="text-indigo-400 hover:underline">Privacy Policy</a></p></div> <p class="mt-6 text-center text-sm text-zinc-500"><a href="/" class="text-indigo-400 hover:underline">← Back to home</a></p></div></div>`);
  });
}
export {
  _page as default
};
