import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Biblo — Command at the speed of thought",
  description:
    "A GTA V-style radial command wheel for macOS. Hold a key, flick a direction, release. Launch apps, run scripts, and trigger actions — without looking.",
  openGraph: {
    title: "Biblo",
    description: "Radial command wheel for macOS power users.",
    type: "website",
  },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className="h-full">
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
