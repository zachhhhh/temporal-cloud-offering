import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async ({ url, platform }) => {
  const env = platform?.env || {};
  const token = url.searchParams.get("token");
  const email = url.searchParams.get("email");
  const type = url.searchParams.get("type") || "magic_link";

  if (!token || !email) {
    return json({ error: "Invalid verification link" }, { status: 400 });
  }

  if (env.KV) {
    // Check for signup verification token
    if (type === "signup") {
      const tokenData = await env.KV.get(`verification:${token}`);
      if (!tokenData) {
        return json(
          { error: "Invalid or expired verification link" },
          { status: 400 }
        );
      }

      const data = JSON.parse(tokenData);
      if (data.email !== email) {
        return json({ error: "Invalid link" }, { status: 400 });
      }

      if (Date.now() > data.expiresAt) {
        await env.KV.delete(`verification:${token}`);
        return json(
          { error: "Verification link has expired" },
          { status: 400 }
        );
      }

      // Get pending user data and activate account
      const pendingUserData = await env.KV.get(`pending_user:${email}`);
      if (pendingUserData) {
        const pendingUser = JSON.parse(pendingUserData);
        pendingUser.verified = true;
        pendingUser.verifiedAt = Date.now();

        // Move to active users
        await env.KV.put(`user:${email}`, JSON.stringify(pendingUser));
        await env.KV.delete(`pending_user:${email}`);
      }

      // Delete used token
      await env.KV.delete(`verification:${token}`);

      return json({
        success: true,
        verified: true,
        message: "Email verified successfully. You can now sign in.",
        user: { email, name: email.split("@")[0] },
      });
    }

    // Magic link verification
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
