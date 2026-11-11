import { SessionBadge } from "@/components/auth/session-badge";
import { PageHeader } from "@/components/ui";
import { getProfile } from "@/lib/auth/session";
import { formatLongDate } from "@/lib/format";

export default async function ClientHome() {
  const profile = (await getProfile())!;
  const first = profile.full_name.split(" ")[0] || "";
  return (
    <>
      <PageHeader eyebrow={formatLongDate(new Date())} title={`Buenos días${first ? `, ${first}` : ""}`} />
      <SessionBadge profile={profile} />
      <p className="m-0 text-sm text-muted">La app del cliente se construye en la fase 5.</p>
    </>
  );
}
