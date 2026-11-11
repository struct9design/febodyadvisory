"use client";

import { cn } from "@/lib/cn";

export type SegmentOption<T extends string> = { value: T; label: string; count?: number };

/** Joined toggle group (Sesión / Volumen, Dieta cerrada / abierta…). */
export function Segmented<T extends string>({
  options,
  value,
  onChange,
  label,
  size = "md",
  className,
}: {
  options: SegmentOption<T>[];
  value: T;
  onChange: (v: T) => void;
  label: string;
  size?: "sm" | "md";
  className?: string;
}) {
  return (
    <div role="radiogroup" aria-label={label} className={cn("flex flex-wrap self-start border border-ink", className)}>
      {options.map((o) => {
        const active = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(o.value)}
            className={cn(
              "cursor-pointer text-xs font-semibold tracking-[0.06em] transition-colors",
              size === "md" ? "min-h-11 px-4 py-2.5" : "min-h-9 px-3 py-2",
              active ? "bg-ink text-ivory" : "bg-transparent text-ink hover:bg-sand",
            )}
          >
            {o.label}
            {o.count !== undefined && <span className="ml-1 opacity-60">{o.count}</span>}
          </button>
        );
      })}
    </div>
  );
}

/** Separate chips used as filters (estado del cliente, categoría de la cola…). */
export function FilterChips<T extends string>({
  options,
  value,
  onChange,
  label,
}: {
  options: SegmentOption<T>[];
  value: T;
  onChange: (v: T) => void;
  label: string;
}) {
  return (
    <div role="radiogroup" aria-label={label} className="flex flex-wrap gap-1">
      {options.map((o) => {
        const active = o.value === value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => onChange(o.value)}
            className={cn(
              "min-h-9 cursor-pointer border px-3 py-2 text-xs font-semibold transition-colors",
              active ? "border-ink bg-ink text-ivory" : "border-line bg-transparent text-ink hover:border-ink",
            )}
          >
            {o.label}
            {o.count !== undefined && <span className="ml-1 opacity-60">{o.count}</span>}
          </button>
        );
      })}
    </div>
  );
}
