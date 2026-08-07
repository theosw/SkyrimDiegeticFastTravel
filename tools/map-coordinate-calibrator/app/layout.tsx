import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DNT Map Coordinate Calibrator",
  description:
    "Drag Diegetic Fast Travel markers into place and export normalized map coordinates.",
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
