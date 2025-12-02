/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  tutorialSidebar: [
    "intro",
    {
      type: "category",
      label: "Getting Started",
      items: [
        "getting-started/quickstart",
        "getting-started/concepts",
        "getting-started/first-workflow",
      ],
    },
    {
      type: "category",
      label: "SDKs",
      items: ["sdks/go", "sdks/typescript", "sdks/python", "sdks/java"],
    },
    {
      type: "category",
      label: "Workflows",
      items: [
        "workflows/basics",
        "workflows/signals",
        "workflows/queries",
        "workflows/child-workflows",
      ],
    },
    {
      type: "category",
      label: "Activities",
      items: [
        "activities/basics",
        "activities/retries",
        "activities/heartbeats",
      ],
    },
    {
      type: "category",
      label: "Billing",
      items: ["billing/pricing", "billing/usage", "billing/invoices"],
    },
    {
      type: "category",
      label: "API Reference",
      items: ["api/rest-api", "api/grpc-api"],
    },
  ],
};

module.exports = sidebars;
