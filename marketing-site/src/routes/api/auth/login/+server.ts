import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export const POST: RequestHandler = async ({ request, platform, cookies }) => {
  try {
    const env = platform?.env || {};
    const { email, password } = await request.json();

    if (!email || !password) {
      return json(
        { error: "Email and password are required" },
        { status: 400 }
      );
    }

    // Hash the provided password
    const hashedPassword = await hashPassword(password);

    // Check credentials in KV
    if (env.KV) {
      const userData = await env.KV.get(`user:${email}`);
      if (!userData) {
        return json({ error: "Invalid email or password" }, { status: 401 });
      }

      const user = JSON.parse(userData);
      if (!user.password || user.password !== hashedPassword) {
        return json({ error: "Invalid email or password" }, { status: 401 });
      }

      // Set auth cookie
      const authData = {
        email: email,
        name: user.name || email.split("@")[0],
        provider: "email",
        hasPassword: true,
      };

      cookies.set("auth", JSON.stringify(authData), {
        path: "/",
        httpOnly: false,
        secure: true,
        sameSite: "lax",
        maxAge: 60 * 60 * 24 * 7, // 7 days
      });

      return json({ success: true, user: authData });
    } else {
      // Demo mode without KV - accept any login for testing
      const authData = {
        email: email,
        name: email.split("@")[0],
        provider: "email",
        hasPassword: true,
      };

      cookies.set("auth", JSON.stringify(authData), {
        path: "/",
        httpOnly: false,
        secure: true,
        sameSite: "lax",
        maxAge: 60 * 60 * 24 * 7,
      });

      return json({ success: true, user: authData });
    }
  } catch (err) {
    console.error("Login error:", err);
    return json({ error: "Login failed" }, { status: 500 });
  }
};
