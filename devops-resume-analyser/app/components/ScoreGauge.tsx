"use client";

import { useEffect, useState } from "react";

interface ScoreGaugeProps {
  score: number;
  size?: number;
}

export default function ScoreGauge({ score, size = 180 }: ScoreGaugeProps) {
  const [animatedScore, setAnimatedScore] = useState(0);

  const strokeWidth = 12;
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const progress = (animatedScore / 100) * circumference;
  const offset = circumference - progress;

  // Determine color based on score
  const getColor = (s: number) => {
    if (s >= 75) return { stroke: "#10b981", glow: "rgba(16, 185, 129, 0.3)", label: "Excellent" };
    if (s >= 50) return { stroke: "#f59e0b", glow: "rgba(245, 158, 11, 0.3)", label: "Good" };
    return { stroke: "#f43f5e", glow: "rgba(244, 63, 94, 0.3)", label: "Needs Work" };
  };

  const colorInfo = getColor(score);

  useEffect(() => {
    // Animate the score counting up
    const duration = 1200;
    const steps = 60;
    const increment = score / steps;
    let current = 0;
    const interval = setInterval(() => {
      current += increment;
      if (current >= score) {
        current = score;
        clearInterval(interval);
      }
      setAnimatedScore(Math.round(current));
    }, duration / steps);

    return () => clearInterval(interval);
  }, [score]);

  return (
    <div className="relative inline-flex items-center justify-center" style={{ width: size, height: size }}>
      <svg
        width={size}
        height={size}
        className="-rotate-90"
        style={{ filter: `drop-shadow(0 0 12px ${colorInfo.glow})` }}
      >
        {/* Background track */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="rgba(100, 116, 139, 0.15)"
          strokeWidth={strokeWidth}
        />
        {/* Progress arc */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={colorInfo.stroke}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          style={{ transition: "stroke-dashoffset 1.2s ease-out, stroke 0.3s ease" }}
        />
      </svg>
      {/* Center text */}
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span
          className="text-4xl font-bold tabular-nums"
          style={{ color: colorInfo.stroke }}
        >
          {animatedScore}
        </span>
        <span className="text-xs font-medium mt-1" style={{ color: colorInfo.stroke, opacity: 0.8 }}>
          {colorInfo.label}
        </span>
      </div>
    </div>
  );
}
