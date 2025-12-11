export const manifest = (() => {
function __memo(fn) {
	let value;
	return () => value ??= (value = fn());
}

return {
	appDir: "_app",
	appPath: "_app",
	assets: new Set(["favicon.png"]),
	mimeTypes: {".png":"image/png"},
	_: {
		client: {start:"_app/immutable/entry/start.DNThgGj5.js",app:"_app/immutable/entry/app.C3ajON1u.js",imports:["_app/immutable/entry/start.DNThgGj5.js","_app/immutable/chunks/vG9K1qYa.js","_app/immutable/chunks/yF97ak1k.js","_app/immutable/chunks/CGiklUNy.js","_app/immutable/chunks/CtKM0EkB.js","_app/immutable/chunks/DTTKcyLN.js","_app/immutable/entry/app.C3ajON1u.js","_app/immutable/chunks/yF97ak1k.js","_app/immutable/chunks/kzzh-_L7.js","_app/immutable/chunks/DTTKcyLN.js","_app/immutable/chunks/CzlK3FID.js","_app/immutable/chunks/C8-YtTiG.js","_app/immutable/chunks/CGiklUNy.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./nodes/0.js')),
			__memo(() => import('./nodes/1.js'))
		],
		remotes: {
			
		},
		routes: [
			{
				id: "/api/auth/google",
				pattern: /^\/api\/auth\/google\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/google/_server.ts.js'))
			},
			{
				id: "/api/auth/google/callback",
				pattern: /^\/api\/auth\/google\/callback\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/google/callback/_server.ts.js'))
			},
			{
				id: "/api/auth/login",
				pattern: /^\/api\/auth\/login\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/login/_server.ts.js'))
			},
			{
				id: "/api/auth/magic-link",
				pattern: /^\/api\/auth\/magic-link\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/magic-link/_server.ts.js'))
			},
			{
				id: "/api/auth/set-password",
				pattern: /^\/api\/auth\/set-password\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/set-password/_server.ts.js'))
			},
			{
				id: "/api/auth/signup",
				pattern: /^\/api\/auth\/signup\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/signup/_server.ts.js'))
			},
			{
				id: "/api/auth/verify",
				pattern: /^\/api\/auth\/verify\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/verify/_server.ts.js'))
			}
		],
		prerendered_routes: new Set(["/","/auth/verify","/dashboard","/dashboard/batch-operations","/dashboard/billing","/dashboard/namespaces","/dashboard/schedules","/dashboard/settings","/dashboard/settings/security","/dashboard/ui","/login","/signup"]),
		matchers: async () => {
			
			return {  };
		},
		server_assets: {}
	}
}
})();
