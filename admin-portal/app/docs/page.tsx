"use client";

import { useEffect } from "react";

const DOCS_URL = "https://docs.temporal.io";

export default function DocsRedirect() {
  useEffect(() => {
    window.location.href = DOCS_URL;
  }, []);

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-950 text-zinc-200">
      <div className="text-center space-y-2">
        <div className="animate-spin w-10 h-10 border-2 border-indigo-400 border-t-transparent rounded-full mx-auto" />
        <p>Redirecting to docs…</p>
      </div>
    </div>
  );
}
