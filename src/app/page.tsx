import Link from "next/link";
import { Logo } from "@/components/brand/logo";
import { buttonClasses } from "@/components/ui";

// Temporary home until the public site is built in phase 7.
export default function Home() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-[1360px] flex-col justify-between gap-12 px-[clamp(20px,4vw,56px)] py-12">
      <div className="flex items-center gap-3.5">
        <Logo size={48} />
        <span className="font-display text-lg font-bold tracking-[0.14em]">FEBODYADVISORY</span>
      </div>
      <h1 className="m-0 font-display text-[clamp(64px,11vw,176px)] leading-[0.92] font-bold uppercase">
        Natural.
        <br />
        <span className="pl-[clamp(0px,8vw,140px)]">Medido.</span>
        <br />
        <span className="pl-[clamp(0px,16vw,280px)] text-accent-text">Sin atajos.</span>
      </h1>
      <div className="flex flex-wrap items-center justify-between gap-4 border-t border-line pt-5">
        <span className="text-[11px] font-medium uppercase tracking-[0.24em] text-muted">
          Asesoría de culturismo natural · Web en construcción
        </span>
        <Link href="/login" className={buttonClasses()}>
          Área privada
        </Link>
      </div>
    </main>
  );
}
