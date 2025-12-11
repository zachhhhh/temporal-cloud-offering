

export const index = 5;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/dashboard/_page.svelte.js')).default;
export const imports = ["_app/immutable/nodes/5.CEdtVfvQ.js","_app/immutable/chunks/Bzak7iHL.js","_app/immutable/chunks/SZhCIaWg.js","_app/immutable/chunks/CzH386r8.js","_app/immutable/chunks/D4bWfIaA.js"];
export const stylesheets = [];
export const fonts = [];
