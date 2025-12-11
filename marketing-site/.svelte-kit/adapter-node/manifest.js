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
		client: {start:"_app/immutable/entry/start.BYVtQMiZ.js",app:"_app/immutable/entry/app.Bz8zx8p8.js",imports:["_app/immutable/entry/start.BYVtQMiZ.js","_app/immutable/chunks/BZJQbgUP.js","_app/immutable/chunks/CzH386r8.js","_app/immutable/chunks/PdjtNgFh.js","_app/immutable/chunks/LTp3URAE.js","_app/immutable/entry/app.Bz8zx8p8.js","_app/immutable/chunks/CzH386r8.js","_app/immutable/chunks/DTs5imaO.js","_app/immutable/chunks/CiFOpYSw.js","_app/immutable/chunks/WkpRxZnY.js","_app/immutable/chunks/Bzak7iHL.js","_app/immutable/chunks/LTp3URAE.js","_app/immutable/chunks/FM7WOqsO.js","_app/immutable/chunks/DjKjOODG.js","_app/immutable/chunks/PdjtNgFh.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
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
				id: "/api/auth/verify",
				pattern: /^\/api\/auth\/verify\/?$/,
				params: [],
				page: null,
				endpoint: __memo(() => import('./entries/endpoints/api/auth/verify/_server.ts.js'))
			}
		],
		prerendered_routes: new Set(["/","/auth/verify","/dashboard","/dashboard/batch-operations","/dashboard/billing","/dashboard/namespaces","/dashboard/schedules","/dashboard/settings","/dashboard/settings/security","/dashboard/ui","/login"]),
		matchers: async () => {
			
			return {  };
		},
		server_assets: {}
	}
}
})();

export const prerendered = new Set(["/","/auth/verify","/dashboard","/dashboard/batch-operations","/dashboard/billing","/dashboard/namespaces","/dashboard/schedules","/dashboard/settings","/dashboard/settings/security","/dashboard/ui","/login"]);

export const base = "";