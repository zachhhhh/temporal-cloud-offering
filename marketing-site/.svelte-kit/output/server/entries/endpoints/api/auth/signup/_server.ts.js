import { json } from "@sveltejs/kit";
function generateToken() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join(
    ""
  );
}
async function hashPassword(password) {
  const encoder = new TextEncoder();
  const data = encoder.encode(password);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}
const POST = async ({ request, platform, url }) => {
  try {
    const env = platform?.env || {};
    const { email, name, password } = await request.json();
    if (!email || !email.includes("@")) {
      return json({ error: "Invalid email address" }, { status: 400 });
    }
    if (!password || password.length < 8) {
      return json(
        { error: "Password must be at least 8 characters" },
        { status: 400 }
      );
    }
    const verificationToken = generateToken();
    const hashedPassword = await hashPassword(password);
    const expiresAt = Date.now() + 24 * 60 * 60 * 1e3;
    const pendingUser = {
      email,
      name: name || email.split("@")[0],
      password: hashedPassword,
      verified: false,
      createdAt: Date.now()
    };
    if (env.KV) {
      const existingUser = await env.KV.get(`user:${email}`);
      if (existingUser) {
        return json(
          { error: "An account with this email already exists" },
          { status: 400 }
        );
      }
      await env.KV.put(
        `verification:${verificationToken}`,
        JSON.stringify({ email, expiresAt }),
        { expirationTtl: 86400 }
      );
      await env.KV.put(`pending_user:${email}`, JSON.stringify(pendingUser), {
        expirationTtl: 86400
      });
    }
    const baseUrl = url.origin;
    const verifyLink = `${baseUrl}/auth/verify?token=${verificationToken}&email=${encodeURIComponent(
      email
    )}&type=signup`;
    const resendKey = env.RESEND_API_KEY;
    if (resendKey) {
      const emailResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          from: "Temporal Cloud <onboarding@resend.dev>",
          to: [email],
          subject: "Verify your Temporal Cloud account",
          html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0f0a1f; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0f0a1f; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" max-width="520" cellpadding="0" cellspacing="0" style="max-width: 520px;">
          <!-- Logo -->
          <tr>
            <td align="center" style="padding-bottom: 32px;">
              <div style="display: inline-flex; align-items: center; gap: 8px;">
                <div style="width: 36px; height: 36px; background: linear-gradient(135deg, #10b981, #06b6d4); border-radius: 8px;"></div>
                <span style="color: #ffffff; font-size: 22px; font-weight: 700; letter-spacing: -0.5px;">Temporal Cloud</span>
              </div>
            </td>
          </tr>
          
          <!-- Main Card -->
          <tr>
            <td style="background: linear-gradient(180deg, #1a1030 0%, #150d28 100%); border: 1px solid rgba(255,255,255,0.1); border-radius: 16px; padding: 40px;">
              <h1 style="margin: 0 0 16px; color: #ffffff; font-size: 24px; font-weight: 600; text-align: center;">
                Welcome to Temporal Cloud!
              </h1>
              <p style="margin: 0 0 8px; color: #a1a1aa; font-size: 15px; line-height: 1.6; text-align: center;">
                Hi ${name || email.split("@")[0]},
              </p>
              <p style="margin: 0 0 32px; color: #a1a1aa; font-size: 15px; line-height: 1.6; text-align: center;">
                Thanks for signing up! Please verify your email address by clicking the button below.
              </p>
              
              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <a href="${verifyLink}" style="display: inline-block; background: linear-gradient(135deg, #10b981, #06b6d4); color: #000000; font-size: 15px; font-weight: 600; text-decoration: none; padding: 14px 32px; border-radius: 8px; box-shadow: 0 4px 14px rgba(16, 185, 129, 0.3);">
                      Verify Email Address →
                    </a>
                  </td>
                </tr>
              </table>
              
              <!-- Divider -->
              <div style="margin: 32px 0; border-top: 1px solid rgba(255,255,255,0.1);"></div>
              
              <!-- Alternative Link -->
              <p style="margin: 0 0 12px; color: #71717a; font-size: 13px; text-align: center;">
                Or copy and paste this URL into your browser:
              </p>
              <p style="margin: 0; color: #10b981; font-size: 12px; word-break: break-all; text-align: center; background: rgba(16, 185, 129, 0.1); padding: 12px; border-radius: 6px;">
                ${verifyLink}
              </p>
              
              <p style="margin: 24px 0 0; color: #52525b; font-size: 13px; text-align: center;">
                This link will expire in 24 hours.
              </p>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding-top: 32px; text-align: center;">
              <p style="margin: 0 0 8px; color: #52525b; font-size: 13px;">
                Didn't create an account? You can safely ignore this email.
              </p>
              <p style="margin: 0; color: #3f3f46; font-size: 12px;">
                © ${(/* @__PURE__ */ new Date()).getFullYear()} Temporal Technologies Inc. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
          `
        })
      });
      if (!emailResponse.ok) {
        const errorText = await emailResponse.text();
        console.error("Resend API error:", errorText);
      } else {
        return json({
          success: true,
          message: "Verification email sent. Please check your inbox."
        });
      }
    }
    if (env.KV) {
      const userData = {
        email,
        name: name || email.split("@")[0],
        password: hashedPassword,
        verified: true,
        // Auto-verify in demo mode
        createdAt: Date.now()
      };
      await env.KV.put(`user:${email}`, JSON.stringify(userData));
    }
    return json({
      success: true,
      message: "Account created successfully! You can now sign in.",
      demoMode: true
    });
  } catch (err) {
    console.error("Signup error:", err);
    return json({ error: "Signup failed" }, { status: 500 });
  }
};
export {
  POST
};
