<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { auth, type User } from '$lib/stores/auth';

	let status: 'verifying' | 'success' | 'verified' | 'error' = 'verifying';
	let errorMessage = '';
	let isSignupVerification = false;

	onMount(async () => {
		const token = $page.url.searchParams.get('token');
		const email = $page.url.searchParams.get('email');
		const type = $page.url.searchParams.get('type') || 'magic_link';
		isSignupVerification = type === 'signup';

		if (!token || !email) {
			status = 'error';
			errorMessage = 'Invalid verification link';
			return;
		}

		try {
			// Verify the token via API
			const response = await fetch(`/api/auth/verify?token=${token}&email=${encodeURIComponent(email)}&type=${type}`);
			const data = await response.json();

			if (data.success) {
				if (data.verified) {
					// Signup verification - show success and redirect to login
					status = 'verified';
					setTimeout(() => goto('/login'), 2000);
				} else if (data.user) {
					// Magic link login - log the user in
					auth.login(data.user);
					status = 'success';
					setTimeout(() => goto('/dashboard'), 1500);
				}
			} else {
				status = 'error';
				errorMessage = data.error || 'Verification failed';
			}
		} catch (err) {
			status = 'error';
			errorMessage = 'Failed to verify link';
		}
	});
</script>

<svelte:head>
	<title>Verifying... | Temporal Cloud</title>
</svelte:head>

<div class="min-h-screen bg-[#0d0620] flex items-center justify-center p-4">
	<div class="w-full max-w-md text-center">
		{#if status === 'verifying'}
			<div class="animate-spin w-12 h-12 border-4 border-emerald-400 border-t-transparent rounded-full mx-auto mb-4"></div>
			<h1 class="text-xl font-semibold text-white">Verifying your sign-in link...</h1>
			<p class="text-zinc-400 mt-2">Please wait a moment</p>
		{:else if status === 'success'}
			<div class="w-12 h-12 bg-emerald-500 rounded-full flex items-center justify-center mx-auto mb-4">
				<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
				</svg>
			</div>
			<h1 class="text-xl font-semibold text-white">Successfully signed in!</h1>
			<p class="text-zinc-400 mt-2">Redirecting to dashboard...</p>
		{:else if status === 'verified'}
			<div class="w-12 h-12 bg-emerald-500 rounded-full flex items-center justify-center mx-auto mb-4">
				<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
				</svg>
			</div>
			<h1 class="text-xl font-semibold text-white">Email verified!</h1>
			<p class="text-zinc-400 mt-2">Your account has been verified. Redirecting to sign in...</p>
		{:else}
			<div class="w-12 h-12 bg-red-500 rounded-full flex items-center justify-center mx-auto mb-4">
				<svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
				</svg>
			</div>
			<h1 class="text-xl font-semibold text-white">Verification failed</h1>
			<p class="text-zinc-400 mt-2">{errorMessage}</p>
			<a href="/login" class="inline-block mt-4 px-4 py-2 bg-emerald-500 text-white rounded-lg hover:bg-emerald-600 transition-colors">
				Try again
			</a>
		{/if}
	</div>
</div>
