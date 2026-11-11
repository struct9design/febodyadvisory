"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { safeNext, type AppRole } from "@/lib/auth/roles";

export async function passwordLogin(email: string, password: string, next?: string) {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error || !data.user) return { error: "Email o contraseña incorrectos." };

  const { data: profile } = await supabase.from("profiles").select("role").eq("id", data.user.id).single();
  if (!profile) {
    await supabase.auth.signOut();
    return { error: "Tu cuenta no tiene acceso todavía. Escribe a tu coach." };
  }
  redirect(safeNext(next, profile.role as AppRole));
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
