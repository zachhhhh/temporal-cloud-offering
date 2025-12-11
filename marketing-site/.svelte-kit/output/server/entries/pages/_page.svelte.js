import { W as attr, V as ensure_array_like } from "../../chunks/index2.js";
import { c as config } from "../../chunks/config.js";
import { e as escape_html } from "../../chunks/escaping.js";
function _page($$renderer, $$props) {
  $$renderer.component(($$renderer2) => {
    const useCases = [
      {
        title: "Agents, MCP, & AI Pipelines",
        desc: "Develop agents that survive real-world chaos, reliable MCP & orchestrate training pipelines."
      },
      {
        title: "Humans-in-the-Loop",
        desc: "No more duct-taping Workflows around human input: just clean, durable orchestration."
      },
      {
        title: "Compensating Patterns (Saga)",
        desc: "Make Saga easy: what if Saga was simply a try...catch?"
      },
      {
        title: "Long-running Workflows",
        desc: "Run Workflows for days, weeks, or months without losing progress or adding complexity."
      },
      {
        title: "Order Fulfillment",
        desc: "One bad service shouldn't break the cart. Temporal keeps the order moving."
      },
      {
        title: "Durable Ledgers",
        desc: "Track transactions with code you can trust down to the last cent."
      },
      {
        title: "CI/CD",
        desc: "Deploy with confidence. Temporal gives you clean retries, rollbacks, and visibility."
      },
      {
        title: "Customer Acquisition",
        desc: "Route leads, onboard users, and engage customers without dropped steps or hacks."
      }
    ];
    const testimonials = [
      {
        quote: "One of the most interesting pieces of tech I've seen in years… Temporal does to backend and infra, what React did to frontend.",
        author: "Guillermo Rauch",
        title: "Founder & CEO, Vercel"
      },
      {
        quote: "Temporal's technology satisfied all of these requirements out of the box and allowed our developers to focus on business logic.",
        author: "Mitchell Hashimoto",
        title: "Co-founder, Hashicorp"
      }
    ];
    const customers = [
      "NVIDIA",
      "Salesforce",
      "Twilio",
      "Descript",
      "Netflix",
      "Stripe",
      "Snap",
      "Datadog"
    ];
    $$renderer2.push(`<section class="relative min-h-screen flex items-center overflow-hidden"><div class="absolute inset-0 bg-gradient-to-br from-[#1a0a2e] via-[#16082a] to-[#0d0620]"></div> <div class="absolute inset-0 opacity-20" style="background-image: linear-gradient(rgba(139, 92, 246, 0.1) 1px, transparent 1px), linear-gradient(90deg, rgba(139, 92, 246, 0.1) 1px, transparent 1px); background-size: 60px 60px;"></div> <div class="absolute top-0 right-0 w-[600px] h-[600px] bg-purple-600/20 rounded-full blur-[150px]"></div> <div class="absolute bottom-0 left-1/4 w-[400px] h-[400px] bg-fuchsia-600/15 rounded-full blur-[120px]"></div> <div class="relative z-10 max-w-7xl mx-auto px-6 py-32 grid lg:grid-cols-2 gap-12 items-center"><div><p class="text-sm font-medium text-emerald-400 tracking-widest uppercase mb-6">Welcome to Temporal</p> <h1 class="text-5xl md:text-6xl lg:text-7xl font-bold mb-8 leading-[1.1] text-white">What if your code never failed?</h1> <p class="text-xl text-zinc-300 max-w-xl mb-10 leading-relaxed">Failures happen. Temporal makes them irrelevant. Build applications that never lose state, even when everything else fails.</p> <div class="flex flex-col sm:flex-row items-start gap-4"><a${attr("href", config.urls.app)} class="px-6 py-3 bg-gradient-to-r from-emerald-400 to-cyan-400 text-black font-semibold rounded-lg transition-all hover:shadow-lg hover:shadow-emerald-400/25">Get Started for Free</a> <a href="https://learn.temporal.io/getting_started/" target="_blank" rel="noopener noreferrer" class="px-6 py-3 text-white font-semibold hover:text-emerald-400 transition-colors">Get Started with OSS</a></div></div> <div class="hidden lg:block"><div class="bg-[#0d1117] border border-zinc-800 rounded-xl overflow-hidden shadow-2xl"><div class="flex items-center gap-2 px-4 py-3 bg-[#161b22] border-b border-zinc-800"><div class="w-3 h-3 rounded-full bg-red-500"></div> <div class="w-3 h-3 rounded-full bg-yellow-500"></div> <div class="w-3 h-3 rounded-full bg-green-500"></div></div> <pre class="p-6 text-sm overflow-x-auto"><code class="text-zinc-300"><span class="text-purple-400">@workflow.defn</span>
<span class="text-blue-400">class</span> <span class="text-yellow-300">SleepForDaysWorkflow</span>:
    <span class="text-zinc-500"># Send an email every 30 days</span>
    <span class="text-purple-400">@workflow.run</span>
    <span class="text-blue-400">async def</span> <span class="text-green-400">run</span>(<span class="text-orange-300">self</span>) -> <span class="text-blue-300">None</span>:
        <span class="text-blue-400">for</span> i <span class="text-blue-400">in</span> <span class="text-yellow-300">range</span>(<span class="text-orange-400">12</span>):
            <span class="text-zinc-500"># Activities have built-in retries!</span>
            <span class="text-blue-400">await</span> workflow.execute_activity(
                send_email,
                start_to_close_timeout=<span class="text-yellow-300">timedelta</span>(seconds=<span class="text-orange-400">10</span>),
            )
            <span class="text-zinc-500"># Sleep for 30 days (yes, really)!</span>
            <span class="text-blue-400">await</span> workflow.sleep(<span class="text-yellow-300">timedelta</span>(days=<span class="text-orange-400">30</span>))</code></pre> <div class="flex gap-2 px-4 py-3 bg-[#161b22] border-t border-zinc-800"><button class="px-3 py-1 text-xs font-medium text-white bg-zinc-700 rounded">PYTHON</button> <button class="px-3 py-1 text-xs font-medium text-zinc-400 hover:text-white transition">GO</button> <button class="px-3 py-1 text-xs font-medium text-zinc-400 hover:text-white transition">TYPESCRIPT</button> <button class="px-3 py-1 text-xs font-medium text-zinc-400 hover:text-white transition">JAVA</button></div></div></div></div></section> <section class="py-12 bg-[#0d0620] border-y border-zinc-800/50 overflow-hidden"><div class="max-w-7xl mx-auto px-6"><div class="flex items-center justify-center gap-12 flex-wrap opacity-60"><!--[-->`);
    const each_array = ensure_array_like(customers);
    for (let $$index = 0, $$length = each_array.length; $$index < $$length; $$index++) {
      let customer = each_array[$$index];
      $$renderer2.push(`<span class="text-lg font-semibold text-zinc-400 whitespace-nowrap">${escape_html(customer)}</span>`);
    }
    $$renderer2.push(`<!--]--></div></div></section> <section id="product" class="py-24 px-6 bg-[#0d1117]"><div class="max-w-6xl mx-auto"><div class="text-center mb-16"><h2 class="text-4xl md:text-5xl font-bold mb-6">Write code as if failure doesn't exist</h2> <p class="text-xl text-zinc-400 max-w-3xl mx-auto leading-relaxed">Distributed systems break, APIs fail, networks flake, and services crash. 
				That's not your problem anymore.</p></div> <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6"><div class="p-8 bg-[#161b22] border border-zinc-800/50 rounded-2xl card-hover"><div class="w-12 h-12 bg-[#6173F3]/10 rounded-xl flex items-center justify-center mb-6"><svg class="w-6 h-6 text-[#6173F3]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path></svg></div> <h3 class="text-xl font-semibold mb-3">Durable by Default</h3> <p class="text-zinc-400 leading-relaxed">Your workflow state is automatically persisted. Survive any failure—server crashes, network issues, or deployments.</p></div> <div class="p-8 bg-[#161b22] border border-zinc-800/50 rounded-2xl card-hover"><div class="w-12 h-12 bg-emerald-500/10 rounded-xl flex items-center justify-center mb-6"><svg class="w-6 h-6 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg></div> <h3 class="text-xl font-semibold mb-3">Automatic Retries</h3> <p class="text-zinc-400 leading-relaxed">APIs fail, networks time out, and users abandon sessions. Temporal treats these as Activities that retry automatically.</p></div> <div class="p-8 bg-[#161b22] border border-zinc-800/50 rounded-2xl card-hover"><div class="w-12 h-12 bg-blue-500/10 rounded-xl flex items-center justify-center mb-6"><svg class="w-6 h-6 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg></div> <h3 class="text-xl font-semibold mb-3">Full Visibility</h3> <p class="text-zinc-400 leading-relaxed">No more wasting time sifting through logs. Get visibility into the exact state of each Workflow execution.</p></div> <div class="p-8 bg-[#161b22] border border-zinc-800/50 rounded-2xl card-hover"><div class="w-12 h-12 bg-amber-500/10 rounded-xl flex items-center justify-center mb-6"><svg class="w-6 h-6 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg></div> <h3 class="text-xl font-semibold mb-3">Long-Running Workflows</h3> <p class="text-zinc-400 leading-relaxed">Workflows can run for seconds, days, or years. Built-in timers, signals, and scheduling.</p></div> <div class="p-8 bg-[#161b22] border border-zinc-800/50 rounded-2xl card-hover"><div class="w-12 h-12 bg-purple-500/10 rounded-xl flex items-center justify-center mb-6"><svg class="w-6 h-6 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path></svg></div> <h3 class="text-xl font-semibold mb-3">Native SDKs</h3> <p class="text-zinc-400 leading-relaxed">Write your business logic in Go, TypeScript, Python, Java, .NET, or PHP. No boilerplate required.</p></div> <div class="p-8 bg-[#161b22] border border-zinc-800/50 rounded-2xl card-hover"><div class="w-12 h-12 bg-rose-500/10 rounded-xl flex items-center justify-center mb-6"><svg class="w-6 h-6 text-rose-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg></div> <h3 class="text-xl font-semibold mb-3">100% Open Source</h3> <p class="text-zinc-400 leading-relaxed">MIT-licensed, built in the open, and backed by a thriving developer community. 16,000+ GitHub stars.</p></div></div></div></section> <section id="use-cases" class="py-24 px-6 bg-[#161b22]/50"><div class="max-w-6xl mx-auto"><div class="text-center mb-16"><h2 class="text-4xl md:text-5xl font-bold mb-6">Common patterns and use cases</h2> <p class="text-xl text-zinc-400">From AI pipelines to order fulfillment, Temporal handles it all.</p></div> <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-4"><!--[-->`);
    const each_array_1 = ensure_array_like(useCases);
    for (let $$index_1 = 0, $$length = each_array_1.length; $$index_1 < $$length; $$index_1++) {
      let useCase = each_array_1[$$index_1];
      $$renderer2.push(`<div class="p-6 bg-[#0d1117] border border-zinc-800/50 rounded-xl card-hover"><h3 class="font-semibold mb-2 text-white">${escape_html(useCase.title)}</h3> <p class="text-sm text-zinc-400 leading-relaxed">${escape_html(useCase.desc)}</p></div>`);
    }
    $$renderer2.push(`<!--]--></div></div></section> <section class="py-24 px-6 bg-[#0d1117]"><div class="max-w-4xl mx-auto"><div class="text-center mb-16"><h2 class="text-4xl md:text-5xl font-bold mb-6">Loved by developers</h2></div> <div class="grid md:grid-cols-2 gap-6"><!--[-->`);
    const each_array_2 = ensure_array_like(testimonials);
    for (let $$index_2 = 0, $$length = each_array_2.length; $$index_2 < $$length; $$index_2++) {
      let testimonial = each_array_2[$$index_2];
      $$renderer2.push(`<div class="p-8 bg-[#161b22] border border-zinc-800/50 rounded-2xl"><p class="text-lg text-zinc-300 mb-6 italic leading-relaxed">"${escape_html(testimonial.quote)}"</p> <div><p class="font-semibold text-white">${escape_html(testimonial.author)}</p> <p class="text-sm text-zinc-500">${escape_html(testimonial.title)}</p></div></div>`);
    }
    $$renderer2.push(`<!--]--></div></div></section> <section id="pricing" class="py-24 px-6 bg-[#161b22]/50"><div class="max-w-4xl mx-auto"><div class="text-center mb-16"><h2 class="text-4xl md:text-5xl font-bold mb-6">Simple, usage-based pricing</h2> <p class="text-xl text-zinc-400">Pay only for what you use. No upfront commitments.</p></div> <div class="bg-[#0d1117] border border-zinc-800/50 rounded-2xl p-8 md:p-12"><div class="grid md:grid-cols-3 gap-8 mb-12"><div class="text-center"><p class="text-5xl font-bold text-[#6173F3]">$${escape_html(config.pricing.actions.price)}</p> <p class="text-zinc-400 mt-2">${escape_html(config.pricing.actions.unit)}</p> <p class="text-sm text-zinc-500 mt-1">Actions</p></div> <div class="text-center"><p class="text-5xl font-bold text-emerald-400">$${escape_html(config.pricing.activeStorage.price)}</p> <p class="text-zinc-400 mt-2">${escape_html(config.pricing.activeStorage.unit)}</p> <p class="text-sm text-zinc-500 mt-1">Active Storage</p></div> <div class="text-center"><p class="text-5xl font-bold text-blue-400">$${escape_html(config.pricing.retainedStorage.price)}</p> <p class="text-zinc-400 mt-2">${escape_html(config.pricing.retainedStorage.unit)}</p> <p class="text-sm text-zinc-500 mt-1">Retained Storage</p></div></div> <div class="border-t border-zinc-800/50 pt-8"><h3 class="font-semibold mb-6 text-center text-white">Everything included:</h3> <div class="grid md:grid-cols-2 gap-4 max-w-xl mx-auto"><!--[-->`);
    const each_array_3 = ensure_array_like([
      "Unlimited namespaces",
      "Multi-region support",
      "99.99% SLA",
      "SSO authentication",
      "Audit logs",
      "24/7 support",
      "Temporal UI",
      "Metrics & monitoring"
    ]);
    for (let $$index_3 = 0, $$length = each_array_3.length; $$index_3 < $$length; $$index_3++) {
      let feature = each_array_3[$$index_3];
      $$renderer2.push(`<div class="flex items-center gap-3"><svg class="w-5 h-5 text-[#6173F3] flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg> <span class="text-zinc-300">${escape_html(feature)}</span></div>`);
    }
    $$renderer2.push(`<!--]--></div></div> <div class="mt-10 text-center"><a${attr("href", config.urls.app)} class="inline-flex items-center gap-2 px-8 py-4 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-semibold text-lg transition-all hover:shadow-lg hover:shadow-indigo-600/25">Start Free Trial <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"></path></svg></a></div></div></div></section> <section class="py-24 px-6 bg-[#0d1117]"><div class="max-w-4xl mx-auto text-center"><h2 class="text-4xl md:text-5xl font-bold mb-6">Ready to build invincible applications?</h2> <p class="text-xl text-zinc-400 mb-10">Join thousands of developers using Temporal to build reliable systems.</p> <div class="flex flex-col sm:flex-row items-center justify-center gap-4"><a${attr("href", config.urls.app)} class="flex items-center gap-2 px-8 py-4 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-semibold text-lg transition-all hover:shadow-lg hover:shadow-indigo-600/25">Get Started for Free <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"></path></svg></a> <a${attr("href", config.urls.docs)} target="_blank" rel="noopener noreferrer" class="px-8 py-4 border border-zinc-700 hover:border-[#6173F3]/50 rounded-xl font-semibold text-lg transition-all">Read Documentation</a></div></div></section>`);
  });
}
export {
  _page as default
};
