const config = {
  siteName: "Temporal Cloud",
  // Your service URLs (update these for production)
  urls: {
    // Temporal UI on Oracle Cloud - main app (like cloud.temporal.io)
    app: "http://152.69.216.238",
    docs: "https://docs.temporal.io",
    community: "https://community.temporal.io",
    slack: "https://temporal.io/slack",
    github: "https://github.com/temporalio/temporal",
    youtube: "https://www.youtube.com/@temporalio",
    twitter: "https://twitter.com/temporalio"
  },
  // Company info
  company: {
    email: "support@temporal.cloud"
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
      external: true
    }
  ],
  // Pricing - matching temporal.io/pricing
  pricing: {
    actions: {
      price: 25,
      unit: "per million actions"
    },
    activeStorage: { price: 0.042, unit: "per GB-hour" },
    retainedStorage: { price: 105e-5, unit: "per GB-hour" }
  }
};
export {
  config as c
};
