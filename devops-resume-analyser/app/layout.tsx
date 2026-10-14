import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "AI Resume Analyzer | ATS Score & Skills Extraction",
  description:
    "Upload your resume and get an instant AI-powered ATS compatibility score, extracted skills list, and actionable improvement suggestions. Built for DevOps pipeline integration.",
  keywords: ["resume analyzer", "ATS score", "skills extraction", "AI", "career tools"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${inter.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col bg-grid-pattern">
        {children}
      </body>
    </html>
  );
}
