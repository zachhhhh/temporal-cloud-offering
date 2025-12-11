

export const index = 0;
let component_cache;
export const component = async () => component_cache ??= (await import('../entries/pages/_layout.svelte.js')).default;
export const universal = {
  "prerender": true,
  "ssr": false
};
export const universal_id = "src/routes/+layout.ts";
export const imports = ["_app/immutable/nodes/0.D7MRI0vZ.js","_app/immutable/chunks/kzzh-_L7.js","_app/immutable/chunks/yF97ak1k.js","_app/immutable/chunks/8_kfmD-X.js","_app/immutable/chunks/DEa5TWVC.js","_app/immutable/chunks/CzlK3FID.js","_app/immutable/chunks/Bk5ptWNf.js","_app/immutable/chunks/CXoE5pbF.js","_app/immutable/chunks/C0gw4Bx3.js","_app/immutable/chunks/C8-YtTiG.js","_app/immutable/chunks/CGiklUNy.js","_app/immutable/chunks/473pHgqg.js","_app/immutable/chunks/BQTcrtsO.js","_app/immutable/chunks/vG9K1qYa.js","_app/immutable/chunks/CtKM0EkB.js","_app/immutable/chunks/DTTKcyLN.js"];
export const stylesheets = ["_app/immutable/assets/0.DcpbKdRl.css"];
export const fonts = [];
