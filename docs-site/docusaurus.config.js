// @ts-check
/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "Your Temporal Cloud",
  tagline: "Durable workflow execution platform",
  favicon: "img/favicon.ico",

  // Set the production url of your site here
  url: "https://docs.yourdomain.com",
  baseUrl: "/",

  // GitHub pages deployment config (if using)
  organizationName: "your-org",
  projectName: "temporal-cloud-docs",

  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",

  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: "./sidebars.js",
          routeBasePath: "/",
        },
        blog: {
          showReadingTime: true,
          routeBasePath: "/changelog",
          blogTitle: "Changelog",
          blogDescription: "Product updates and releases",
        },
        theme: {
          customCss: "./src/css/custom.css",
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: "Your Temporal Cloud",
        logo: {
          alt: "Logo",
          src: "img/logo.svg",
        },
        items: [
          {
            type: "docSidebar",
            sidebarId: "tutorialSidebar",
            position: "left",
            label: "Documentation",
          },
          { to: "/changelog", label: "Changelog", position: "left" },
          {
            href: "https://admin.yourdomain.com",
            label: "Dashboard",
            position: "right",
          },
          {
            href: "https://status.yourdomain.com",
            label: "Status",
            position: "right",
          },
        ],
      },
      footer: {
        style: "dark",
        links: [
          {
            title: "Documentation",
            items: [
              { label: "Getting Started", to: "/getting-started" },
              { label: "SDKs", to: "/sdks" },
              { label: "API Reference", to: "/api" },
            ],
          },
          {
            title: "Resources",
            items: [
              { label: "Pricing", to: "/pricing" },
              { label: "Changelog", to: "/changelog" },
              { label: "Status", href: "https://status.yourdomain.com" },
            ],
          },
          {
            title: "Support",
            items: [
              { label: "Contact Us", href: "mailto:support@yourdomain.com" },
              {
                label: "Community Forum",
                href: "https://community.yourdomain.com",
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Your Company. All rights reserved.`,
      },
      prism: {
        theme: require("prism-react-renderer").themes.github,
        darkTheme: require("prism-react-renderer").themes.dracula,
        additionalLanguages: ["go", "java", "typescript", "python"],
      },
    }),
};

module.exports = config;
