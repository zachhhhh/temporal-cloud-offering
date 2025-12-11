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
		client: {start:"_app/immutable/entry/start.CeZQ4IWY.js",app:"_app/immutable/entry/app.0tN5ipoS.js",imports:["_app/immutable/entry/start.CeZQ4IWY.js","_app/immutable/chunks/D-3zrxhC.js","_app/immutable/chunks/KVv5Wq5H.js","_app/immutable/chunks/eAXd7Ly4.js","_app/immutable/chunks/CNgpWDSg.js","_app/immutable/entry/app.0tN5ipoS.js","_app/immutable/chunks/KVv5Wq5H.js","_app/immutable/chunks/BWbQCZ69.js","_app/immutable/chunks/CNgpWDSg.js","_app/immutable/chunks/ozNNVPW2.js","_app/immutable/chunks/eAXd7Ly4.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./nodes/0.js')),
			__memo(() => import('./nodes/1.js')),
			__memo(() => import('./nodes/2.js')),
			__memo(() => import('./nodes/3.js')),
			__memo(() => import('./nodes/4.js')),
			__memo(() => import('./nodes/5.js')),
			__memo(() => import('./nodes/6.js')),
			__memo(() => import('./nodes/7.js')),
			__memo(() => import('./nodes/8.js')),
			__memo(() => import('./nodes/9.js')),
			__memo(() => import('./nodes/10.js')),
			__memo(() => import('./nodes/11.js')),
			__memo(() => import('./nodes/12.js')),
			__memo(() => import('./nodes/13.js'))
		],
		remotes: {
			
		},
		routes: [
			{
				id: "/",
				pattern: /^\/$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 3 },
				endpoint: null
			},
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
			},
			{
				id: "/auth/verify",
				pattern: /^\/auth\/verify\/?$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 4 },
				endpoint: null
			},
			{
				id: "/dashboard",
				pattern: /^\/dashboard\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 5 },
				endpoint: null
			},
			{
				id: "/dashboard/batch-operations",
				pattern: /^\/dashboard\/batch-operations\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 6 },
				endpoint: null
			},
			{
				id: "/dashboard/billing",
				pattern: /^\/dashboard\/billing\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 7 },
				endpoint: null
			},
			{
				id: "/dashboard/namespaces",
				pattern: /^\/dashboard\/namespaces\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 8 },
				endpoint: null
			},
			{
				id: "/dashboard/schedules",
				pattern: /^\/dashboard\/schedules\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 9 },
				endpoint: null
			},
			{
				id: "/dashboard/settings",
				pattern: /^\/dashboard\/settings\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 10 },
				endpoint: null
			},
			{
				id: "/dashboard/settings/security",
				pattern: /^\/dashboard\/settings\/security\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 11 },
				endpoint: null
			},
			{
				id: "/dashboard/ui",
				pattern: /^\/dashboard\/ui\/?$/,
				params: [],
				page: { layouts: [0,2,], errors: [1,,], leaf: 12 },
				endpoint: null
			},
			{
				id: "/login",
				pattern: /^\/login\/?$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 13 },
				endpoint: null
			}
		],
		prerendered_routes: new Set([]),
		matchers: async () => {
			
			return {  };
		},
		server_assets: {}
	}
}
})();
