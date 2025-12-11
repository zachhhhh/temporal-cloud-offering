import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async ({ url, platform }) => {
  const env = platform?.env || {};
  const token = url.searchParams.get("token");
  const email = url.searchParams.get("email");

  if (!token || !email) {
    return json({ error: "Invalid verification link" }, { status: 400 });
  }

  // For demo without KV, just accept any token and log the user in
  // In production, you would verify against KV storage
  if (env.KV) {
    const tokenData = await env.KV.get(`magic_link:${token}`);
    if (!tokenData) {
      return json({ error: "Invalid or expired link" }, { status: 400 });
    }

    const data = JSON.parse(tokenData);
    if (data.email !== email) {
      return json({ error: "Invalid link" }, { status: 400 });
    }

    if (Date.now() > data.expiresAt) {
      await env.KV.delete(`magic_link:${token}`);
      return json({ error: "Link has expired" }, { status: 400 });
    }

    // Delete used token
    await env.KV.delete(`magic_link:${token}`);
  }

  // Return user data for client-side login
  const user = {
    email: email,
    name: email.split("@")[0],
    provider: "email" as const,
  };

  return json({ success: true, user });
};
