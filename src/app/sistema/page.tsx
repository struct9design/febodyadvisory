import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { SystemShowcase } from "./showcase";

export const metadata: Metadata = { title: "Sistema de diseño", robots: { index: false } };

export default function SystemPage() {
  if (process.env.VERCEL_ENV === "production") notFound();
  return <SystemShowcase />;
}
