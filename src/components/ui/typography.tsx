import type { ElementType, HTMLAttributes } from "react";
import { cn } from "@/lib/cn";

type Tone = "bronze" | "muted" | "gold" | "danger" | "on-ink";

const tones: Record<Tone, string> = {
  bronze: "text-bronze",
  muted: "text-muted",
  gold: "text-gold",
  danger: "text-danger",
  "on-ink": "text-on-ink-muted",
};

export function Eyebrow({
  as: Tag = "span",
  tone = "bronze",
  className,
  ...props
}: HTMLAttributes<HTMLElement> & { as?: ElementType; tone?: Tone }) {
  return (
    <Tag
      className={cn("text-[11px] font-semibold uppercase tracking-eyebrow", tones[tone], className)}
      {...props}
    />
  );
}

export function Label({
  as: Tag = "span",
  tone = "muted",
  className,
  ...props
}: HTMLAttributes<HTMLElement> & { as?: ElementType; tone?: Tone }) {
  return (
    <Tag
      className={cn("text-[10px] font-semibold uppercase tracking-label", tones[tone], className)}
      {...props}
    />
  );
}

type DisplaySize = "xl" | "lg" | "md" | "sm" | "xs";

const displaySizes: Record<DisplaySize, string> = {
  xl: "text-[clamp(38px,5vw,64px)] leading-[0.95]",
  lg: "text-[clamp(28px,3vw,40px)] leading-none",
  md: "text-2xl leading-none",
  sm: "text-xl leading-none",
  xs: "text-lg leading-none",
};

export function Display({
  as: Tag = "h2",
  size = "md",
  weight = "bold",
  className,
  ...props
}: HTMLAttributes<HTMLElement> & { as?: ElementType; size?: DisplaySize; weight?: "semibold" | "bold" }) {
  return (
    <Tag
      className={cn(
        "m-0 font-display uppercase",
        weight === "bold" ? "font-bold" : "font-semibold",
        displaySizes[size],
        className,
      )}
      {...props}
    />
  );
}
