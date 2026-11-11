import { cn } from "@/lib/cn";

const tones = {
  ink: "bg-ink",
  gold: "bg-gold",
  "gold-deep": "bg-gold-deep",
  danger: "bg-danger",
  ok: "bg-ok",
} as const;

export function ProgressBar({
  value,
  tone = "ink",
  track = "light",
  height = 4,
  label,
  className,
}: {
  value: number;
  tone?: keyof typeof tones;
  track?: "light" | "dark";
  height?: 3 | 4 | 6;
  label: string;
  className?: string;
}) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div
      role="progressbar"
      aria-label={label}
      aria-valuenow={Math.round(pct)}
      aria-valuemin={0}
      aria-valuemax={100}
      className={cn(track === "light" ? "bg-line-soft" : "bg-ink-line", className)}
      style={{ height }}
    >
      <div className={cn("h-full transition-[width] duration-400", tones[tone])} style={{ width: `${pct}%` }} />
    </div>
  );
}
