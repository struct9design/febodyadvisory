"use client";

import { useState } from "react";
import { Logo } from "@/components/brand/logo";
import {
  Button,
  Card,
  CardTitle,
  Checkbox,
  DataTable,
  Display,
  Eyebrow,
  Field,
  FilterChips,
  Input,
  KpiStrip,
  Label,
  PageHeader,
  ProgressBar,
  Segmented,
  Select,
  Tag,
  Textarea,
  type Column,
  type TagTone,
} from "@/components/ui";
import { formatDecimal, formatEuros, formatKcal } from "@/lib/format";

const SWATCHES = [
  "ink", "ivory", "paper", "sand", "line", "line-soft", "muted", "muted-2", "gold", "gold-deep", "bronze",
  "accent-text", "ink-soft", "ok", "ok-bg", "warn", "warn-bg", "danger", "danger-bg",
];

type Client = { id: string; name: string; plan: string; status: string; tone: TagTone; weight: number; adherence: number };

const CLIENTS: Client[] = [
  { id: "c1", name: "Alejandro Martín", plan: "Premium completo", status: "Activo", tone: "ok", weight: 78.3, adherence: 91 },
  { id: "c4", name: "Sergio Navas", plan: "Esencial", status: "Activo", tone: "ok", weight: 90.4, adherence: 54 },
  { id: "c5", name: "Iván Sáez", plan: "Premium completo", status: "Finaliza pronto", tone: "danger", weight: 74, adherence: 66 },
  { id: "c7", name: "Nerea Campos", plan: "Premium completo", status: "Nuevo", tone: "warn", weight: 63.5, adherence: 0 },
];

const COLUMNS: Column<Client>[] = [
  {
    key: "name",
    header: "Cliente",
    cell: (c) => (
      <span className="flex flex-col gap-0.5">
        <span className="text-sm font-semibold">{c.name}</span>
        <span className="text-xs text-muted">{c.plan}</span>
      </span>
    ),
  },
  { key: "status", header: "Estado", cell: (c) => <Tag tone={c.tone}>{c.status}</Tag> },
  { key: "weight", header: "Peso", cell: (c) => `${formatDecimal(c.weight)} kg` },
  {
    key: "adh",
    header: "Adherencia",
    cell: (c) => (
      <span className="flex items-center gap-2">
        <ProgressBar
          label={`Adherencia de ${c.name}`}
          value={c.adherence}
          tone={c.adherence < 60 ? "danger" : "ink"}
          className="flex-1"
        />
        <span className="min-w-9 font-semibold">{c.adherence ? `${c.adherence} %` : "—"}</span>
      </span>
    ),
  },
];

export function SystemShowcase() {
  const [view, setView] = useState<"sesion" | "volumen">("sesion");
  const [chip, setChip] = useState<"todos" | "Activo" | "Nuevo">("todos");
  const [fasted, setFasted] = useState(true);
  const [selected, setSelected] = useState("c1");

  return (
    <main className="mx-auto flex max-w-[1240px] flex-col gap-12 p-[clamp(18px,3.4vw,48px)]">
      <PageHeader
        eyebrow="Fase 1 · solo en local y preview"
        title="Sistema de diseño"
        actions={<Logo size={56} />}
      />

      <section className="flex flex-col gap-4">
        <Label>Colores (únicos permitidos)</Label>
        <div className="grid grid-cols-[repeat(auto-fill,minmax(120px,1fr))] gap-2">
          {SWATCHES.map((s) => (
            <div key={s} className="flex flex-col gap-1.5 text-xs">
              <span className="h-12 border border-line" style={{ background: `var(--color-${s})` }} />
              {s}
            </div>
          ))}
        </div>
      </section>

      <section className="flex flex-col gap-4">
        <Label>Tipografía</Label>
        <Eyebrow>Lunes, 19 de octubre</Eyebrow>
        <Display as="p" size="xl">
          Natural. Medido. <span className="text-accent-text">Sin atajos.</span>
        </Display>
        <Display as="p" size="md">
          Volumen semanal por grupo muscular
        </Display>
        <p className="m-0 max-w-xl text-[17px] leading-[1.75] text-ink-soft">
          Entrenamiento, nutrición y seguimiento individual para culturistas naturales que buscan progresar con método.
        </p>
        <p className="m-0 text-sm text-muted">
          Cifras: {formatKcal(2650)} · {formatEuros(109)} · {formatDecimal(78.3)} kg
        </p>
      </section>

      <section className="flex flex-col gap-4">
        <Label>Botones</Label>
        <div className="flex flex-wrap items-center gap-3">
          <Button>Solicitar valoración</Button>
          <Button variant="secondary">Ver planes</Button>
          <Button variant="quiet">Solicitar alternativa</Button>
          <Button size="sm">Usar</Button>
          <Button size="lg" className="justify-between gap-7">
            Enviar solicitud <span aria-hidden>→</span>
          </Button>
          <Button variant="danger-link">Eliminar comida</Button>
          <Button disabled>Desactivado</Button>
        </div>
        <div className="flex flex-wrap items-center gap-3 bg-ink p-6">
          <Button variant="gold">
            Empezar entrenamiento <span aria-hidden>→</span>
          </Button>
          <Button variant="on-ink" size="sm">
            Pausar
          </Button>
        </div>
      </section>

      <section className="flex flex-col gap-4">
        <Label>Tira de KPIs</Label>
        <KpiStrip
          items={[
            { label: "Clientes activos", value: "64", detail: "+5 este mes", detailTone: "ok" },
            { label: "Ingresos noviembre", value: formatEuros(4380), detail: "Previsto 6.540 €" },
            { label: "Check-ins pendientes", value: "3", detail: "2 con más de 24 h" },
            { label: "Adherencia media", value: "86 %", detail: "+2 pts vs. octubre", detailTone: "ok" },
            { label: "Adherencia dieta", value: "83 %", detail: "−1 pt vs. octubre", detailTone: "danger" },
          ]}
        />
      </section>

      <section className="flex flex-col gap-4">
        <Label>Etiquetas de estado y controles</Label>
        <div className="flex flex-wrap gap-2">
          <Tag tone="ok">Pagado</Tag>
          <Tag tone="warn">Pendiente</Tag>
          <Tag tone="danger">Vencido</Tag>
          <Tag tone="neutral">Justificante</Tag>
          <Tag tone="gold">PR</Tag>
          <Tag tone="ink">Coach</Tag>
        </div>
        <div className="flex flex-wrap items-center gap-4">
          <Segmented
            label="Vista de entrenamiento"
            value={view}
            onChange={setView}
            options={[
              { value: "sesion", label: "Sesión" },
              { value: "volumen", label: "Volumen semanal" },
            ]}
          />
          <FilterChips
            label="Estado"
            value={chip}
            onChange={setChip}
            options={[
              { value: "todos", label: "Todos", count: 12 },
              { value: "Activo", label: "Activo", count: 8 },
              { value: "Nuevo", label: "Nuevo", count: 3 },
            ]}
          />
        </div>
        <ProgressBar label="Semana 4 de 12" value={29} tone="gold-deep" height={3} className="max-w-sm" />
      </section>

      <section className="grid gap-4 md:grid-cols-2">
        <Card tone="strong">
          <CardTitle>Registrar pesaje</CardTitle>
          <div className="grid grid-cols-2 gap-2.5">
            <Field label="Peso (kg)">
              {({ id }) => <Input id={id} inputMode="decimal" placeholder="78,3" />}
            </Field>
            <Field label="Hora">{({ id }) => <Input id={id} type="time" defaultValue="07:30" />}</Field>
          </div>
          <Field label="Método">
            {({ id }) => (
              <Select id={id}>
                <option>Plicometría 7 pliegues</option>
                <option>Bioimpedancia</option>
              </Select>
            )}
          </Field>
          <Checkbox checked={fasted} onChange={setFasted}>
            En ayunas, tras ir al baño
          </Checkbox>
          <Field label="Nota" error="Este campo es obligatorio.">
            {({ id, describedBy, invalid }) => (
              <Textarea id={id} aria-describedby={describedBy} aria-invalid={invalid} />
            )}
          </Field>
          <Button>Guardar pesaje</Button>
        </Card>
        <div className="flex flex-col gap-4">
          <Card tone="ink">
            <Eyebrow tone="gold">Próxima acción · 18:00</Eyebrow>
            <Display as="p" size="lg">
              Torso A
            </Display>
            <span className="text-sm text-on-ink-muted">5 ejercicios · 15 series · aprox. 1 h 10 min</span>
          </Card>
          <Card>
            <CardTitle aside="Contacto (línea inferior)">Formulario público</CardTitle>
            <Field label="Nombre">{({ id }) => <Input id={id} variant="line" placeholder="Tu nombre" />}</Field>
          </Card>
          <Card tone="dashed">
            <CardTitle>Añadir ejercicio adicional</CardTitle>
          </Card>
        </div>
      </section>

      <section className="flex flex-col gap-4">
        <Label>Tabla de datos (clic o Intro para seleccionar)</Label>
        <DataTable
          caption="Clientes"
          columns={COLUMNS}
          rows={CLIENTS}
          rowKey={(c) => c.id}
          selectedKey={selected}
          onRowClick={(c) => setSelected(c.id)}
        />
      </section>
    </main>
  );
}
