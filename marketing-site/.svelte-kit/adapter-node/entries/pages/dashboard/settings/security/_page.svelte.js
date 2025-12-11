import { U as head, X as store_get, W as attr, Z as unsubscribe_stores } from "../../../../../chunks/index2.js";
import { a as auth } from "../../../../../chunks/auth.js";
import { e as escape_html } from "../../../../../chunks/context.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    var $$store_subs;
    let currentPassword = "";
    let newPassword = "";
    let confirmPassword = "";
    let loading = false;
    head("1ewmk9s", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Security Settings | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="min-h-screen p-6 text-slate-100"><div class="max-w-2xl mx-auto"><h1 class="text-2xl font-medium mb-2">Security Settings</h1> <p class="text-zinc-400 mb-8">Manage your password and security preferences</p> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> <div class="bg-zinc-900 border border-zinc-800 rounded-xl p-6"><h2 class="text-lg font-semibold mb-4">${escape_html(store_get($$store_subs ??= {}, "$auth", auth)?.provider === "email" ? "Set Password" : "Password")}</h2> `);
    if (store_get($$store_subs ??= {}, "$auth", auth)?.provider === "google") {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<p class="text-zinc-400 text-sm mb-4">You signed in with Google. You can set a password to also sign in with email.</p>`);
    } else {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`<p class="text-zinc-400 text-sm mb-4">Set a password to sign in with your email and password instead of magic links.</p>`);
    }
    $$renderer2.push(`<!--]--> <form class="space-y-4">`);
    if (store_get($$store_subs ??= {}, "$auth", auth)?.hasPassword) {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<div><label for="current-password" class="block text-sm font-medium text-zinc-300 mb-2">Current Password</label> <input type="password" id="current-password"${attr("value", currentPassword)} class="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" placeholder="Enter current password"/></div>`);
    } else {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> <div><label for="new-password" class="block text-sm font-medium text-zinc-300 mb-2">${escape_html(store_get($$store_subs ??= {}, "$auth", auth)?.hasPassword ? "New Password" : "Password")}</label> <input type="password" id="new-password"${attr("value", newPassword)} class="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" placeholder="Enter password (min 8 characters)" minlength="8" required/></div> <div><label for="confirm-password" class="block text-sm font-medium text-zinc-300 mb-2">Confirm Password</label> <input type="password" id="confirm-password"${attr("value", confirmPassword)} class="w-full px-4 py-3 bg-zinc-800 border border-zinc-700 rounded-lg text-white placeholder-zinc-500 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent" placeholder="Confirm password" minlength="8" required/></div> <button type="submit"${attr("disabled", loading, true)} class="w-full py-3 bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed rounded-lg font-medium transition-colors flex items-center justify-center gap-2">`);
    {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`${escape_html(store_get($$store_subs ??= {}, "$auth", auth)?.hasPassword ? "Update Password" : "Set Password")}`);
    }
    $$renderer2.push(`<!--]--></button></form></div> <div class="mt-6 bg-zinc-900 border border-zinc-800 rounded-xl p-6"><h2 class="text-lg font-semibold mb-4">Connected Accounts</h2> <div class="space-y-3"><div class="flex items-center justify-between p-3 bg-zinc-800/50 rounded-lg"><div class="flex items-center gap-3"><svg class="w-5 h-5" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"></path><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"></path><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"></path><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"></path></svg> <div><p class="font-medium">Google</p> <p class="text-sm text-zinc-500">${escape_html(store_get($$store_subs ??= {}, "$auth", auth)?.provider === "google" ? store_get($$store_subs ??= {}, "$auth", auth).email : "Not connected")}</p></div></div> `);
    if (store_get($$store_subs ??= {}, "$auth", auth)?.provider === "google") {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<span class="px-3 py-1 bg-emerald-500/10 text-emerald-400 text-sm rounded-full">Connected</span>`);
    } else {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`<a href="/api/auth/google" class="px-3 py-1 bg-zinc-700 hover:bg-zinc-600 text-sm rounded-lg transition-colors">Connect</a>`);
    }
    $$renderer2.push(`<!--]--></div> <div class="flex items-center justify-between p-3 bg-zinc-800/50 rounded-lg"><div class="flex items-center gap-3"><svg class="w-5 h-5 text-zinc-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg> <div><p class="font-medium">Email &amp; Password</p> <p class="text-sm text-zinc-500">${escape_html(store_get($$store_subs ??= {}, "$auth", auth)?.email)}</p></div></div> `);
    if (store_get($$store_subs ??= {}, "$auth", auth)?.hasPassword) {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<span class="px-3 py-1 bg-emerald-500/10 text-emerald-400 text-sm rounded-full">Enabled</span>`);
    } else {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`<span class="px-3 py-1 bg-zinc-700 text-zinc-400 text-sm rounded-full">Not set</span>`);
    }
    $$renderer2.push(`<!--]--></div></div></div></div></div>`);
    if ($$store_subs) unsubscribe_stores($$store_subs);
  });
}
export {
  _page as default
};
