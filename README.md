# FeBodyAdvisory

Web pública (`/`), app del cliente (`/app`) y panel de gestión (`/panel`) de la asesoría de culturismo natural FeBodyAdvisory.

Next.js 15 · TypeScript · Tailwind CSS v4 · Supabase (Postgres, Auth, Storage, Realtime) · Vercel.

## Desarrollo

```bash
pnpm install
cp .env.example .env.local   # rellena la publishable key de Supabase
pnpm dev                     # http://localhost:3000
```

| Script | Qué hace |
|---|---|
| `pnpm test` | Tests unitarios (Vitest) |
| `pnpm typecheck` | Comprobación de tipos |
| `pnpm lint` | ESLint |
| `pnpm build` | Build de producción |

`/sistema` muestra todos los componentes base (no disponible en producción).

## Reglas de diseño

Los tokens están en `src/app/globals.css`. La paleta, los radios y las sombras por defecto de Tailwind están anulados: solo existen los colores de marca, esquinas rectas y sin sombras.

## Base de datos

Migraciones en `supabase/migrations`. Las políticas RLS son la fuente de verdad de los permisos; la interfaz solo oculta lo que el rol no puede usar.
