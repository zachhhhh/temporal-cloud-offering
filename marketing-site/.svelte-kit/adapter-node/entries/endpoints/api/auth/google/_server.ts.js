import { redirect } from "@sveltejs/kit";
const GET = async ({ platform, url }) => {
  const env = platform?.env || {};
  const GOOGLE_CLIENT_ID = env.GOOGLE_CLIENT_ID || "";
  const baseUrl = url.origin;
  const REDIRECT_URI = env.GOOGLE_REDIRECT_URI || `${baseUrl}/api/auth/google/callback`;
  if (GOOGLE_CLIENT_ID) {
    const params = new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      response_type: "code",
      scope: "openid email profile",
      access_type: "offline",
      prompt: "consent"
    });
    throw redirect(
      302,
      `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`
    );
  }
  throw redirect(302, `${REDIRECT_URI}?code=sso_pending`);
};
export {
  GET
};
