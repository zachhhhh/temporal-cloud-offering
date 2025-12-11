import { json } from "@sveltejs/kit";
async function hashPassword(password) {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
const POST = async ({ request, platform, cookies }) => {
  try {
    const env = platform?.env || {};
    const { email, current_password, new_password } = await request.json();
    if (!email || !new_password) {
      return json(
        { error: "Email and password are required" },
        { status: 400 }
      );
    }
    if (new_password.length < 8) {
      return json(
        { error: "Password must be at least 8 characters" },
        { status: 400 }
      );
    }
    const hashedPassword = await hashPassword(new_password);
    if (env.KV) {
      const existingData = await env.KV.get(`user:${email}`);
      if (existingData) {
        const userData = JSON.parse(existingData);
        if (userData.password && current_password) {
          const hashedCurrent = await hashPassword(current_password);
          if (hashedCurrent !== userData.password) {
            return json(
              { error: "Current password is incorrect" },
              { status: 400 }
            );
          }
        }
        userData.password = hashedPassword;
        await env.KV.put(`user:${email}`, JSON.stringify(userData));
      } else {
        await env.KV.put(
          `user:${email}`,
          JSON.stringify({
            email,
            password: hashedPassword,
            createdAt: (/* @__PURE__ */ new Date()).toISOString()
          })
        );
      }
    }
    const authCookie = cookies.get("auth");
    if (authCookie) {
      try {
        const authData = JSON.parse(authCookie);
        authData.hasPassword = true;
        cookies.set("auth", JSON.stringify(authData), {
          path: "/",
          httpOnly: false,
          secure: true,
          sameSite: "lax",
          maxAge: 60 * 60 * 24 * 7
        });
      } catch (e) {
      }
    }
    return json({ success: true, message: "Password set successfully" });
  } catch (err) {
    console.error("Set password error:", err);
    return json({ error: "Failed to set password" }, { status: 500 });
  }
};
export {
  POST
};
