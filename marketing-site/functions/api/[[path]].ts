// Cloudflare Pages Function to proxy API requests to OKE backend
// Use environment variable or fallback to demo mode
interface CFContext {
  request: Request;
  env: {
    OKE_BACKEND_URL?: string;
  };
  params: Record<string, string>;
}

export const onRequest = async (context: CFContext): Promise<Response> => {
  const url = new URL(context.request.url);
  const path = url.pathname.replace(/^\/api/, "");
  const backendUrl = context.env.OKE_BACKEND_URL;

  // CORS headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-API-Key",
    "Content-Type": "application/json",
  };

  if (!backendUrl) {
    return new Response(JSON.stringify({ error: "Backend not configured" }), {
      status: 500,
      headers: corsHeaders,
    });
  }

  try {
    const response = await fetch(`${backendUrl}/api/v1${path}${url.search}`, {
      method: context.request.method,
      headers: {
        "Content-Type": "application/json",
        ...(context.request.headers.get("Authorization") && {
          Authorization: context.request.headers.get("Authorization")!,
        }),
        ...(context.request.headers.get("X-API-Key") && {
          "X-API-Key": context.request.headers.get("X-API-Key")!,
        }),
      },
      body:
        context.request.method !== "GET"
          ? await context.request.text()
          : undefined,
    });

    return new Response(response.body, {
      status: response.status,
      headers: { ...corsHeaders, ...Object.fromEntries(response.headers) },
    });
  } catch (error) {
    console.error("Backend error:", error);
    return new Response(
      JSON.stringify({ error: "Backend unavailable", details: String(error) }),
      {
        status: 502,
        headers: corsHeaders,
      }
    );
  }
};

// Handle CORS preflight
export const onRequestOptions = async (): Promise<Response> => {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, X-API-Key",
      "Access-Control-Max-Age": "86400",
    },
  });
};
