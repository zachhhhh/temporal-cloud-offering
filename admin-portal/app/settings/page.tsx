"use client";

import { useState, useEffect } from "react";
import { Key, Plus, Trash2, Copy, Check, Eye, EyeOff } from "lucide-react";

interface APIKey {
  id: string;
  name: string;
  key_prefix: string;
  scopes: string[];
  expires_at: string | null;
  last_used_at: string | null;
  created_at: string;
}

export default function SettingsPage() {
  const [apiKeys, setApiKeys] = useState<APIKey[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [newKey, setNewKey] = useState({ name: "", expires_in: "90d" });
  const [createdKey, setCreatedKey] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const BILLING_API =
    process.env.NEXT_PUBLIC_BILLING_API || "http://localhost:8082";
  const ORG_ID = process.env.NEXT_PUBLIC_ORG_ID || "demo-org";

  useEffect(() => {
    fetchAPIKeys();
  }, []);

  async function fetchAPIKeys() {
    try {
      const res = await fetch(
        `${BILLING_API}/api/v1/organizations/${ORG_ID}/api-keys`
      );
      if (res.ok) {
        const data = await res.json();
        setApiKeys(data || []);
      }
    } catch (err) {
      console.error("Failed to fetch API keys:", err);
    } finally {
      setLoading(false);
    }
  }

  async function createAPIKey() {
    try {
      const res = await fetch(
        `${BILLING_API}/api/v1/organizations/${ORG_ID}/api-keys`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(newKey),
        }
      );
      if (res.ok) {
        const data = await res.json();
        setCreatedKey(data.key);
        setNewKey({ name: "", expires_in: "90d" });
        fetchAPIKeys();
      }
    } catch (err) {
      console.error("Failed to create API key:", err);
    }
  }

  async function deleteAPIKey(keyId: string) {
    if (!confirm("Are you sure you want to delete this API key?")) return;

    try {
      const res = await fetch(`${BILLING_API}/api/v1/api-keys/${keyId}`, {
        method: "DELETE",
      });
      if (res.ok) {
        fetchAPIKeys();
      }
    } catch (err) {
      console.error("Failed to delete API key:", err);
    }
  }

  function copyToClipboard(text: string) {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return "Never";
    return new Date(dateStr).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="max-w-4xl mx-auto px-6 py-8">
        <h1 className="text-2xl font-bold mb-8">Settings</h1>

        {/* API Keys Section */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl">
          <div className="px-6 py-4 border-b border-zinc-800 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Key className="w-5 h-5 text-zinc-400" />
              <h2 className="font-semibold">API Keys</h2>
            </div>
            <button
              onClick={() => setShowCreate(true)}
              className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 rounded-lg text-sm font-medium transition-colors"
            >
              <Plus className="w-4 h-4" />
              Create Key
            </button>
          </div>

          {/* Created Key Alert */}
          {createdKey && (
            <div className="m-4 p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
              <p className="text-sm text-green-400 mb-2">
                API key created! Copy it now - you won&apos;t be able to see it
                again.
              </p>
              <div className="flex items-center gap-2">
                <code className="flex-1 px-3 py-2 bg-zinc-800 rounded font-mono text-sm break-all">
                  {createdKey}
                </code>
                <button
                  onClick={() => copyToClipboard(createdKey)}
                  className="p-2 bg-zinc-800 hover:bg-zinc-700 rounded-lg transition-colors"
                >
                  {copied ? (
                    <Check className="w-4 h-4 text-green-400" />
                  ) : (
                    <Copy className="w-4 h-4" />
                  )}
                </button>
              </div>
              <button
                onClick={() => setCreatedKey(null)}
                className="mt-3 text-sm text-zinc-400 hover:text-zinc-200"
              >
                Dismiss
              </button>
            </div>
          )}

          {/* Create Key Modal */}
          {showCreate && (
            <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
              <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 w-full max-w-md">
                <h2 className="text-lg font-semibold mb-4">Create API Key</h2>

                <div className="space-y-4">
                  <div>
                    <label className="block text-sm text-zinc-400 mb-1">
                      Name
                    </label>
                    <input
                      type="text"
                      value={newKey.name}
                      onChange={(e) =>
                        setNewKey({ ...newKey, name: e.target.value })
                      }
                      className="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg focus:outline-none focus:border-indigo-500"
                      placeholder="Production API Key"
                    />
                  </div>

                  <div>
                    <label className="block text-sm text-zinc-400 mb-1">
                      Expires In
                    </label>
                    <select
                      value={newKey.expires_in}
                      onChange={(e) =>
                        setNewKey({ ...newKey, expires_in: e.target.value })
                      }
                      className="w-full px-3 py-2 bg-zinc-800 border border-zinc-700 rounded-lg focus:outline-none focus:border-indigo-500"
                    >
                      <option value="30d">30 days</option>
                      <option value="90d">90 days</option>
                      <option value="1y">1 year</option>
                      <option value="">Never</option>
                    </select>
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
                    onClick={() => {
                      createAPIKey();
                      setShowCreate(false);
                    }}
                    disabled={!newKey.name}
                    className="flex-1 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 rounded-lg text-sm font-medium transition-colors"
                  >
                    Create
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* API Keys List */}
          <div className="divide-y divide-zinc-800">
            {loading ? (
              <div className="px-6 py-8 text-center text-zinc-500">
                Loading...
              </div>
            ) : apiKeys.length === 0 ? (
              <div className="px-6 py-8 text-center text-zinc-500">
                No API keys yet. Create one to get started.
              </div>
            ) : (
              apiKeys.map((key) => (
                <div
                  key={key.id}
                  className="px-6 py-4 flex items-center justify-between hover:bg-zinc-800/30"
                >
                  <div>
                    <p className="font-medium">{key.name}</p>
                    <p className="text-sm text-zinc-500">
                      tc_live_{key.key_prefix}_••••••••
                    </p>
                  </div>
                  <div className="flex items-center gap-6">
                    <div className="text-right">
                      <p className="text-xs text-zinc-500">Last used</p>
                      <p className="text-sm">{formatDate(key.last_used_at)}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs text-zinc-500">Expires</p>
                      <p className="text-sm">
                        {key.expires_at ? formatDate(key.expires_at) : "Never"}
                      </p>
                    </div>
                    <button
                      onClick={() => deleteAPIKey(key.id)}
                      className="p-2 text-zinc-400 hover:text-red-400 hover:bg-zinc-800 rounded-lg transition-colors"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Organization Settings */}
        <div className="mt-8 bg-zinc-900 border border-zinc-800 rounded-xl p-6">
          <h2 className="font-semibold mb-4">Organization</h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm text-zinc-400 mb-1">
                Organization ID
              </label>
              <div className="flex items-center gap-2">
                <code className="flex-1 px-3 py-2 bg-zinc-800 rounded font-mono text-sm">
                  {ORG_ID}
                </code>
                <button
                  onClick={() => copyToClipboard(ORG_ID)}
                  className="p-2 bg-zinc-800 hover:bg-zinc-700 rounded-lg transition-colors"
                >
                  <Copy className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Danger Zone */}
        <div className="mt-8 bg-zinc-900 border border-red-500/20 rounded-xl p-6">
          <h2 className="font-semibold text-red-400 mb-4">Danger Zone</h2>
          <p className="text-sm text-zinc-400 mb-4">
            These actions are irreversible. Please proceed with caution.
          </p>
          <button className="px-4 py-2 bg-red-500/10 text-red-400 border border-red-500/20 hover:bg-red-500/20 rounded-lg text-sm font-medium transition-colors">
            Delete Organization
          </button>
        </div>
      </div>
    </div>
  );
}
