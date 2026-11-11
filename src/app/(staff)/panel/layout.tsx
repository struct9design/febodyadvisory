import { STAFF_ROLES } from "@/lib/auth/roles";
import { requireRole } from "@/lib/auth/session";

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  await requireRole(STAFF_ROLES, "/panel");
  return <div className="flex min-h-dvh flex-col gap-7 px-[clamp(24px,3vw,48px)] pt-8 pb-14">{children}</div>;
}
