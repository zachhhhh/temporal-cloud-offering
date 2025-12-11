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
		client: {start:"_app/immutable/entry/start.D7c543dy.js",app:"_app/immutable/entry/app.D3TPfVeC.js",imports:["_app/immutable/entry/start.D7c543dy.js","_app/immutable/chunks/C2oB9cch.js","_app/immutable/chunks/KVv5Wq5H.js","_app/immutable/chunks/eAXd7Ly4.js","_app/immutable/chunks/CNgpWDSg.js","_app/immutable/entry/app.D3TPfVeC.js","_app/immutable/chunks/KVv5Wq5H.js","_app/immutable/chunks/BWbQCZ69.js","_app/immutable/chunks/CNgpWDSg.js","_app/immutable/chunks/ozNNVPW2.js","_app/immutable/chunks/eAXd7Ly4.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
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
