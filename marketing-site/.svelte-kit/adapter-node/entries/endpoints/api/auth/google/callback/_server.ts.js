import { redirect } from "@sveltejs/kit";
const GET = async ({ url, cookies, platform }) => {
  const env = platform?.env || {};
  const GOOGLE_CLIENT_ID = env.GOOGLE_CLIENT_ID || "";
  const GOOGLE_CLIENT_SECRET = env.GOOGLE_CLIENT_SECRET || "";
  const REDIRECT_URI = env.GOOGLE_REDIRECT_URI || "https://temporal-cloud-marketing.pages.dev/api/auth/google/callback";
  const code = url.searchParams.get("code");
  const error = url.searchParams.get("error");
  if (error) {
    throw redirect(302, `/login?error=${error}`);
  }
  if (!code) {
    throw redirect(302, "/login?error=no_code");
  }
  if (code === "sso_pending") {
    throw redirect(302, "/login?error=sso_not_configured");
  }
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: REDIRECT_URI,
      grant_type: "authorization_code"
    })
  });
  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    console.error("Token exchange failed:", errorText);
    throw redirect(302, "/login?error=oauth_failed");
  }
  const tokens = await tokenResponse.json();
  const userResponse = await fetch(
    "https://www.googleapis.com/oauth2/v2/userinfo",
    {
      headers: { Authorization: `Bearer ${tokens.access_token}` }
    }
  );
  if (!userResponse.ok) {
    console.error("Failed to get user info");
    throw redirect(302, "/login?error=oauth_failed");
  }
  const userInfo = await userResponse.json();
  const userData = {
    email: userInfo.email,
    name: userInfo.name,
    avatar: userInfo.picture,
    provider: "google"
  };
  cookies.set("auth", JSON.stringify(userData), {
    path: "/",
    httpOnly: false,
    // Allow client-side access for SvelteKit store
    secure: true,
    sameSite: "lax",
    maxAge: 60 * 60 * 24 * 7
    // 7 days
  });
  throw redirect(302, "/dashboard");
};
export {
  GET
};
