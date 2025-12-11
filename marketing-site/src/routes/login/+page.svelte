<script lang="ts">
  import { onMount } from "svelte";
  import { config } from "$lib/config";

  const APP_URL = config.urls.app;
  const LOGIN_URL = `${APP_URL.replace(/\/$/, "")}/auth/signin`;

  onMount(() => {
    window.location.href = LOGIN_URL;
  });
</script>

<svelte:head>
  <title>Sign In | Temporal Cloud</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-[#0d0620] text-zinc-300">
  <div class="text-center space-y-2">
    <div
      class="animate-spin w-10 h-10 border-2 border-emerald-400 border-t-transparent rounded-full mx-auto"
      aria-label="Redirecting to sign in"
    ></div>
    <p>Sending you to Temporal Cloud sign-in…</p>
    <p class="text-xs text-zinc-500">{LOGIN_URL}</p>
  </div>
</div>
