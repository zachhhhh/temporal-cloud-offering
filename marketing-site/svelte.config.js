import adapterNode from "@sveltejs/adapter-node";
import adapterCloudflare from "@sveltejs/adapter-cloudflare";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

// Use Node adapter for Oracle/Docker deployment, Cloudflare for Pages
const useNodeAdapter = process.env.BUILD_ADAPTER === "node";

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: useNodeAdapter
      ? adapterNode({
          out: "build",
          precompress: true,
        })
      : adapterCloudflare({
          routes: {
            include: ["/*"],
            exclude: ["<all>"],
          },
        }),
    prerender: {
      handleHttpError: "warn",
    },
  },
};

export default config;
