import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

export type Kpi = {
  label: string;
  value: ReactNode;
  unit?: string;
  detail?: string;
  detailTone?: "ok" | "danger" | "muted";
};

const detailTones = {
  ok: { light: "text-ok", dark: "text-gold" },
  danger: { light: "text-danger", dark: "text-danger-line" },
  muted: { light: "text-muted", dark: "text-on-ink-muted" },
};

/** Cells joined by a 1px ink gap; the first cell is inverted with a gold label. */
export function KpiStrip({ items, size = "lg" }: { items: Kpi[]; size?: "lg" | "md" }) {
  return (
    <dl className="m-0 flex flex-wrap gap-px border border-ink bg-ink">
      {items.map((k, i) => {
        const dark = i === 0;
        const tone = k.detailTone ?? "muted";
        return (
          <div
            key={k.label}
            className={cn(
              "flex min-w-0 flex-[1_1_170px] flex-col gap-2.5",
              size === "lg" ? "px-[22px] py-5" : "px-5 py-[18px]",
              dark ? "bg-ink text-ivory" : "bg-paper text-ink",
            )}
          >
            <dt
              className={cn(
                "text-[10px] font-semibold uppercase tracking-[0.2em]",
                dark ? "text-gold" : "text-muted",
              )}
            >
              {k.label}
            </dt>
            <dd
              className={cn(
                "m-0 font-display leading-[0.95] font-bold",
                size === "lg" ? "text-[40px]" : "text-[34px]",
              )}
            >
              {k.value}
              {k.unit && <span className="ml-1 text-base font-medium">{k.unit}</span>}
            </dd>
            {k.detail && (
              <dd className={cn("m-0 text-xs font-medium", detailTones[tone][dark ? "dark" : "light"])}>
                {k.detail}
              </dd>
            )}
          </div>
        );
      })}
    </dl>
  );
}
