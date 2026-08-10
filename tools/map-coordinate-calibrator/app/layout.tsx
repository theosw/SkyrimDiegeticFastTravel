import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DNT Map Coordinate Calibrator",
  description:
    "Calibrate Diegetic Fast Travel map coordinates and selection-ring optics.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
