// Site configuration - Update these URLs to point to your services
export const config = {
  siteName: "Temporal Cloud",
  tagline: "Build Invincible Applications",

  // Your service URLs (update these for production)
  urls: {
    // Temporal UI on Oracle Cloud - includes billing, usage, settings
    app: import.meta.env.VITE_APP_URL || "http://152.69.216.238/cloud/billing",
    // Temporal UI - main workflows interface
    temporalUI: import.meta.env.VITE_TEMPORAL_UI || "http://152.69.216.238",
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
