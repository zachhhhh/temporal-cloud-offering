import { json } from "@sveltejs/kit";
const GET = async ({ url, platform }) => {
  const env = platform?.env || {};
  const token = url.searchParams.get("token");
  const email = url.searchParams.get("email");
  const type = url.searchParams.get("type") || "magic_link";
  if (!token || !email) {
    return json({ error: "Invalid verification link" }, { status: 400 });
  }
  if (env.KV) {
    if (type === "signup") {
      const tokenData2 = await env.KV.get(`verification:${token}`);
      if (!tokenData2) {
        return json(
          { error: "Invalid or expired verification link" },
          { status: 400 }
        );
      }
      const data2 = JSON.parse(tokenData2);
      if (data2.email !== email) {
        return json({ error: "Invalid link" }, { status: 400 });
      }
      if (Date.now() > data2.expiresAt) {
        await env.KV.delete(`verification:${token}`);
        return json(
          { error: "Verification link has expired" },
          { status: 400 }
        );
      }
      const pendingUserData = await env.KV.get(`pending_user:${email}`);
      if (pendingUserData) {
        const pendingUser = JSON.parse(pendingUserData);
        pendingUser.verified = true;
        pendingUser.verifiedAt = Date.now();
        await env.KV.put(`user:${email}`, JSON.stringify(pendingUser));
        await env.KV.delete(`pending_user:${email}`);
      }
      await env.KV.delete(`verification:${token}`);
      return json({
        success: true,
        verified: true,
        message: "Email verified successfully. You can now sign in.",
        user: { email, name: email.split("@")[0] }
      });
    }
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
    await env.KV.delete(`magic_link:${token}`);
  }
  const user = {
    email,
    name: email.split("@")[0],
    provider: "email"
  };
  return json({ success: true, user });
};
export {
  GET
};
