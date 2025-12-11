

export const index = 5;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/dashboard/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/5.CWKBhgbK.js","_app/immutable/chunks/BMDhiZVf.js","_app/immutable/chunks/OpDIeaVH.js","_app/immutable/chunks/BPZvvf-C.js","_app/immutable/chunks/BwOv3IO7.js","_app/immutable/chunks/BmY4_E-U.js"];
export const stylesheets = [];
export const fonts = [];
