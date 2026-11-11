import { cn } from "@/lib/cn";

// TODO(logo): replace with the official /public/brand/logo-fe.svg once delivered. Never redraw it.
export function Logo({ size = 48, onInk = false, className }: { size?: number; onInk?: boolean; className?: string }) {
  return (
    <span
      role="img"
      aria-label="FeBodyAdvisory"
      className={cn(
        "inline-flex flex-none items-center justify-center border border-dashed text-[9px] font-semibold uppercase tracking-label",
        onInk ? "border-on-ink-faint text-on-ink-faint" : "border-muted-2 text-muted-2",
        className,
      )}
      style={{ width: size, height: size }}
    >
      Logo
    </span>
  );
}
