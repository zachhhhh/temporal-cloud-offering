// Cloudflare Worker to proxy API requests to OKE backend
export interface Env {
  OKE_BILLING_URL: string;
  OKE_TEMPORAL_URL: string;
}

// No demo data - use real backend only

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, X-API-Key",
    };

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // Route to appropriate backend
    let backendUrl: string;
    let backendPath: string;

    if (path === "/api/health") {
      // Health check - direct path
      backendUrl = env.OKE_BILLING_URL;
      backendPath = "/health";
    } else if (path.startsWith("/api/")) {
      // Billing API - map /api/* to /api/v1/*
      backendUrl = env.OKE_BILLING_URL;
      backendPath = `/api/v1${path.replace("/api", "")}`;
    } else if (path.startsWith("/temporal/")) {
      // Temporal UI
      backendUrl = env.OKE_TEMPORAL_URL;
      backendPath = path.replace("/temporal", "");
    } else {
      return new Response(JSON.stringify({ error: "Not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    try {
      const targetUrl = `${backendUrl}${backendPath}${url.search}`;

      const response = await fetch(targetUrl, {
        method: request.method,
        headers: {
          "Content-Type":
            request.headers.get("Content-Type") || "application/json",
          ...(request.headers.get("Authorization") && {
            Authorization: request.headers.get("Authorization")!,
          }),
          ...(request.headers.get("X-API-Key") && {
            "X-API-Key": request.headers.get("X-API-Key")!,
          }),
        },
        body:
          request.method !== "GET" && request.method !== "HEAD"
            ? await request.text()
            : undefined,
      });

      // Clone response with CORS headers
      const responseHeaders = new Headers(response.headers);
      Object.entries(corsHeaders).forEach(([key, value]) => {
        responseHeaders.set(key, value);
      });

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });
    } catch (error) {
      console.error("Proxy error:", error);
      return new Response(
        JSON.stringify({
          error: "Backend unavailable",
          details: String(error),
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  },
};
