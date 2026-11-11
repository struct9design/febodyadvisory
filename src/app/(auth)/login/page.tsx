import type { Metadata } from "next";
import { Logo } from "@/components/brand/logo";
import { Display, Eyebrow } from "@/components/ui";
import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Acceso" };

const ERRORS: Record<string, string> = {
  enlace: "El enlace ha caducado o ya se ha usado. Pide uno nuevo.",
  perfil: "Tu cuenta no tiene acceso todavía. Escribe a tu coach.",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string }>;
}) {
  const { next, error } = await searchParams;
  return (
    <main className="grid min-h-dvh md:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
      <section className="hidden flex-col justify-between bg-ink p-12 text-ivory md:flex">
        <div className="flex items-center gap-3.5">
          <Logo size={48} onInk />
          <span className="font-display text-lg font-bold tracking-[0.14em]">FEBODYADVISORY</span>
        </div>
        <p className="m-0 font-display text-[clamp(48px,6vw,96px)] leading-[0.92] font-bold uppercase">
          Natural.
          <br />
          Medido.
          <br />
          <span className="text-gold">Sin atajos.</span>
        </p>
        <span className="text-xs text-on-ink-dim">Culturismo natural · Asesoría online</span>
      </section>

      <section className="flex flex-col justify-center gap-10 px-[clamp(20px,6vw,96px)] py-12">
        <div className="flex items-center gap-3 md:hidden">
          <Logo size={44} />
          <span className="font-display text-base font-bold tracking-[0.14em]">FEBODYADVISORY</span>
        </div>
        <div className="flex max-w-md flex-col gap-3 border-b border-ink pb-5">
          <Eyebrow>Área privada</Eyebrow>
          <Display as="h1" size="xl">
            Acceso
          </Display>
          <p className="m-0 text-sm leading-relaxed text-muted">
            Clientes y equipo de FeBodyAdvisory. Si aún no tienes cuenta, tu coach te enviará una invitación.
          </p>
        </div>
        {error && ERRORS[error] && (
          <p role="alert" className="m-0 max-w-md border border-danger bg-danger-bg px-4 py-3 text-sm">
            {ERRORS[error]}
          </p>
        )}
        <LoginForm next={next} />
      </section>
    </main>
  );
}
