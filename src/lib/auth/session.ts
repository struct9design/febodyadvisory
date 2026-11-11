import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { homeFor, type AppRole } from "./roles";

export type Profile = {
  id: string;
  full_name: string;
  email: string;
  role: AppRole;
  avatar_url: string | null;
};

export const getProfile = cache(async (): Promise<Profile | null> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;
  const { data } = await supabase
    .from("profiles")
    .select("id, full_name, email, role, avatar_url")
    .eq("id", user.id)
    .single();
  return (data as Profile | null) ?? null;
});

/** Guards a layout: unauthenticated → login, wrong area → that user's home. */
export async function requireRole(allowed: readonly AppRole[], path: string): Promise<Profile> {
  const profile = await getProfile();
  if (!profile) redirect(`/login?next=${encodeURIComponent(path)}`);
  if (!allowed.includes(profile.role)) redirect(homeFor(profile.role));
  return profile;
}
