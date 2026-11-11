import { describe, expect, it } from "vitest";
import { homeFor, safeNext } from "./roles";

describe("roles", () => {
  it("manda al staff al panel y al cliente a la app", () => {
    expect(homeFor("coach")).toBe("/panel");
    expect(homeFor("client")).toBe("/app");
  });

  it("solo acepta redirecciones internas de su propia zona", () => {
    expect(safeNext("/panel/clientes", "admin")).toBe("/panel/clientes");
    expect(safeNext("/panel/clientes", "client")).toBe("/app");
    expect(safeNext("//evil.com", "client")).toBe("/app");
    expect(safeNext("https://evil.com", "admin")).toBe("/panel");
    expect(safeNext("/application", "client")).toBe("/app");
  });
});
