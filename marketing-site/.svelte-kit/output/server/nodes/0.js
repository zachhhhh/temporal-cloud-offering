

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": true,
  "ssr": false
};
export const universal_id = "src/routes/+layout.ts";
export const imports = ["_app/immutable/nodes/0.DbsQRend.js","_app/immutable/chunks/BMDhiZVf.js","_app/immutable/chunks/OpDIeaVH.js","_app/immutable/chunks/BPZvvf-C.js","_app/immutable/chunks/kn1poJoi.js","_app/immutable/chunks/Is5Z81B9.js","_app/immutable/chunks/COxHBxUK.js","_app/immutable/chunks/DXU610Kk.js","_app/immutable/chunks/BmY4_E-U.js","_app/immutable/chunks/BD1ZCLaQ.js","_app/immutable/chunks/2ZD9iXh7.js","_app/immutable/chunks/BwOv3IO7.js"];
export const stylesheets = ["_app/immutable/assets/0.QX3SwbS5.css"];
export const fonts = [];
