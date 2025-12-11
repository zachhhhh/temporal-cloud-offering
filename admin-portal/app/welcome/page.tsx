"use client";

import Link from "next/link";
import { CheckCircle, ArrowRight } from "lucide-react";
import { getTemporalUI } from "@/lib/api";

export default function WelcomePage() {
  const temporalUI = getTemporalUI();

  const steps = [
    "Create or paste an API key in Settings",
    "Provision a namespace",
    "Invite teammates via your IdP",
    "Connect workers and run a test workflow",
  ];

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="max-w-4xl mx-auto px-6 py-10 space-y-8">
        <div className="bg-gradient-to-r from-indigo-600/20 to-emerald-500/10 border border-indigo-800/40 rounded-2xl p-6">
          <h1 className="text-2xl font-bold mb-2">Welcome to Temporal Cloud</h1>
          <p className="text-zinc-300">
            Your console is ready. Follow these steps to get to a healthy
            namespace with workers running.
          </p>
        </div>

        <div className="grid gap-4">
          {steps.map((step, idx) => (
            <div
              key={step}
              className="flex items-center gap-3 bg-zinc-900 border border-zinc-800 rounded-xl p-4"
            >
              <CheckCircle className="w-5 h-5 text-emerald-400" />
              <div>
                <p className="font-semibold">Step {idx + 1}</p>
                <p className="text-zinc-400 text-sm">{step}</p>
              </div>
            </div>
          ))}
        </div>

        <div className="grid md:grid-cols-2 gap-4">
          <Link
            href="/settings"
            className="flex items-center justify-between px-4 py-3 bg-indigo-600 hover:bg-indigo-700 rounded-xl transition-colors"
          >
            <span className="font-semibold">Add API Key</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
          {temporalUI && (
            <a
              href={temporalUI}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-between px-4 py-3 bg-zinc-900 border border-zinc-800 rounded-xl hover:border-zinc-700 transition-colors"
            >
              <span>Open Temporal UI</span>
              <ArrowRight className="w-4 h-4" />
            </a>
          )}
        </div>
      </div>
    </div>
  );
}
