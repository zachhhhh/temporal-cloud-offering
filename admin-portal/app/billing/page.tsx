"use client";

import { useState, useEffect } from "react";
import { CreditCard, Download, Calendar, TrendingUp } from "lucide-react";
import { fetchJSON, getBillingAPI, getOrgId } from "@/lib/api";

interface Invoice {
  id: string;
  invoice_number: string;
  period_start: string;
  period_end: string;
  subtotal_cents: number;
  total_cents: number;
  status: string;
}

interface Subscription {
  plan: string;
  status: string;
  actions_included: number;
  active_storage_gb: number;
  retained_storage_gb: number;
  current_period_start: string;
  current_period_end: string;
}

export default function BillingPage() {
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const BILLING_API = getBillingAPI();
  const ORG_ID = getOrgId();

  useEffect(() => {
    async function fetchData() {
      try {
        const [invRes, subRes] = await Promise.all([
          fetchJSON<Invoice[]>(
            `${BILLING_API}/api/v1/organizations/${ORG_ID}/invoices`
          ),
          fetchJSON<Subscription>(
            `${BILLING_API}/api/v1/organizations/${ORG_ID}/subscription`
          ),
        ]);

        setInvoices(invRes || []);
        setSubscription(subRes);
      } catch (err) {
        console.error("Failed to fetch billing data:", err);
        setError("Unable to load billing. Check API key and endpoints.");
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

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  const plans = [
    {
      name: "Free",
      price: "$0",
      actions: "100K",
      storage: "0.1 GB",
      current: subscription?.plan === "free",
    },
    {
      name: "Essential",
      price: "$100/mo",
      actions: "1M",
      storage: "1 GB",
      current: subscription?.plan === "essential",
    },
    {
      name: "Business",
      price: "$500/mo",
      actions: "2.5M",
      storage: "2.5 GB",
      current: subscription?.plan === "business",
    },
    {
      name: "Enterprise",
      price: "Custom",
      actions: "10M+",
      storage: "10+ GB",
      current: subscription?.plan === "enterprise",
    },
  ];

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="max-w-6xl mx-auto px-6 py-8">
        <h1 className="text-2xl font-bold mb-8">Billing & Subscription</h1>

        {/* Current Plan */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-6 mb-8">
          {error && (
            <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded text-red-300 text-sm">
              {error}
            </div>
          )}
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-lg font-semibold">Current Plan</h2>
              <p className="text-zinc-400 text-sm">
                {subscription
                  ? `${
                      subscription.plan.charAt(0).toUpperCase() +
                      subscription.plan.slice(1)
                    } Plan`
                  : "Loading..."}
              </p>
            </div>
            <span
              className={`px-3 py-1 rounded-full text-sm font-medium ${
                subscription?.status === "active"
                  ? "bg-green-500/10 text-green-400"
                  : "bg-yellow-500/10 text-yellow-400"
              }`}
            >
              {subscription?.status || "Loading"}
            </span>
          </div>

          {subscription && (
            <div className="grid grid-cols-3 gap-6">
              <div>
                <p className="text-xs text-zinc-500 mb-1">Actions Included</p>
                <p className="text-lg font-medium">
                  {(subscription.actions_included / 1000000).toFixed(1)}M /
                  month
                </p>
              </div>
              <div>
                <p className="text-xs text-zinc-500 mb-1">Active Storage</p>
                <p className="text-lg font-medium">
                  {subscription.active_storage_gb} GB
                </p>
              </div>
              <div>
                <p className="text-xs text-zinc-500 mb-1">Retained Storage</p>
                <p className="text-lg font-medium">
                  {subscription.retained_storage_gb} GB
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Plan Options */}
        <h2 className="text-lg font-semibold mb-4">Available Plans</h2>
        <div className="grid grid-cols-4 gap-4 mb-8">
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={`bg-zinc-900 border rounded-xl p-5 ${
                plan.current ? "border-indigo-500" : "border-zinc-800"
              }`}
            >
              <h3 className="font-semibold mb-1">{plan.name}</h3>
              <p className="text-2xl font-bold text-indigo-400 mb-4">
                {plan.price}
              </p>
              <div className="space-y-2 text-sm text-zinc-400">
                <p>{plan.actions} actions</p>
                <p>{plan.storage} active storage</p>
              </div>
              {plan.current ? (
                <div className="mt-4 text-center text-sm text-indigo-400 font-medium">
                  Current Plan
                </div>
              ) : (
                <button className="mt-4 w-full py-2 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium transition-colors">
                  {plan.name === "Enterprise" ? "Contact Sales" : "Upgrade"}
                </button>
              )}
            </div>
          ))}
        </div>

        {/* Invoices */}
        <h2 className="text-lg font-semibold mb-4">Invoice History</h2>
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
          <table className="w-full">
            <thead className="bg-zinc-800/50">
              <tr className="text-left text-xs text-zinc-400 uppercase">
                <th className="px-6 py-3">Invoice</th>
                <th className="px-6 py-3">Period</th>
                <th className="px-6 py-3">Amount</th>
                <th className="px-6 py-3">Status</th>
                <th className="px-6 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-800">
              {loading ? (
                <tr>
                  <td
                    colSpan={5}
                    className="px-6 py-8 text-center text-zinc-500"
                  >
                    Loading...
                  </td>
                </tr>
              ) : invoices.length === 0 ? (
                <tr>
                  <td
                    colSpan={5}
                    className="px-6 py-8 text-center text-zinc-500"
                  >
                    No invoices yet
                  </td>
                </tr>
              ) : (
                invoices.map((invoice) => (
                  <tr key={invoice.id} className="hover:bg-zinc-800/30">
                    <td className="px-6 py-4 font-medium">
                      {invoice.invoice_number}
                    </td>
                    <td className="px-6 py-4 text-zinc-400">
                      {formatDate(invoice.period_start)} -{" "}
                      {formatDate(invoice.period_end)}
                    </td>
                    <td className="px-6 py-4">
                      {formatCurrency(invoice.total_cents)}
                    </td>
                    <td className="px-6 py-4">
                      <span
                        className={`px-2 py-1 rounded text-xs font-medium ${
                          invoice.status === "paid"
                            ? "bg-green-500/10 text-green-400"
                            : invoice.status === "pending"
                            ? "bg-yellow-500/10 text-yellow-400"
                            : "bg-zinc-500/10 text-zinc-400"
                        }`}
                      >
                        {invoice.status}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <button className="text-zinc-400 hover:text-zinc-200">
                        <Download className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pricing Info */}
        <div className="mt-8 p-6 bg-zinc-900/50 border border-zinc-800 rounded-xl">
          <h3 className="font-semibold mb-4">Overage Pricing</h3>
          <div className="grid grid-cols-3 gap-6 text-sm">
            <div>
              <p className="text-zinc-400 mb-1">Actions</p>
              <p>$25-50 per million</p>
            </div>
            <div>
              <p className="text-zinc-400 mb-1">Active Storage</p>
              <p>$0.042 per GB-hour</p>
            </div>
            <div>
              <p className="text-zinc-400 mb-1">Retained Storage</p>
              <p>$0.00105 per GB-hour</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
