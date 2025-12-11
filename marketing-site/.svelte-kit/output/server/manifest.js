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
		client: {start:"_app/immutable/entry/start.BMygj1mk.js",app:"_app/immutable/entry/app.DWi8kFq2.js",imports:["_app/immutable/entry/start.BMygj1mk.js","_app/immutable/chunks/2ZD9iXh7.js","_app/immutable/chunks/OpDIeaVH.js","_app/immutable/chunks/COxHBxUK.js","_app/immutable/chunks/BwOv3IO7.js","_app/immutable/entry/app.DWi8kFq2.js","_app/immutable/chunks/OpDIeaVH.js","_app/immutable/chunks/BMDhiZVf.js","_app/immutable/chunks/BwOv3IO7.js","_app/immutable/chunks/Is5Z81B9.js","_app/immutable/chunks/COxHBxUK.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
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
