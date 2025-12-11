

export const index = 10;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/dashboard/settings/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/10.CoUGihGJ.js","_app/immutable/chunks/BMDhiZVf.js","_app/immutable/chunks/OpDIeaVH.js","_app/immutable/chunks/BPZvvf-C.js","_app/immutable/chunks/BwOv3IO7.js","_app/immutable/chunks/BtkkMSFB.js"];
export const stylesheets = [];
export const fonts = [];
