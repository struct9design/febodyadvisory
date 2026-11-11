import type { HTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/cn";
import { Display } from "./typography";

type CardTone = "paper" | "strong" | "ink" | "dashed";

const tones: Record<CardTone, string> = {
  paper: "border border-line bg-paper",
  strong: "border border-ink bg-paper",
  ink: "bg-ink text-ivory",
  dashed: "border border-dashed border-muted-2",
};

export function Card({
  tone = "paper",
  padded = true,
  className,
  ...props
}: HTMLAttributes<HTMLDivElement> & { tone?: CardTone; padded?: boolean }) {
  return (
    <div
      className={cn("flex flex-col gap-4", tones[tone], padded && "p-[clamp(18px,2.4vw,28px)]", className)}
      {...props}
    />
  );
}

export function CardTitle({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-baseline justify-between gap-3">
      <Display as="h3" size="sm" weight="semibold">
        {children}
      </Display>
      {aside && <span className="text-xs text-muted">{aside}</span>}
    </div>
  );
}
