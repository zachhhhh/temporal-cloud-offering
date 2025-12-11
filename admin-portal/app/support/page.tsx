"use client";

import { LifeBuoy, Mail, MessageSquare, BookOpen } from "lucide-react";

const supportLinks = [
  {
    title: "Status",
    desc: "Check service health and incidents",
    href: "https://status.temporal.io",
    icon: LifeBuoy,
  },
  {
    title: "Docs",
    desc: "Product docs and tutorials",
    href: "https://docs.temporal.io",
    icon: BookOpen,
  },
  {
    title: "Community",
    desc: "Ask questions in the forum",
    href: "https://community.temporal.io",
    icon: MessageSquare,
  },
  {
    title: "Email Support",
    desc: "Contact the Temporal team",
    href: "mailto:support@temporal.io",
    icon: Mail,
  },
];

export default function SupportPage() {
  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <div className="max-w-5xl mx-auto px-6 py-10">
        <h1 className="text-2xl font-bold mb-2">Support</h1>
        <p className="text-zinc-400 mb-8">
          Get help fast with docs, community, or direct support.
        </p>

        <div className="grid md:grid-cols-2 gap-4">
          {supportLinks.map((item) => {
            const Icon = item.icon;
            return (
              <a
                key={item.title}
                href={item.href}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-start gap-3 p-4 bg-zinc-900 border border-zinc-800 rounded-xl hover:border-zinc-700 transition-colors"
              >
                <div className="p-2 bg-indigo-600/10 rounded-lg">
                  <Icon className="w-5 h-5 text-indigo-300" />
                </div>
                <div>
                  <p className="font-semibold">{item.title}</p>
                  <p className="text-sm text-zinc-400">{item.desc}</p>
                </div>
              </a>
            );
          })}
        </div>
      </div>
    </div>
  );
}
