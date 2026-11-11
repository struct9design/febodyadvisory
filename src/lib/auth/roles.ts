export const APP_ROLES = ["admin", "coach", "nutritionist", "billing", "client"] as const;
export type AppRole = (typeof APP_ROLES)[number];

export const STAFF_ROLES = ["admin", "coach", "nutritionist", "billing"] as const satisfies readonly AppRole[];
export type StaffRole = (typeof STAFF_ROLES)[number];

export const ROLE_LABEL: Record<AppRole, string> = {
  admin: "Admin",
  coach: "Entrenador",
  nutritionist: "Nutricionista",
  billing: "Administración",
  client: "Cliente",
};

export function isStaff(role: AppRole): role is StaffRole {
  return (STAFF_ROLES as readonly AppRole[]).includes(role);
}

export function homeFor(role: AppRole): string {
  return isStaff(role) ? "/panel" : "/app";
}

/** Only allow same-site relative redirects that match the user's area. */
export function safeNext(next: string | null | undefined, role: AppRole): string {
  const home = homeFor(role);
  if (!next || !next.startsWith("/") || next.startsWith("//")) return home;
  return next === home || next.startsWith(`${home}/`) ? next : home;
}
