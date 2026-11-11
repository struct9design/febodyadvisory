import { signOut } from "@/app/(auth)/login/actions";
import { ROLE_LABEL } from "@/lib/auth/roles";
import type { Profile } from "@/lib/auth/session";
import { Button } from "@/components/ui";

export function SessionBadge({ profile }: { profile: Profile }) {
  return (
    <div className="flex flex-wrap items-center gap-4 border border-line bg-paper px-5 py-4">
      <div className="flex flex-col gap-0.5">
        <span className="text-sm font-semibold">{profile.full_name || profile.email}</span>
        <span className="text-xs text-muted">
          {ROLE_LABEL[profile.role]} · {profile.email}
        </span>
      </div>
      <form action={signOut} className="ml-auto">
        <Button type="submit" variant="secondary" size="sm">
          Cerrar sesión
        </Button>
      </form>
    </div>
  );
}
