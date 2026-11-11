import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import { Display, Eyebrow } from "./typography";

export function PageHeader({
  eyebrow,
  title,
  actions,
  className,
}: {
  eyebrow?: ReactNode;
  title: ReactNode;
  actions?: ReactNode;
  className?: string;
}) {
  return (
    <header
      className={cn(
        "flex flex-wrap items-end justify-between gap-5 border-b border-ink pb-5",
        className,
      )}
    >
      <div className="flex flex-col gap-2">
        {eyebrow && <Eyebrow>{eyebrow}</Eyebrow>}
        <Display as="h1" size="xl">
          {title}
        </Display>
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </header>
  );
}
