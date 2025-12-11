

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": true,
  "ssr": false
};
export const universal_id = "src/routes/+layout.ts";
export const imports = ["_app/immutable/nodes/0.CLFAgoP0.js","_app/immutable/chunks/Bzak7iHL.js","_app/immutable/chunks/SZhCIaWg.js","_app/immutable/chunks/CzH386r8.js","_app/immutable/chunks/DTs5imaO.js","_app/immutable/chunks/CiFOpYSw.js","_app/immutable/chunks/WkpRxZnY.js","_app/immutable/chunks/DLqRUzrJ.js","_app/immutable/chunks/FM7WOqsO.js","_app/immutable/chunks/D4bWfIaA.js","_app/immutable/chunks/CWUSDlSs.js","_app/immutable/chunks/Erm0fwTT.js","_app/immutable/chunks/DjKjOODG.js","_app/immutable/chunks/PdjtNgFh.js","_app/immutable/chunks/C-52dS8W.js","_app/immutable/chunks/BDhEFcsG.js","_app/immutable/chunks/BZJQbgUP.js","_app/immutable/chunks/LTp3URAE.js"];
export const stylesheets = ["_app/immutable/assets/0.CFGKW3vc.css"];
export const fonts = [];
