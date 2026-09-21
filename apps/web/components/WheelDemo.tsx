"use client";

import { useState, useEffect, useRef } from "react";

const LABELS = [
  "Launch App",
  "Run Script",
  "Shortcut",
  "Keystroke",
  "Open URL",
  "Custom",
  "Window",
  "Clipboard",
];

const CX = 200;
const CY = 200;
const R1 = 55;
const R2 = 160;
const GAP = 2; // degrees gap between segments

function toRad(deg: number) {
  return ((deg - 90) * Math.PI) / 180; // -90 → 12 o'clock = 0
}

function segmentPath(
  cx: number,
  cy: number,
  r1: number,
  r2: number,
  startDeg: number,
  endDeg: number
) {
  const s1 = { x: cx + r1 * Math.cos(toRad(startDeg)), y: cy + r1 * Math.sin(toRad(startDeg)) };
  const s2 = { x: cx + r2 * Math.cos(toRad(startDeg)), y: cy + r2 * Math.sin(toRad(startDeg)) };
  const e1 = { x: cx + r1 * Math.cos(toRad(endDeg)), y: cy + r1 * Math.sin(toRad(endDeg)) };
  const e2 = { x: cx + r2 * Math.cos(toRad(endDeg)), y: cy + r2 * Math.sin(toRad(endDeg)) };
  const large = endDeg - startDeg > 180 ? 1 : 0;
  return `M ${s1.x} ${s1.y} L ${s2.x} ${s2.y} A ${r2} ${r2} 0 ${large} 1 ${e2.x} ${e2.y} L ${e1.x} ${e1.y} A ${r1} ${r1} 0 ${large} 0 ${s1.x} ${s1.y} Z`;
}

function labelPos(i: number) {
  const midDeg = i * 45; // segment i centred at i*45, label at mid angle
  const r = 120;
  return {
    x: CX + r * Math.cos(toRad(midDeg)),
    y: CY + r * Math.sin(toRad(midDeg)),
  };
}

export default function WheelDemo() {
  const [active, setActive] = useState<number | null>(null);
  const [paused, setPaused] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const autoIdx = useRef(0);

  useEffect(() => {
    if (paused) {
      if (timerRef.current) clearInterval(timerRef.current);
      return;
    }
    timerRef.current = setInterval(() => {
      autoIdx.current = (autoIdx.current + 1) % 8;
      setActive(autoIdx.current);
    }, 1500);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [paused]);

  return (
    <section
      id="wheel"
      style={{ background: "var(--surface)" }}
      className="py-24 px-6"
    >
      <div className="max-w-5xl mx-auto flex flex-col items-center">
        <p
          className="text-xs font-semibold tracking-widest uppercase mb-3 text-center"
          style={{ color: "var(--accent)" }}
        >
          Interface
        </p>
        <h2
          className="text-4xl sm:text-5xl font-bold tracking-tight text-center mb-14"
          style={{ color: "var(--text)" }}
        >
          The wheel
        </h2>

        <div
          onMouseEnter={() => setPaused(true)}
          onMouseLeave={() => { setPaused(false); setActive(null); }}
        >
          <svg
            viewBox="0 0 400 400"
            width={340}
            height={340}
            aria-label="Interactive wheel demo"
          >
            <defs>
              <filter id="glow">
                <feGaussianBlur stdDeviation="6" result="blur" />
                <feMerge>
                  <feMergeNode in="blur" />
                  <feMergeNode in="SourceGraphic" />
                </feMerge>
              </filter>
            </defs>

            {LABELS.map((label, i) => {
              const startDeg = i * 45 - 22.5 + GAP / 2;
              const endDeg = (i + 1) * 45 - 22.5 - GAP / 2;
              const isActive = active === i;
              const pos = labelPos(i);

              return (
                <g
                  key={label}
                  onMouseEnter={() => setActive(i)}
                  style={{ cursor: "pointer" }}
                >
                  <path
                    d={segmentPath(CX, CY, R1, R2, startDeg, endDeg)}
                    fill={
                      isActive
                        ? "rgba(124,106,247,0.55)"
                        : "rgba(124,106,247,0.08)"
                    }
                    stroke={
                      isActive
                        ? "rgba(124,106,247,0.9)"
                        : "rgba(124,106,247,0.2)"
                    }
                    strokeWidth={1}
                    filter={isActive ? "url(#glow)" : undefined}
                    style={{ transition: "fill 0.2s, stroke 0.2s" }}
                  />
                  {/* Label */}
                  <text
                    x={pos.x}
                    y={pos.y}
                    textAnchor="middle"
                    dominantBaseline="middle"
                    fontSize={10}
                    fontFamily="system-ui, sans-serif"
                    fontWeight={isActive ? 600 : 400}
                    fill={isActive ? "#c4baff" : "rgba(144,144,168,0.7)"}
                    style={{ transition: "fill 0.2s", pointerEvents: "none", userSelect: "none" }}
                  >
                    {label}
                  </text>
                </g>
              );
            })}

            {/* Dead zone circle */}
            <circle
              cx={CX}
              cy={CY}
              r={R1 - 2}
              fill="rgba(7,7,10,0.85)"
              stroke="rgba(124,106,247,0.15)"
              strokeWidth={1}
            />
            <text
              x={CX}
              y={CY}
              textAnchor="middle"
              dominantBaseline="middle"
              fontSize={9}
              fontFamily="system-ui, sans-serif"
              fill="rgba(90,90,114,0.8)"
              style={{ userSelect: "none" }}
            >
              dead zone
            </text>
          </svg>
        </div>

        <p
          className="mt-8 text-sm text-center"
          style={{ color: "var(--text-muted)" }}
        >
          8 directions. Zero clicks. Infinite control.
        </p>
      </div>
    </section>
  );
}
