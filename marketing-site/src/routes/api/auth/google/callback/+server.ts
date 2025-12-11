import { redirect } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async ({ url, cookies, platform }) => {
  const env = platform?.env || {};
  const GOOGLE_CLIENT_ID = env.GOOGLE_CLIENT_ID || "";
  const GOOGLE_CLIENT_SECRET = env.GOOGLE_CLIENT_SECRET || "";
  const REDIRECT_URI =
    env.GOOGLE_REDIRECT_URI ||
    "https://temporal-cloud-marketing.pages.dev/api/auth/google/callback";

  const code = url.searchParams.get("code");
  const error = url.searchParams.get("error");

  if (error) {
    throw redirect(302, `/login?error=${error}`);
  }

  if (!code) {
    throw redirect(302, "/login?error=no_code");
  }

  // Handle SSO pending state (when Google OAuth is not configured)
  if (code === "sso_pending") {
    throw redirect(302, "/login?error=sso_not_configured");
  }

  // Exchange code for tokens
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: REDIRECT_URI,
      grant_type: "authorization_code",
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    console.error("Token exchange failed:", errorText);
    throw redirect(302, "/login?error=oauth_failed");
  }

  const tokens = await tokenResponse.json();

  // Get user info
  const userResponse = await fetch(
    "https://www.googleapis.com/oauth2/v2/userinfo",
    {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    }
  );

  if (!userResponse.ok) {
    console.error("Failed to get user info");
    throw redirect(302, "/login?error=oauth_failed");
  }

  const userInfo = await userResponse.json();

  // Set auth cookie with user data
  const userData = {
    email: userInfo.email,
    name: userInfo.name,
    avatar: userInfo.picture,
    provider: "google",
  };

  cookies.set("auth", JSON.stringify(userData), {
    path: "/",
    httpOnly: false, // Allow client-side access for SvelteKit store
    secure: true,
    sameSite: "lax",
    maxAge: 60 * 60 * 24 * 7, // 7 days
  });

  throw redirect(302, "/dashboard");
};
