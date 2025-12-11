<script lang="ts">
	import { onMount } from 'svelte';
	import { config } from '$lib/config';
	
	// Redirect all dashboard routes to the admin portal / console
	const APP_URL = config.urls.app;
	
	onMount(() => {
		window.location.href = APP_URL;
	});
</script>

<div class="min-h-screen bg-black flex items-center justify-center">
	<div class="text-center">
		<div class="animate-spin w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full mx-auto mb-4"></div>
		<p class="text-zinc-400">Redirecting to Temporal Cloud Console...</p>
		<p class="text-xs text-zinc-600 mt-2">{APP_URL}</p>
	</div>
</div>
