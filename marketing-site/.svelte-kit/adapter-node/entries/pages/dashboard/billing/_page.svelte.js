import { U as head, V as ensure_array_like, $ as attr_class, W as attr, _ as stringify } from "../../../../chunks/index2.js";
import { e as escape_html } from "../../../../chunks/context.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    let subscription = null;
    let upgrading = null;
    const plans = [
      {
        id: "essentials",
        name: "Essentials",
        price: "$100",
        priceDetail: "Starting at /mo",
        actions: "1M Actions",
        activeStorage: "1 GB",
        retainedStorage: "40 GB",
        features: [
          "99.9% SLA",
          "Multi-Cloud & Multi-Region",
          "User Roles & API Keys",
          "Audit Logging",
          "1 Business Day P0 Response"
        ],
        popular: true
      },
      {
        id: "business",
        name: "Business",
        price: "$500",
        priceDetail: "Starting at /mo",
        actions: "2.5M Actions",
        activeStorage: "2.5 GB",
        retainedStorage: "100 GB",
        features: [
          "Everything in Essentials",
          "SAML SSO Included",
          "SCIM Add-on",
          "2 Business Hours P0 Response",
          "Workflow Troubleshooting"
        ]
      },
      {
        id: "enterprise",
        name: "Enterprise",
        price: "Custom",
        priceDetail: "contact sales",
        actions: "10M Actions",
        activeStorage: "10 GB",
        retainedStorage: "400 GB",
        features: [
          "Everything in Business",
          "SCIM Included",
          "24/7, 30 Min P0 Response",
          "Technical Onboarding",
          "Design Review"
        ]
      },
      {
        id: "mission_critical",
        name: "Mission Critical",
        price: "Custom",
        priceDetail: "contact sales",
        actions: "10M+ Actions",
        activeStorage: "10+ GB",
        retainedStorage: "400+ GB",
        features: [
          "Everything in Enterprise",
          "Designated Support Engineer",
          "Worker Tuning",
          "Cost Reviews",
          "Security Reviews"
        ]
      }
    ];
    head("ay4x9r", $$renderer2, ($$renderer3) => {
      $$renderer3.title(($$renderer4) => {
        $$renderer4.push(`<title>Billing | Temporal Cloud</title>`);
      });
    });
    $$renderer2.push(`<div class="min-h-screen p-6 text-slate-100"><div class="max-w-6xl mx-auto"><h1 class="text-2xl font-medium mb-8">Billing &amp; Subscription</h1> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--> <div class="grid md:grid-cols-2 gap-6 mb-8"><div class="bg-zinc-900 border border-zinc-800 rounded-xl p-6"><div class="flex items-center justify-between mb-6"><div><h2 class="text-lg font-semibold">Current Plan</h2> <p class="text-zinc-400 text-sm">${escape_html("Loading...")}</p></div> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--></div> `);
    {
      $$renderer2.push("<!--[!-->");
    }
    $$renderer2.push(`<!--]--></div> <div class="bg-zinc-900 border border-zinc-800 rounded-xl p-6"><div class="flex items-center justify-between mb-6"><div><h2 class="text-lg font-semibold">Current Usage</h2> <p class="text-zinc-400 text-sm">This billing period</p></div></div> `);
    {
      $$renderer2.push("<!--[!-->");
      $$renderer2.push(`<p class="text-zinc-500">Loading usage data...</p>`);
    }
    $$renderer2.push(`<!--]--></div></div> <h2 class="text-lg font-semibold mb-4">Available Plans</h2> <div class="grid md:grid-cols-4 gap-4 mb-8"><!--[-->`);
    const each_array = ensure_array_like(plans);
    for (let $$index_1 = 0, $$length = each_array.length; $$index_1 < $$length; $$index_1++) {
      let plan = each_array[$$index_1];
      const isCurrent = subscription?.plan === plan.id;
      $$renderer2.push(`<div${attr_class(`relative bg-zinc-900 border rounded-xl p-5 transition-all ${stringify(isCurrent ? "border-indigo-500 ring-1 ring-indigo-500/20" : "border-zinc-800 hover:border-zinc-700")}`)}>`);
      if (plan.popular && !isCurrent) {
        $$renderer2.push("<!--[-->");
        $$renderer2.push(`<div class="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 bg-indigo-500 text-black text-xs font-semibold rounded-full">Popular</div>`);
      } else {
        $$renderer2.push("<!--[!-->");
      }
      $$renderer2.push(`<!--]--> <h3 class="font-semibold mb-1">${escape_html(plan.name)}</h3> <div class="mb-4"><span class="text-2xl font-bold">${escape_html(plan.price)}</span> <span class="text-sm text-zinc-500 ml-1">${escape_html(plan.priceDetail)}</span></div> <div class="space-y-2 text-sm text-zinc-400 mb-4"><p class="flex items-center gap-2"><svg class="w-4 h-4 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg> ${escape_html(plan.actions)}</p> <p class="flex items-center gap-2"><svg class="w-4 h-4 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg> ${escape_html(plan.activeStorage)} active storage</p> <p class="flex items-center gap-2"><svg class="w-4 h-4 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg> ${escape_html(plan.retainedStorage)} retained storage</p> <!--[-->`);
      const each_array_1 = ensure_array_like(plan.features.slice(0, 2));
      for (let $$index = 0, $$length2 = each_array_1.length; $$index < $$length2; $$index++) {
        let feature = each_array_1[$$index];
        $$renderer2.push(`<p class="flex items-center gap-2"><svg class="w-4 h-4 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg> ${escape_html(feature)}</p>`);
      }
      $$renderer2.push(`<!--]--></div> `);
      if (isCurrent) {
        $$renderer2.push("<!--[-->");
        $$renderer2.push(`<div class="w-full py-2 text-center text-sm text-indigo-400 font-medium border border-indigo-500/30 rounded-lg bg-indigo-500/5">Current Plan</div>`);
      } else {
        $$renderer2.push("<!--[!-->");
        if (plan.id === "enterprise" || plan.id === "mission_critical") {
          $$renderer2.push("<!--[-->");
          $$renderer2.push(`<a href="mailto:sales@temporal.io" class="block w-full py-2 text-center bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium transition-colors">Contact Sales</a>`);
        } else {
          $$renderer2.push("<!--[!-->");
          $$renderer2.push(`<button${attr("disabled", upgrading !== null, true)} class="w-full py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg text-sm font-medium transition-colors flex items-center justify-center gap-2 disabled:opacity-50">`);
          if (upgrading === plan.id) {
            $$renderer2.push("<!--[-->");
            $$renderer2.push(`<svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg> Processing...`);
          } else {
            $$renderer2.push("<!--[!-->");
            $$renderer2.push(`Upgrade <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"></path></svg>`);
          }
          $$renderer2.push(`<!--]--></button>`);
        }
        $$renderer2.push(`<!--]-->`);
      }
      $$renderer2.push(`<!--]--></div>`);
    }
    $$renderer2.push(`<!--]--></div> <h2 class="text-lg font-semibold mb-4">Invoice History</h2> <div class="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden"><table class="w-full"><thead class="bg-zinc-800/50"><tr class="text-left text-xs text-zinc-400 uppercase"><th class="px-6 py-3">Invoice</th><th class="px-6 py-3">Period</th><th class="px-6 py-3">Amount</th><th class="px-6 py-3">Status</th></tr></thead><tbody class="divide-y divide-zinc-800">`);
    {
      $$renderer2.push("<!--[-->");
      $$renderer2.push(`<tr><td colspan="4" class="px-6 py-8 text-center text-zinc-500">Loading...</td></tr>`);
    }
    $$renderer2.push(`<!--]--></tbody></table></div> <div class="mt-8 p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl"><h3 class="font-semibold mb-2">Pay-As-You-Go Pricing</h3> <p class="text-sm text-zinc-400 mb-6">Billed down to the unit per month. Volume discounts as you scale.</p> <div class="grid md:grid-cols-3 gap-8"><div><h4 class="text-sm font-medium text-zinc-300 mb-3 flex items-center gap-2"><svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg> Actions (per Million)</h4> <div class="space-y-2 text-sm"><div class="flex justify-between"><span class="text-zinc-500">First 5M</span><span class="text-emerald-400 font-medium">$50</span></div> <div class="flex justify-between"><span class="text-zinc-500">Next 5M</span><span class="text-emerald-400 font-medium">$45</span></div> <div class="flex justify-between"><span class="text-zinc-500">Next 10M</span><span class="text-emerald-400 font-medium">$40</span></div> <div class="flex justify-between"><span class="text-zinc-500">Next 30M</span><span class="text-emerald-400 font-medium">$35</span></div> <div class="flex justify-between"><span class="text-zinc-500">Next 50M</span><span class="text-emerald-400 font-medium">$30</span></div> <div class="flex justify-between"><span class="text-zinc-500">Next 100M</span><span class="text-emerald-400 font-medium">$25</span></div> <div class="flex justify-between"><span class="text-zinc-500">Over 200M</span><span class="text-cyan-400 font-medium">Contact Sales</span></div></div></div> <div><h4 class="text-sm font-medium text-zinc-300 mb-3 flex items-center gap-2"><svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"></path></svg> Storage (per GB-hour)</h4> <div class="space-y-3 text-sm"><div class="p-3 bg-zinc-800/50 rounded-lg"><div class="flex justify-between mb-1"><span class="text-zinc-400">Active Storage</span> <span class="text-emerald-400 font-medium">$0.042</span></div> <p class="text-xs text-zinc-500">For open/running workflows</p></div> <div class="p-3 bg-zinc-800/50 rounded-lg"><div class="flex justify-between mb-1"><span class="text-zinc-400">Retained Storage</span> <span class="text-emerald-400 font-medium">$0.00105</span></div> <p class="text-xs text-zinc-500">For closed workflow history</p></div></div></div> <div><h4 class="text-sm font-medium text-zinc-300 mb-3 flex items-center gap-2"><svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"></path></svg> Support</h4> <p class="text-sm text-zinc-400 mb-3">Plans charge the greater of your monthly plan or 5%-10% of usage to maintain your support level.</p> <a href="https://temporal.io/pricing" target="_blank" rel="noopener" class="inline-flex items-center gap-1 text-sm text-emerald-400 hover:text-emerald-300 transition-colors">View full pricing details <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg></a></div></div></div> <div class="mt-6 p-6 bg-gradient-to-r from-emerald-500/10 to-cyan-500/10 border border-emerald-500/20 rounded-xl"><div class="flex items-center justify-between"><div><h3 class="font-semibold text-white mb-1">Are you a startup under $30M?</h3> <p class="text-sm text-zinc-400">Get $6,000 in free Temporal Cloud credits through our Startup Program.</p></div> <a href="https://temporal.io/startup-program" target="_blank" rel="noopener" class="px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-black font-medium rounded-lg text-sm transition-colors whitespace-nowrap">Apply Now →</a></div></div></div></div>`);
  });
}
export {
  _page as default
};
