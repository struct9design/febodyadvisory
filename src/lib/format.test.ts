import { describe, expect, it } from "vitest";
import {
  formatDayMonth,
  formatDayMonthShort,
  formatDecimal,
  formatEuros,
  formatKcal,
  formatLongDate,
  formatNumber,
  formatSigned,
  parseDecimal,
} from "./format";

describe("formato es-ES", () => {
  it("agrupa miles con punto también en 4 cifras", () => {
    expect(formatNumber(2650)).toBe("2.650");
    expect(formatKcal(2650.4)).toBe("2.650 kcal");
  });

  it("usa coma decimal", () => {
    expect(formatDecimal(78.34)).toBe("78,3");
  });

  it("formatea euros sin decimales cuando son enteros", () => {
    expect(formatEuros(109)).toBe("109 €");
    expect(formatEuros(4380)).toBe("4.380 €");
    expect(formatEuros(82.5)).toBe("82,50 €");
  });

  it("usa signo menos tipográfico", () => {
    expect(formatSigned(-0.4, 1, " kg")).toBe("−0,4 kg");
    expect(formatSigned(0.5, 1, " cm")).toBe("+0,5 cm");
  });

  it("formatea fechas en castellano", () => {
    const d = new Date("2026-11-11T10:00:00Z");
    expect(formatDayMonth(d)).toBe("11 de noviembre");
    expect(formatDayMonthShort(d)).toBe("11 nov");
    expect(formatLongDate(d)).toBe("Miércoles, 11 de noviembre");
  });

  it("acepta coma o punto al leer", () => {
    expect(parseDecimal("78,3")).toBe(78.3);
    expect(parseDecimal("78.3")).toBe(78.3);
    expect(parseDecimal("abc")).toBeNull();
  });
});
