"use client";

import type { KeyboardEvent, ReactNode } from "react";
import { cn } from "@/lib/cn";

export type Column<T> = {
  key: string;
  header: ReactNode;
  cell: (row: T) => ReactNode;
  className?: string;
  align?: "left" | "right" | "center";
};

const alignClass = { left: "text-left", right: "text-right", center: "text-center" };

export function DataTable<T>({
  columns,
  rows,
  rowKey,
  onRowClick,
  selectedKey,
  minWidth = 760,
  empty = "Sin resultados.",
  caption,
  className,
}: {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  selectedKey?: string;
  minWidth?: number;
  empty?: ReactNode;
  caption?: string;
  className?: string;
}) {
  const onKey = (e: KeyboardEvent<HTMLTableRowElement>, row: T) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      onRowClick?.(row);
    }
  };

  return (
    <div className={cn("overflow-x-auto border border-ink bg-paper", className)}>
      <table className="w-full border-collapse text-[13px]" style={{ minWidth }}>
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead>
          <tr className="border-b border-ink">
            {columns.map((c) => (
              <th
                key={c.key}
                scope="col"
                className={cn(
                  "px-[18px] py-3 text-[10px] font-semibold uppercase tracking-[0.16em] text-muted",
                  alignClass[c.align ?? "left"],
                  c.className,
                )}
              >
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 && (
            <tr>
              <td colSpan={columns.length} className="px-[18px] py-10 text-center text-sm text-muted">
                {empty}
              </td>
            </tr>
          )}
          {rows.map((row) => {
            const key = rowKey(row);
            const selected = key === selectedKey;
            return (
              <tr
                key={key}
                tabIndex={onRowClick ? 0 : undefined}
                aria-selected={onRowClick ? selected : undefined}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                onKeyDown={onRowClick ? (e) => onKey(e, row) : undefined}
                className={cn(
                  "border-b border-line-soft last:border-b-0",
                  onRowClick && "cursor-pointer hover:bg-ivory focus-visible:-outline-offset-2",
                  selected && "bg-sand hover:bg-sand",
                )}
              >
                {columns.map((c) => (
                  <td key={c.key} className={cn("px-[18px] py-3 align-middle", alignClass[c.align ?? "left"], c.className)}>
                    {c.cell(row)}
                  </td>
                ))}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
