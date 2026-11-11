"use client";

import { useState, useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button, Field, Input, Segmented } from "@/components/ui";
import { createClient } from "@/lib/supabase/client";
import { passwordLogin } from "./actions";

type Mode = "magic" | "password";

const schema = z.object({
  email: z.email("Introduce un email válido."),
  password: z.string().optional(),
});
type Values = z.infer<typeof schema>;

export function LoginForm({ next }: { next?: string }) {
  const [mode, setMode] = useState<Mode>("magic");
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [serverError, setServerError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  const onSubmit = handleSubmit((values) => {
    setServerError(null);
    startTransition(async () => {
      if (mode === "password") {
        if (!values.password) {
          setError("password", { message: "Introduce tu contraseña." });
          return;
        }
        const res = await passwordLogin(values.email, values.password, next);
        if (res?.error) setServerError(res.error);
        return;
      }
      const supabase = createClient();
      const callback = new URL("/auth/callback", window.location.origin);
      if (next) callback.searchParams.set("next", next);
      const { error } = await supabase.auth.signInWithOtp({
        email: values.email,
        options: { shouldCreateUser: false, emailRedirectTo: callback.toString() },
      });
      if (error) {
        setServerError("No hemos podido enviar el enlace. Comprueba el email o inténtalo en unos minutos.");
        return;
      }
      setSentTo(values.email);
    });
  });

  if (sentTo) {
    return (
      <div className="flex max-w-md flex-col gap-4 border border-ink p-7">
        <p className="m-0 font-display text-[22px] leading-snug">Revisa tu correo.</p>
        <p className="m-0 text-sm leading-relaxed text-muted">
          Si <strong className="font-semibold text-ink">{sentTo}</strong> tiene acceso, te hemos enviado un enlace para
          entrar. Caduca en una hora.
        </p>
        <Button variant="secondary" size="sm" className="self-start" onClick={() => setSentTo(null)}>
          Usar otro email
        </Button>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex max-w-md flex-col gap-6">
      <Segmented
        label="Forma de acceso"
        value={mode}
        onChange={(m) => {
          setMode(m);
          setServerError(null);
        }}
        options={[
          { value: "magic", label: "Enlace por email" },
          { value: "password", label: "Contraseña" },
        ]}
      />
      <Field label="Email" error={errors.email?.message}>
        {({ id, describedBy, invalid }) => (
          <Input
            id={id}
            type="email"
            autoComplete="email"
            placeholder="tu@email.com"
            aria-describedby={describedBy}
            aria-invalid={invalid}
            {...register("email")}
          />
        )}
      </Field>
      {mode === "password" && (
        <Field label="Contraseña" error={errors.password?.message}>
          {({ id, describedBy, invalid }) => (
            <Input
              id={id}
              type="password"
              autoComplete="current-password"
              aria-describedby={describedBy}
              aria-invalid={invalid}
              {...register("password")}
            />
          )}
        </Field>
      )}
      {serverError && (
        <p role="alert" className="m-0 text-sm text-danger">
          {serverError}
        </p>
      )}
      <Button type="submit" size="lg" disabled={pending} className="justify-between">
        {pending ? "Enviando…" : mode === "magic" ? "Enviarme el enlace" : "Entrar"}
        <span aria-hidden>→</span>
      </Button>
    </form>
  );
}
