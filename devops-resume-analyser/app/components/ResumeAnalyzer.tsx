"use client";

import { useState, useRef, useCallback } from "react";
import ScoreGauge from "./ScoreGauge";

interface AnalysisResult {
  skills: string[];
  ats_score: number;
  suggestions: string[];
}

const BACKEND_URL =
  process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000";

export default function ResumeAnalyzer() {
  const [file, setFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<AnalysisResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = useCallback((selectedFile: File | null) => {
    setError(null);
    setResult(null);

    if (selectedFile && !selectedFile.name.toLowerCase().endsWith(".pdf")) {
      setError("Please upload a PDF file.");
      setFile(null);
      return;
    }

    if (selectedFile && selectedFile.size > 10 * 1024 * 1024) {
      setError("File size must be less than 10 MB.");
      setFile(null);
      return;
    }

    setFile(selectedFile);
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setDragOver(false);
      const droppedFile = e.dataTransfer.files[0] || null;
      handleFileChange(droppedFile);
    },
    [handleFileChange]
  );

  const handleSubmit = async () => {
    if (!file) {
      setError("Please select a PDF file first.");
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const formData = new FormData();
      formData.append("file", file);

      const response = await fetch(`${BACKEND_URL}/analyze`, {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        throw new Error(
          errorData?.detail || `Server error (${response.status})`
        );
      }

      const data: AnalysisResult = await response.json();
      setResult(data);
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to analyze resume. Please try again."
      );
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setFile(null);
    setResult(null);
    setError(null);
    if (fileInputRef.current) fileInputRef.current.value = "";
  };

  return (
    <div className="w-full max-w-3xl mx-auto space-y-8">
      {/* ─── Upload Card ─── */}
      <div className="glass-card p-8 animate-pulse-glow">
        <div
          id="upload-zone"
          className={`upload-zone p-10 text-center cursor-pointer ${
            dragOver ? "drag-over" : ""
          }`}
          onClick={() => fileInputRef.current?.click()}
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
        >
          {/* Upload Icon */}
          <div className="mx-auto w-16 h-16 mb-4 rounded-2xl bg-gradient-to-br from-accent-cyan/20 to-accent-blue/20 flex items-center justify-center">
            <svg
              className="w-8 h-8 text-accent-cyan"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M12 16.5V9.75m0 0 3 3m-3-3-3 3M6.75 19.5a4.5 4.5 0 0 1-1.41-8.775 5.25 5.25 0 0 1 10.233-2.33 3 3 0 0 1 3.758 3.848A3.752 3.752 0 0 1 18 19.5H6.75Z"
              />
            </svg>
          </div>

          {file ? (
            <div>
              <p className="text-lg font-medium text-foreground">{file.name}</p>
              <p className="text-sm text-muted mt-1">
                {(file.size / 1024).toFixed(1)} KB — Click or drop to replace
              </p>
            </div>
          ) : (
            <div>
              <p className="text-lg font-medium text-foreground">
                Drop your resume here
              </p>
              <p className="text-sm text-muted mt-1">
                or click to browse — PDF only, up to 10 MB
              </p>
            </div>
          )}

          <input
            ref={fileInputRef}
            id="file-input"
            type="file"
            accept=".pdf,application/pdf"
            className="hidden"
            onChange={(e) => handleFileChange(e.target.files?.[0] || null)}
          />
        </div>

        {/* Action Buttons */}
        <div className="mt-6 flex items-center justify-center gap-4">
          <button
            id="analyze-button"
            onClick={handleSubmit}
            disabled={!file || loading}
            className="btn-primary text-base"
          >
            {loading ? (
              <span className="inline-flex items-center gap-2">
                <svg
                  className="animate-spin w-5 h-5"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    className="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    strokeWidth="4"
                  />
                  <path
                    className="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                  />
                </svg>
                Analyzing…
              </span>
            ) : (
              "Analyze Resume"
            )}
          </button>

          {(file || result) && (
            <button
              id="reset-button"
              onClick={resetForm}
              className="px-6 py-3 rounded-xl text-muted border border-card-border hover:text-foreground hover:border-accent-cyan/40 transition-all text-base"
            >
              Reset
            </button>
          )}
        </div>

        {/* Error Message */}
        {error && (
          <div
            id="error-message"
            className="mt-4 p-4 rounded-xl bg-accent-rose/10 border border-accent-rose/20 text-accent-rose text-sm text-center"
          >
            {error}
          </div>
        )}
      </div>

      {/* ─── Loading State ─── */}
      {loading && (
        <div className="glass-card p-12 text-center animate-fade-in-up">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-gradient-to-br from-accent-cyan/20 to-accent-blue/20 mb-4">
            <svg
              className="animate-spin w-8 h-8 text-accent-cyan"
              fill="none"
              viewBox="0 0 24 24"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
          </div>
          <h3 className="text-xl font-semibold text-foreground">
            Analyzing your resume…
          </h3>
          <p className="text-muted mt-2">
            Extracting skills and calculating ATS compatibility
          </p>
          <div className="mt-6 h-1 w-48 mx-auto rounded-full overflow-hidden bg-surface">
            <div
              className="h-full rounded-full"
              style={{
                background:
                  "linear-gradient(90deg, var(--accent-cyan), var(--accent-blue), var(--accent-violet))",
                backgroundSize: "200% 100%",
                animation: "shimmer 1.5s ease-in-out infinite",
              }}
            />
          </div>
        </div>
      )}

      {/* ─── Results ─── */}
      {result && !loading && (
        <div className="space-y-6">
          {/* ATS Score */}
          <div
            id="ats-score-card"
            className="glass-card p-8 text-center animate-fade-in-up stagger-1"
          >
            <h2 className="text-sm font-semibold uppercase tracking-widest text-muted mb-6">
              ATS Compatibility Score
            </h2>
            <ScoreGauge score={result.ats_score} />
            <p className="text-muted text-sm mt-4">
              Based on keyword density, formatting, and content structure
            </p>
          </div>

          {/* Skills */}
          <div
            id="skills-card"
            className="glass-card p-8 animate-fade-in-up stagger-2"
          >
            <h2 className="text-sm font-semibold uppercase tracking-widest text-muted mb-4">
              Extracted Skills
            </h2>
            <div className="flex flex-wrap gap-2">
              {result.skills.map((skill, i) => (
                <span key={i} className="skill-badge">
                  {skill}
                </span>
              ))}
            </div>
            {result.skills.length === 0 && (
              <p className="text-muted text-sm">
                No specific skills were detected.
              </p>
            )}
          </div>

          {/* Suggestions */}
          <div
            id="suggestions-card"
            className="glass-card p-8 animate-fade-in-up stagger-3"
          >
            <h2 className="text-sm font-semibold uppercase tracking-widest text-muted mb-4">
              Improvement Suggestions
            </h2>
            <div className="space-y-3">
              {result.suggestions.map((suggestion, i) => (
                <div key={i} className="suggestion-item">
                  <div className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 rounded-full bg-accent-blue/15 text-accent-blue text-xs font-bold flex items-center justify-center mt-0.5">
                      {i + 1}
                    </span>
                    <p className="text-foreground/90 text-sm leading-relaxed">
                      {suggestion}
                    </p>
                  </div>
                </div>
              ))}
              {result.suggestions.length === 0 && (
                <p className="text-muted text-sm">
                  Your resume looks great — no suggestions at this time!
                </p>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
