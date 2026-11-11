import type { HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export type TagTone = "ok" | "warn" | "danger" | "neutral" | "ink" | "gold" | "outline-gold";

const tones: Record<TagTone, string> = {
  ok: "bg-ok-bg text-ok",
  warn: "bg-warn-bg text-warn",
  danger: "bg-danger-bg text-danger",
  neutral: "bg-line-soft text-ink-soft",
  ink: "bg-ink text-ivory",
  gold: "bg-gold-deep text-ink",
  "outline-gold": "border border-gold text-gold",
};

export function Tag({
  tone = "neutral",
  className,
  ...props
}: HTMLAttributes<HTMLSpanElement> & { tone?: TagTone }) {
  return (
    <span
      className={cn(
        "inline-flex items-center self-start px-2 py-1 text-[10px] leading-none font-semibold uppercase tracking-[0.1em] whitespace-nowrap",
        tones[tone],
        className,
      )}
      {...props}
    />
  );
}
