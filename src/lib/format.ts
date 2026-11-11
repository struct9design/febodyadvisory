const LOCALE = "es-ES";
const TZ = "Europe/Madrid";

// es-ES skips the thousands separator for 4-digit numbers by default; the brand wants «2.650».
export function formatNumber(value: number, decimals = 0): string {
  return new Intl.NumberFormat(LOCALE, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
    useGrouping: "always",
  }).format(value);
}

export function formatDecimal(value: number, decimals = 1): string {
  return formatNumber(value, decimals);
}

export function formatEuros(value: number): string {
  const decimals = Number.isInteger(value) ? 0 : 2;
  return `${formatNumber(value, decimals)} €`;
}

export function formatKg(value: number, decimals = 1): string {
  return `${formatNumber(value, decimals)} kg`;
}

export function formatKcal(value: number): string {
  return `${formatNumber(Math.round(value))} kcal`;
}

export function formatPercent(value: number, decimals = 0): string {
  return `${formatNumber(value, decimals)} %`;
}

export function formatSigned(value: number, decimals = 1, unit = ""): string {
  const sign = value > 0 ? "+" : value < 0 ? "−" : "±";
  return `${sign}${formatNumber(Math.abs(value), decimals)}${unit}`;
}

function toDate(d: Date | string): Date {
  return typeof d === "string" ? new Date(d) : d;
}

/** «11 de noviembre» */
export function formatDayMonth(d: Date | string): string {
  return new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", timeZone: TZ }).format(toDate(d));
}

/** «11 nov» */
export function formatDayMonthShort(d: Date | string): string {
  return new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "short", timeZone: TZ })
    .format(toDate(d))
    .replace(".", "");
}

/** «Miércoles, 11 de noviembre» */
export function formatLongDate(d: Date | string): string {
  const s = new Intl.DateTimeFormat(LOCALE, {
    weekday: "long",
    day: "numeric",
    month: "long",
    timeZone: TZ,
  }).format(toDate(d));
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** «08:50» */
export function formatTime(d: Date | string): string {
  return new Intl.DateTimeFormat(LOCALE, { hour: "2-digit", minute: "2-digit", timeZone: TZ }).format(toDate(d));
}

/** Parses user input like «78,3» or «78.3». */
export function parseDecimal(input: string): number | null {
  const n = Number.parseFloat(input.trim().replace(",", "."));
  return Number.isFinite(n) ? n : null;
}
