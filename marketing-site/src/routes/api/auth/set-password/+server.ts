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

    // Hash the new password
    const hashedPassword = await hashPassword(new_password);

    // Store in KV if available
    if (env.KV) {
      // Check if user already has a password
      const existingData = await env.KV.get(`user:${email}`);
      if (existingData) {
        const userData = JSON.parse(existingData);
        if (userData.password && current_password) {
          // Verify current password
          const hashedCurrent = await hashPassword(current_password);
          if (hashedCurrent !== userData.password) {
            return json(
              { error: "Current password is incorrect" },
              { status: 400 }
            );
          }
        }
        // Update password
        userData.password = hashedPassword;
        await env.KV.put(`user:${email}`, JSON.stringify(userData));
      } else {
        // Create new user record
        await env.KV.put(
          `user:${email}`,
          JSON.stringify({
            email,
            password: hashedPassword,
            createdAt: new Date().toISOString(),
          })
        );
      }
    }

    // Update auth cookie to indicate user has password
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
          maxAge: 60 * 60 * 24 * 7,
        });
      } catch (e) {
        // Ignore parse errors
      }
    }

    return json({ success: true, message: "Password set successfully" });
  } catch (err) {
    console.error("Set password error:", err);
    return json({ error: "Failed to set password" }, { status: 500 });
  }
};
