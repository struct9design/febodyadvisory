import type { Metadata } from "next";
import { Antonio, Work_Sans } from "next/font/google";
import "./globals.css";

const antonio = Antonio({
  variable: "--font-antonio",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
});

const workSans = Work_Sans({
  variable: "--font-work-sans",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600"],
});

export const metadata: Metadata = {
  title: {
    default: "FeBodyAdvisory · Asesoría de culturismo natural",
    template: "%s · FeBodyAdvisory",
  },
  description:
    "Entrenamiento, nutrición y seguimiento individual para culturistas naturales que buscan progresar con método.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es" className={`${antonio.variable} ${workSans.variable}`}>
      <body>{children}</body>
    </html>
  );
}
