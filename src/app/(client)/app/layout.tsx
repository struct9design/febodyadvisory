import { requireRole } from "@/lib/auth/session";

export default async function ClientAppLayout({ children }: { children: React.ReactNode }) {
  await requireRole(["client"], "/app");
  return <div className="mx-auto flex min-h-dvh max-w-[1240px] flex-col gap-7 p-[clamp(18px,3.4vw,48px)]">{children}</div>;
}
