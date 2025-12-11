
// this file is generated — do not edit it


declare module "svelte/elements" {
	export interface HTMLAttributes<T> {
		'data-sveltekit-keepfocus'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-noscroll'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-preload-code'?:
			| true
			| ''
			| 'eager'
			| 'viewport'
			| 'hover'
			| 'tap'
			| 'off'
			| undefined
			| null;
		'data-sveltekit-preload-data'?: true | '' | 'hover' | 'tap' | 'off' | undefined | null;
		'data-sveltekit-reload'?: true | '' | 'off' | undefined | null;
		'data-sveltekit-replacestate'?: true | '' | 'off' | undefined | null;
	}
}

export {};


declare module "$app/types" {
	export interface AppTypes {
		RouteId(): "/" | "/api" | "/api/auth" | "/api/auth/google" | "/api/auth/google/callback" | "/api/auth/login" | "/api/auth/magic-link" | "/api/auth/set-password" | "/api/auth/verify" | "/auth" | "/auth/verify" | "/dashboard" | "/dashboard/batch-operations" | "/dashboard/billing" | "/dashboard/namespaces" | "/dashboard/schedules" | "/dashboard/settings" | "/dashboard/settings/security" | "/dashboard/ui" | "/login";
		RouteParams(): {
			
		};
		LayoutParams(): {
			"/": Record<string, never>;
			"/api": Record<string, never>;
			"/api/auth": Record<string, never>;
			"/api/auth/google": Record<string, never>;
			"/api/auth/google/callback": Record<string, never>;
			"/api/auth/login": Record<string, never>;
			"/api/auth/magic-link": Record<string, never>;
			"/api/auth/set-password": Record<string, never>;
			"/api/auth/verify": Record<string, never>;
			"/auth": Record<string, never>;
			"/auth/verify": Record<string, never>;
			"/dashboard": Record<string, never>;
			"/dashboard/batch-operations": Record<string, never>;
			"/dashboard/billing": Record<string, never>;
			"/dashboard/namespaces": Record<string, never>;
			"/dashboard/schedules": Record<string, never>;
			"/dashboard/settings": Record<string, never>;
			"/dashboard/settings/security": Record<string, never>;
			"/dashboard/ui": Record<string, never>;
			"/login": Record<string, never>
		};
		Pathname(): "/" | "/api" | "/api/" | "/api/auth" | "/api/auth/" | "/api/auth/google" | "/api/auth/google/" | "/api/auth/google/callback" | "/api/auth/google/callback/" | "/api/auth/login" | "/api/auth/login/" | "/api/auth/magic-link" | "/api/auth/magic-link/" | "/api/auth/set-password" | "/api/auth/set-password/" | "/api/auth/verify" | "/api/auth/verify/" | "/auth" | "/auth/" | "/auth/verify" | "/auth/verify/" | "/dashboard" | "/dashboard/" | "/dashboard/batch-operations" | "/dashboard/batch-operations/" | "/dashboard/billing" | "/dashboard/billing/" | "/dashboard/namespaces" | "/dashboard/namespaces/" | "/dashboard/schedules" | "/dashboard/schedules/" | "/dashboard/settings" | "/dashboard/settings/" | "/dashboard/settings/security" | "/dashboard/settings/security/" | "/dashboard/ui" | "/dashboard/ui/" | "/login" | "/login/";
		ResolvedPathname(): `${"" | `/${string}`}${ReturnType<AppTypes['Pathname']>}`;
		Asset(): "/favicon.png" | string & {};
	}
}