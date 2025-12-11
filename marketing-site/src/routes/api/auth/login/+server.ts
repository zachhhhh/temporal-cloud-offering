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

    // Demo mode - accept any login for testing
    // TODO: Enable KV-based auth when ready for production
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
  } catch (err) {
    console.error("Login error:", err);
    return json({ error: "Login failed" }, { status: 500 });
  }
};
