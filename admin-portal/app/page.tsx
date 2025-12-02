"use client";

import { useState, useEffect } from "react";
import {
  Activity,
  CreditCard,
  Database,
  Server,
  Users,
  ExternalLink,
} from "lucide-react";

interface UsageSummary {
  total_actions: number;
  active_storage_gbh: number;
  retained_storage_gbh: number;
  estimated_cost_cents: number;
  period_start: string;
  period_end: string;
}

interface Namespace {
  id: string;
  name: string;
  temporal_namespace: string;
  region: string;
  status: string;
}

export default function Dashboard() {
  const [usage, setUsage] = useState<UsageSummary | null>(null);
  const [namespaces, setNamespaces] = useState<Namespace[]>([]);
  const [loading, setLoading] = useState(true);

  const BILLING_API =
    process.env.NEXT_PUBLIC_BILLING_API || "http://localhost:8082";
  const TEMPORAL_UI =
    process.env.NEXT_PUBLIC_TEMPORAL_UI || "http://localhost:8080";
  const ORG_ID = process.env.NEXT_PUBLIC_ORG_ID || "demo-org";

  useEffect(() => {
    async function fetchData() {
      try {
        const [usageRes, nsRes] = await Promise.all([
          fetch(`${BILLING_API}/api/v1/organizations/${ORG_ID}/usage/current`),
          fetch(`${BILLING_API}/api/v1/organizations/${ORG_ID}/namespaces`),
        ]);

        if (usageRes.ok) setUsage(await usageRes.json());
        if (nsRes.ok) setNamespaces(await nsRes.json());
      } catch (err) {
        console.error("Failed to fetch data:", err);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [BILLING_API, ORG_ID]);

  const formatCurrency = (cents: number) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    }).format(cents / 100);
  };

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat("en-US").format(num);
  };

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b border-zinc-800 bg-zinc-900/50">
        <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Server className="w-8 h-8 text-indigo-500" />
            <h1 className="text-xl font-bold">Temporal Cloud</h1>
          </div>
          <a
            href={TEMPORAL_UI}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg text-sm font-medium transition-colors"
          >
            Open Temporal UI
            <ExternalLink className="w-4 h-4" />
          </a>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-6 py-8">
        {/* Usage Summary Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-indigo-500/10 rounded-lg">
                <Activity className="w-5 h-5 text-indigo-500" />
              </div>
              <span className="text-sm text-zinc-400">Actions</span>
            </div>
            <p className="text-3xl font-bold">
              {loading ? "..." : formatNumber(usage?.total_actions || 0)}
            </p>
            <p className="text-xs text-zinc-500 mt-1">This billing period</p>
          </div>

          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-green-500/10 rounded-lg">
                <Database className="w-5 h-5 text-green-500" />
              </div>
              <span className="text-sm text-zinc-400">Active Storage</span>
            </div>
            <p className="text-3xl font-bold">
              {loading
                ? "..."
                : `${(usage?.active_storage_gbh || 0).toFixed(2)} GBh`}
            </p>
            <p className="text-xs text-zinc-500 mt-1">$0.042/GBh</p>
          </div>

          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-blue-500/10 rounded-lg">
                <Database className="w-5 h-5 text-blue-500" />
              </div>
              <span className="text-sm text-zinc-400">Retained Storage</span>
            </div>
            <p className="text-3xl font-bold">
              {loading
                ? "..."
                : `${(usage?.retained_storage_gbh || 0).toFixed(2)} GBh`}
            </p>
            <p className="text-xs text-zinc-500 mt-1">$0.00105/GBh</p>
          </div>

          <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-yellow-500/10 rounded-lg">
                <CreditCard className="w-5 h-5 text-yellow-500" />
              </div>
              <span className="text-sm text-zinc-400">Estimated Cost</span>
            </div>
            <p className="text-3xl font-bold">
              {loading
                ? "..."
                : formatCurrency(usage?.estimated_cost_cents || 0)}
            </p>
            <p className="text-xs text-zinc-500 mt-1">Current period</p>
          </div>
        </div>

        {/* Namespaces */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl">
          <div className="px-6 py-4 border-b border-zinc-800 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Users className="w-5 h-5 text-zinc-400" />
              <h2 className="font-semibold">Namespaces</h2>
            </div>
            <button className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg text-sm font-medium transition-colors">
              Create Namespace
            </button>
          </div>

          <div className="divide-y divide-zinc-800">
            {loading ? (
              <div className="px-6 py-8 text-center text-zinc-500">
                Loading...
              </div>
            ) : namespaces.length === 0 ? (
              <div className="px-6 py-8 text-center text-zinc-500">
                No namespaces yet. Create one to get started.
              </div>
            ) : (
              namespaces.map((ns) => (
                <div
                  key={ns.id}
                  className="px-6 py-4 flex items-center justify-between hover:bg-zinc-800/50 transition-colors"
                >
                  <div>
                    <p className="font-medium">{ns.name}</p>
                    <p className="text-sm text-zinc-500">
                      {ns.temporal_namespace}
                    </p>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-sm text-zinc-400">{ns.region}</span>
                    <span
                      className={`px-2 py-1 rounded text-xs font-medium ${
                        ns.status === "active"
                          ? "bg-green-500/10 text-green-400"
                          : "bg-yellow-500/10 text-yellow-400"
                      }`}
                    >
                      {ns.status}
                    </span>
                    <a
                      href={`${TEMPORAL_UI}/namespaces/${ns.temporal_namespace}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-indigo-400 hover:text-indigo-300 text-sm"
                    >
                      View in Temporal UI →
                    </a>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
