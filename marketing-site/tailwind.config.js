/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{html,js,svelte,ts}"],
  theme: {
    extend: {
      colors: {
        temporal: {
          purple: "#7c3aed",
          dark: "#0f0f0f",
          gray: "#1a1a1a",
        },
      },
    },
  },
  plugins: [],
};
