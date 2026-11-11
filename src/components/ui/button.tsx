import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

type Variant = "primary" | "secondary" | "gold" | "quiet" | "danger-link" | "on-ink";
type Size = "sm" | "md" | "lg";

const base =
  "inline-flex items-center justify-center gap-3 font-semibold uppercase tracking-button transition-colors duration-200 cursor-pointer disabled:cursor-not-allowed disabled:opacity-50";

const variants: Record<Variant, string> = {
  primary: "bg-ink text-ivory hover:bg-bronze",
  secondary: "border border-ink text-ink hover:bg-ink hover:text-ivory",
  gold: "bg-gold text-ink hover:bg-gold-light",
  quiet: "border border-line text-muted hover:border-ink hover:text-ink",
  "danger-link": "text-danger normal-case tracking-normal hover:underline",
  "on-ink": "border border-muted text-ivory hover:border-gold hover:text-gold",
};

const sizes: Record<Size, string> = {
  sm: "min-h-9 px-3.5 py-2 text-[11px]",
  md: "min-h-11 px-[18px] py-3 text-xs",
  lg: "min-h-14 px-7 py-[18px] text-xs tracking-[0.16em]",
};

export function buttonClasses({
  variant = "primary",
  size = "md",
  className,
}: { variant?: Variant; size?: Size; className?: string } = {}) {
  return cn(base, variants[variant], variant !== "danger-link" && sizes[size], className);
}

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant, size, className, type = "button", ...props },
  ref,
) {
  return <button ref={ref} type={type} className={buttonClasses({ variant, size, className })} {...props} />;
});
