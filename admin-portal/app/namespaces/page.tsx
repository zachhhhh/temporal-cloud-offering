"use client";

import { useState, useEffect } from "react";
import { Server, Plus, ExternalLink, Trash2, Settings } from "lucide-react";

interface Namespace {
  id: string;
  name: string;
  temporal_namespace: string;
  region: string;
  status: string;
  retention_days: number;
  created_at: string;
}

export default function NamespacesPage() {
  const [namespaces, setNamespaces] = useState<Namespace[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [newNs, setNewNs] = useState({
    name: "",
    region: "us-east-1",
    retention_days: 7,
  });

  const BILLING_API =
    process.env.NEXT_PUBLIC_BILLING_API || "http://localhost:8082";
  const TEMPORAL_UI =
    process.env.NEXT_PUBLIC_TEMPORAL_UI || "http://localhost:8080";
  const ORG_ID = process.env.NEXT_PUBLIC_ORG_ID || "demo-org";

  useEffect(() => {
    fetchNamespaces();
  }, []);

  async function fetchNamespaces() {
    try {
      const res = await fetch(
        `${BILLING_API}/api/v1/organizations/${ORG_ID}/namespaces`
      );
      if (res.ok) {
        const data = await res.json();
        setNamespaces(data || []);
      }
    } catch (err) {
      console.error("Failed to fetch namespaces:", err);
    } finally {
      setLoading(false);
    }
  }

  async function createNamespace() {
    try {
      const res = await fetch(
        `${BILLING_API}/api/v1/organizations/${ORG_ID}/namespaces`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(newNs),
        }
      );
      if (res.ok) {
        setShowCreate(false);
        setNewNs({ name: "", region: "us-east-1", retention_days: 7 });
        fetchNamespaces();
      }
    } catch (err) {
      console.error("Failed to create namespace:", err);
    }
  }

  const regions = [
    { id: "us-east-1", name: "US East (N. Virginia)" },
    { id: "us-west-2", name: "US West (Oregon)" },
    { id: "eu-west-1", name: "EU (Ireland)" },
    { id: "ap-southeast-1", name: "Asia Pacific (Singapore)" },
  ];

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="max-w-6xl mx-auto px-6 py-8">
        <div className="flex items-center justify-between mb-8">
          <h1 className="text-2xl font-bold">Namespaces</h1>
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg text-sm font-medium transition-colors"
          >
            <Plus className="w-4 h-4" />
            Create Namespace
          </button>
        </div>

        {/* Create Modal */}
        {showCreate && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 w-full max-w-md">
              <h2 className="text-lg font-semibold mb-4">Create Namespace</h2>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-zinc-400 mb-1">
                    Name
                  </label>
                  <input
                    type="text"
                    value={newNs.name}
                    onChange={(e) =>
                      setNewNs({ ...newNs, name: e.target.value })
                    }
                    className="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg focus:outline-none focus:border-indigo-500"
                    placeholder="my-namespace"
                  />
                </div>

                <div>
                  <label className="block text-sm text-zinc-400 mb-1">
                    Region
                  </label>
                  <select
                    value={newNs.region}
                    onChange={(e) =>
                      setNewNs({ ...newNs, region: e.target.value })
                    }
                    className="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg focus:outline-none focus:border-indigo-500"
                  >
                    {regions.map((r) => (
                      <option key={r.id} value={r.id}>
                        {r.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm text-zinc-400 mb-1">
                    Retention (days)
                  </label>
                  <input
                    type="number"
                    value={newNs.retention_days}
                    onChange={(e) =>
                      setNewNs({
                        ...newNs,
                        retention_days: parseInt(e.target.value),
                      })
                    }
                    className="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg focus:outline-none focus:border-indigo-500"
                    min={1}
                    max={90}
                  />
                </div>
              </div>

              <div className="flex gap-3 mt-6">
                <button
                  onClick={() => setShowCreate(false)}
                  className="flex-1 py-2 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={createNamespace}
                  disabled={!newNs.name}
                  className="flex-1 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 rounded-lg text-sm font-medium transition-colors"
                >
                  Create
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Namespaces List */}
        <div className="space-y-4">
          {loading ? (
            <div className="text-center py-12 text-zinc-500">Loading...</div>
          ) : namespaces.length === 0 ? (
            <div className="text-center py-12 bg-zinc-900 border border-zinc-800 rounded-xl">
              <Server className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
              <p className="text-zinc-400 mb-4">No namespaces yet</p>
              <button
                onClick={() => setShowCreate(true)}
                className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg text-sm font-medium transition-colors"
              >
                Create your first namespace
              </button>
            </div>
          ) : (
            namespaces.map((ns) => (
              <div
                key={ns.id}
                className="bg-zinc-900 border border-zinc-800 rounded-xl p-5"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className="p-2 bg-indigo-500/10 rounded-lg">
                      <Server className="w-5 h-5 text-indigo-500" />
                    </div>
                    <div>
                      <h3 className="font-semibold">{ns.name}</h3>
                      <p className="text-sm text-zinc-500">
                        {ns.temporal_namespace}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-6">
                    <div className="text-right">
                      <p className="text-xs text-zinc-500">Region</p>
                      <p className="text-sm">{ns.region}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-zinc-500">Retention</p>
                      <p className="text-sm">{ns.retention_days} days</p>
                    </div>
                    <span
                      className={`px-2 py-1 rounded text-xs font-medium ${
                        ns.status === "active"
                          ? "bg-green-500/10 text-green-400"
                          : ns.status === "provisioning"
                          ? "bg-yellow-500/10 text-yellow-400"
                          : "bg-zinc-500/10 text-zinc-400"
                      }`}
                    >
                      {ns.status}
                    </span>

                    <div className="flex items-center gap-2">
                      <a
                        href={`${TEMPORAL_UI}/namespaces/${ns.temporal_namespace}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-2 hover:bg-zinc-800 rounded-lg transition-colors"
                        title="Open in Temporal UI"
                      >
                        <ExternalLink className="w-4 h-4 text-zinc-400" />
                      </a>
                      <button
                        className="p-2 hover:bg-zinc-800 rounded-lg transition-colors"
                        title="Settings"
                      >
                        <Settings className="w-4 h-4 text-zinc-400" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
