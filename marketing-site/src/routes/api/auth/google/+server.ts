import { redirect } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async ({ platform, url }) => {
  const env = platform?.env || {};
  const GOOGLE_CLIENT_ID = env.GOOGLE_CLIENT_ID || "";
  const baseUrl = url.origin;
  const REDIRECT_URI =
    env.GOOGLE_REDIRECT_URI || `${baseUrl}/api/auth/google/callback`;

  // If Google OAuth is configured, redirect to Google
  if (GOOGLE_CLIENT_ID) {
    const params = new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      response_type: "code",
      scope: "openid email profile",
      access_type: "offline",
      prompt: "consent",
    });
    throw redirect(
      302,
      `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`
    );
  }

  // Fallback: redirect to callback with a special code for SSO simulation
  // This allows the system to work before Google OAuth is configured
  throw redirect(302, `${REDIRECT_URI}?code=sso_pending`);
};
