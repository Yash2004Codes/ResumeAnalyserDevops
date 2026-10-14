import ResumeAnalyzer from "./components/ResumeAnalyzer";

export default function Home() {
  return (
    <div className="flex flex-col flex-1 items-center justify-start min-h-screen px-4 py-12 sm:py-20">
      {/* Header */}
      <header className="text-center mb-12 max-w-2xl">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-accent-cyan/10 border border-accent-cyan/20 text-accent-cyan text-xs font-medium mb-6">
          <svg className="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
            <path d="M11.3 1.046A1 1 0 0112 2v5h4a1 1 0 01.82 1.573l-7 10A1 1 0 018 18v-5H4a1 1 0 01-.82-1.573l7-10a1 1 0 011.12-.38z" />
          </svg>
          Powered by AI
        </div>
        <h1 className="text-4xl sm:text-5xl font-bold tracking-tight mb-4">
          <span className="gradient-text">Resume Analyzer</span>
        </h1>
        <p className="text-muted text-lg leading-relaxed">
          Upload your resume and get an instant ATS compatibility score,
          extracted skills, and actionable improvement suggestions.
        </p>
      </header>

      {/* Main Content */}
      <main className="w-full">
        <ResumeAnalyzer />
      </main>

      {/* Footer */}
      <footer className="mt-auto pt-16 pb-6 text-center">
        <p className="text-muted/60 text-xs">
          Built for DevOps pipeline integration · Groq AI · FastAPI · Next.js
        </p>
      </footer>
    </div>
  );
}
