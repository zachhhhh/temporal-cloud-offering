import { U as head, W as attr } from "../../../../chunks/index2.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let orgName = "My Organization";
    let email = "admin@example.com";
    let saving = false;
    head("a30v8d", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Settings | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="min-h-screen p-6 text-slate-100"><div class="max-w-2xl mx-auto"><h1 class="text-2xl font-medium mb-8">Settings</h1> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> <div class="bg-zinc-900 border border-zinc-800 rounded-xl p-6 mb-6"><h2 class="text-lg font-semibold mb-4">Organization</h2> <div class="space-y-4"><div><label class="block text-sm text-zinc-400 mb-1">Organization Name</label> <input${attr("value", orgName)} class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg text-white focus:outline-none focus:border-indigo-500"/></div> <div><label class="block text-sm text-zinc-400 mb-1">Admin Email</label> <input${attr("value", email)} type="email" class="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg text-white focus:outline-none focus:border-indigo-500"/></div></div></div> <div class="bg-zinc-900 border border-zinc-800 rounded-xl p-6 mb-6"><h2 class="text-lg font-semibold mb-4">API Access</h2> <div class="space-y-4"><div><label class="block text-sm text-zinc-400 mb-1">Organization ID</label> <div class="flex gap-2"><input value="demo-org" readonly class="flex-1 px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg text-zinc-400"/> <button class="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 rounded-lg transition-colors"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg></button></div></div> <div><label class="block text-sm text-zinc-400 mb-1">API Endpoint</label> <div class="flex gap-2"><input value="https://api.temporal.cloud" readonly class="flex-1 px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg text-zinc-400"/> <button class="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 rounded-lg transition-colors"><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg></button></div></div></div></div> <a href="/dashboard/settings/security" class="block bg-zinc-900 border border-zinc-800 rounded-xl p-6 mb-6 hover:border-zinc-700 transition-colors group"><div class="flex items-center justify-between"><div class="flex items-center gap-4"><div class="w-10 h-10 bg-emerald-500/10 rounded-lg flex items-center justify-center"><svg class="w-5 h-5 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg></div> <div><h2 class="text-lg font-semibold">Security Settings</h2> <p class="text-sm text-zinc-400">Manage your password and connected accounts</p></div></div> <svg class="w-5 h-5 text-zinc-500 group-hover:text-white transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg></div></a> <div class="bg-zinc-900 border border-zinc-800 rounded-xl p-6 mb-6"><h2 class="text-lg font-semibold mb-4 text-red-400">Danger Zone</h2> <p class="text-sm text-zinc-400 mb-4">Once you delete your organization, there is no going back. Please be certain.</p> <button class="px-4 py-2 bg-red-600/10 hover:bg-red-600/20 border border-red-600/30 text-red-400 rounded-lg text-sm font-medium transition-colors">Delete Organization</button></div> <div class="flex justify-end"><button${attr("disabled", saving, true)} class="px-6 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg font-medium transition-colors disabled:opacity-50 flex items-center gap-2">`);
    {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`Save Changes`);
    }
    $$renderer2.push(`<!--]--></button></div></div></div>`);
  });
}
export {
  _page as default
};
