import {
  forwardRef,
  useId,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from "react";
import { cn } from "@/lib/cn";

const fieldBase =
  "w-full bg-field text-ink placeholder:text-muted-2 outline-none transition-colors aria-[invalid=true]:border-danger";

const fieldVariants = {
  box: "border border-ink px-3 py-3 text-sm min-h-11 focus:border-gold-deep",
  soft: "border border-line px-2.5 py-2 text-sm min-h-9 focus:border-ink",
  line: "border-0 border-b border-ink bg-transparent px-0 py-2.5 text-[17px] focus:border-gold-deep",
} as const;

type FieldVariant = keyof typeof fieldVariants;

export const Input = forwardRef<
  HTMLInputElement,
  InputHTMLAttributes<HTMLInputElement> & { variant?: FieldVariant }
>(function Input({ variant = "box", className, ...props }, ref) {
  return <input ref={ref} className={cn(fieldBase, fieldVariants[variant], className)} {...props} />;
});

export const Textarea = forwardRef<
  HTMLTextAreaElement,
  TextareaHTMLAttributes<HTMLTextAreaElement> & { variant?: FieldVariant }
>(function Textarea({ variant = "soft", className, ...props }, ref) {
  return (
    <textarea
      ref={ref}
      className={cn(fieldBase, fieldVariants[variant], "min-h-28 resize-y leading-relaxed", className)}
      {...props}
    />
  );
});

export const Select = forwardRef<
  HTMLSelectElement,
  SelectHTMLAttributes<HTMLSelectElement> & { variant?: Exclude<FieldVariant, "line"> }
>(function Select({ variant = "box", className, children, ...props }, ref) {
  return (
    <span className="relative block w-full">
      <select
        ref={ref}
        className={cn(fieldBase, fieldVariants[variant], "cursor-pointer appearance-none pr-9", className)}
        {...props}
      >
        {children}
      </select>
      <span aria-hidden className="pointer-events-none absolute top-1/2 right-3 -translate-y-1/2 text-xs text-muted">
        ▾
      </span>
    </span>
  );
});

/** Label + control + error, wired with ids for screen readers. */
export function Field({
  label,
  error,
  hint,
  className,
  children,
}: {
  label: ReactNode;
  error?: string;
  hint?: ReactNode;
  className?: string;
  children: (ids: { id: string; describedBy?: string; invalid: boolean }) => ReactNode;
}) {
  const id = useId();
  const msgId = `${id}-msg`;
  return (
    <div className={cn("flex flex-col gap-1.5", className)}>
      <label
        htmlFor={id}
        className="text-[10px] font-semibold uppercase tracking-label text-muted"
      >
        {label}
      </label>
      {children({ id, describedBy: error || hint ? msgId : undefined, invalid: !!error })}
      {(error || hint) && (
        <span id={msgId} className={cn("text-xs", error ? "text-danger" : "text-muted")}>
          {error ?? hint}
        </span>
      )}
    </div>
  );
}

export function Checkbox({
  checked,
  onChange,
  children,
  className,
}: {
  checked: boolean;
  onChange: (checked: boolean) => void;
  children: ReactNode;
  className?: string;
}) {
  return (
    <label className={cn("flex min-h-11 cursor-pointer items-center gap-3 text-sm", className)}>
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="peer sr-only"
      />
      <span
        aria-hidden
        className="flex size-5 flex-none items-center justify-center border border-ink text-xs text-gold peer-checked:bg-ink peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-gold-deep"
      >
        {checked ? "✓" : ""}
      </span>
      {children}
    </label>
  );
}
