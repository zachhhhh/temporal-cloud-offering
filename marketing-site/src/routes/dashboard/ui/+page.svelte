<script lang="ts">
  import { onMount } from "svelte";
  import { config } from "$lib/config";

  const APP_URL = config.urls.app;

  onMount(() => {
    window.location.href = APP_URL;
  });
</script>

<div class="min-h-screen flex items-center justify-center bg-[#0d0620] text-zinc-300">
  <div class="text-center space-y-2">
    <div
      class="animate-spin w-10 h-10 border-2 border-emerald-400 border-t-transparent rounded-full mx-auto"
      aria-label="Redirecting to UI"
    ></div>
    <p>Opening Temporal UI in Cloud Console…</p>
    <p class="text-xs text-zinc-500">{APP_URL}</p>
  </div>
</div>
