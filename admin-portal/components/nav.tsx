"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Server,
  CreditCard,
  Settings,
  ExternalLink,
} from "lucide-react";

export default function Nav() {
  const pathname = usePathname();
  const TEMPORAL_UI =
    process.env.NEXT_PUBLIC_TEMPORAL_UI || "http://localhost:8080";

  const links = [
    { href: "/", label: "Dashboard", icon: LayoutDashboard },
    { href: "/namespaces", label: "Namespaces", icon: Server },
    { href: "/billing", label: "Billing", icon: CreditCard },
    { href: "/settings", label: "Settings", icon: Settings },
  ];

  return (
    <nav className="w-64 bg-zinc-900 border-r border-zinc-800 min-h-screen p-4">
      <div className="flex items-center gap-2 px-2 mb-8">
        <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
          <span className="text-white font-bold text-sm">T</span>
        </div>
        <span className="font-semibold">Temporal Cloud</span>
      </div>

      <div className="space-y-1">
        {links.map((link) => {
          const Icon = link.icon;
          const isActive = pathname === link.href;
          return (
            <Link
              key={link.href}
              href={link.href}
              className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                isActive
                  ? "bg-indigo-600 text-white"
                  : "text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800"
              }`}
            >
              <Icon className="w-4 h-4" />
              {link.label}
            </Link>
          );
        })}
      </div>

      <div className="mt-8 pt-8 border-t border-zinc-800">
        <a
          href={TEMPORAL_UI}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-3 px-3 py-2 rounded-lg text-sm text-zinc-400 hover:text-zinc-100 hover:bg-zinc-800 transition-colors"
        >
          <ExternalLink className="w-4 h-4" />
          Temporal UI
        </a>
      </div>
    </nav>
  );
}
