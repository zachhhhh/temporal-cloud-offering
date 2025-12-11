import { json } from "@sveltejs/kit";
const GET = async ({ url, platform }) => {
  const env = platform?.env || {};
  const token = url.searchParams.get("token");
  const email = url.searchParams.get("email");
  if (!token || !email) {
    return json({ error: "Invalid verification link" }, { status: 400 });
  }
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
