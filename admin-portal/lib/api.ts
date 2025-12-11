// API utilities for admin portal
// For production, set these in Cloudflare Pages environment variables

export function getBillingAPI(): string {
  // In browser, check for runtime config first
  if (typeof window !== "undefined") {
    const runtimeConfig = (window as any).__RUNTIME_CONFIG__;
    if (runtimeConfig?.BILLING_API) return runtimeConfig.BILLING_API;
  }
  return (
    process.env.NEXT_PUBLIC_BILLING_API ||
    "https://billing.temporal-cloud.pages.dev"
  );
}

export function getTemporalUI(): string {
  if (typeof window !== "undefined") {
    const runtimeConfig = (window as any).__RUNTIME_CONFIG__;
    if (runtimeConfig?.TEMPORAL_UI) return runtimeConfig.TEMPORAL_UI;
  }
  return (
    process.env.NEXT_PUBLIC_TEMPORAL_UI ||
    "https://temporal-cloud.pages.dev/dashboard/ui"
  );
}

export function getOrgId(): string {
  // In production, this would come from auth context
  return process.env.NEXT_PUBLIC_ORG_ID || "default-org";
}

export function getApiKey(): string | null {
  if (typeof window === "undefined") return null;

  // Check localStorage first
  const stored = localStorage.getItem("tc_api_key");
  if (stored) return stored;

  // Check cookie
  const cookies = document.cookie.split(";");
  for (const cookie of cookies) {
    const [name, value] = cookie.trim().split("=");
    if (name === "tc_api_key") return value;
  }

  return null;
}

export function authHeaders(): Record<string, string> {
  const apiKey = getApiKey();
  if (apiKey) {
    return { "X-API-Key": apiKey };
  }
  return {};
}

export async function fetchJSON<T>(
  url: string,
  options?: RequestInit
): Promise<T> {
  const response = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...authHeaders(),
      ...options?.headers,
    },
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }

  return response.json();
}
