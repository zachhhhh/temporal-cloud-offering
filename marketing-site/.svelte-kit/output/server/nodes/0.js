

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": true,
  "ssr": false
};
export const universal_id = "src/routes/+layout.ts";
export const imports = ["_app/immutable/nodes/0.CFNqgiyJ.js","_app/immutable/chunks/BWbQCZ69.js","_app/immutable/chunks/KVv5Wq5H.js","_app/immutable/chunks/Che9Dmhg.js","_app/immutable/chunks/CqPjbGvf.js","_app/immutable/chunks/ozNNVPW2.js","_app/immutable/chunks/eAXd7Ly4.js","_app/immutable/chunks/DL2-I4h1.js","_app/immutable/chunks/BdiaiBs7.js","_app/immutable/chunks/473pHgqg.js","_app/immutable/chunks/B5Bwh81o.js","_app/immutable/chunks/C2oB9cch.js","_app/immutable/chunks/CNgpWDSg.js"];
export const stylesheets = ["_app/immutable/assets/0.BZGZJCq8.css"];
export const fonts = [];
