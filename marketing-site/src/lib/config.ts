// Site configuration - Update these URLs to point to your services
export const config = {
  siteName: "Temporal Cloud",
  tagline: "Build Invincible Applications",

  // Your service URLs (update these for production)
  // NOTE: temporal-ui requires a Temporal server backend. Use admin-portal for standalone demo.
  // Once Temporal server is deployed, switch app URL to temporal-ui.
  urls: {
    // Admin portal for standalone billing/settings (until Temporal server is deployed)
    app:
      import.meta.env.VITE_APP_URL || "https://temporal-admin-portal.pages.dev",
    // Temporal UI - requires Temporal server backend
    temporalUI:
      import.meta.env.VITE_TEMPORAL_UI || "https://temporal-ui.pages.dev",
    // Use relative path for API - Cloudflare Pages Functions will proxy to OKE
    billingAPI: import.meta.env.VITE_BILLING_API || "",
    docs: "https://docs.temporal.io",
    community: "https://community.temporal.io",
    slack: "https://temporal.io/slack",
    github: "https://github.com/temporalio/temporal",
    youtube: "https://www.youtube.com/@temporalio",
    twitter: "https://twitter.com/temporalio",
    blog: "/blog",
  },

  // Demo video
  demoVideo: "https://youtu.be/dNVmRfWsNkM",

  // Company info
  company: {
    name: "Temporal Cloud",
    email: "support@temporal.cloud",
  },

  // Navigation links
  nav: [
    { label: "Product", href: "#product" },
    { label: "Use Cases", href: "#use-cases" },
    { label: "Pricing", href: "#pricing" },
    { label: "Docs", href: "https://docs.temporal.io", external: true },
    {
      label: "Community",
      href: "https://community.temporal.io",
      external: true,
    },
  ],

  // Pricing - matching temporal.io/pricing
  pricing: {
    actions: {
      price: 25,
      unit: "per million actions",
    },
    activeStorage: { price: 0.042, unit: "per GB-hour" },
    retainedStorage: { price: 0.00105, unit: "per GB-hour" },
  },
};
