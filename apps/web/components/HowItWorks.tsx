"use client";

const steps = [
  {
    n: 1,
    title: "Hold",
    desc: "Press your hotkey. The wheel appears instantly at 16ms.",
  },
  {
    n: 2,
    title: "Flick",
    desc: "Move toward any of 8 segments. Dead zone prevents accidental fires.",
  },
  {
    n: 3,
    title: "Release",
    desc: "Your action fires. The frontmost app never loses focus.",
  },
];

export default function HowItWorks() {
  return (
    <section
      id="how-it-works"
      style={{ background: "var(--bg)" }}
      className="py-24 px-6"
    >
      <div className="max-w-5xl mx-auto">
        <p
          className="text-xs font-semibold tracking-widest uppercase mb-3 text-center"
          style={{ color: "var(--accent)" }}
        >
          Three gestures
        </p>
        <h2
          className="text-4xl sm:text-5xl font-bold tracking-tight text-center mb-16"
          style={{ color: "var(--text)" }}
        >
          How it works
        </h2>

        {/* Steps row */}
        <div className="relative flex flex-col sm:flex-row gap-0 sm:gap-0 items-stretch">
          {/* Connecting line — desktop only */}
          <div
            className="hidden sm:block absolute top-[28px] left-[calc(16.6%+28px)] right-[calc(16.6%+28px)] h-px"
            style={{ background: "rgba(124,106,247,0.2)" }}
          />

          {steps.map((step) => (
            <div
              key={step.n}
              className="flex flex-col items-center text-center flex-1 px-6 pb-10 sm:pb-0"
            >
              {/* Number circle */}
              <div
                className="w-14 h-14 rounded-full flex items-center justify-center text-lg font-bold mb-6 relative z-10"
                style={{
                  background: "rgba(124,106,247,0.15)",
                  border: "1.5px solid rgba(124,106,247,0.4)",
                  color: "var(--accent)",
                }}
              >
                {step.n}
              </div>
              <h3
                className="text-xl font-semibold mb-3"
                style={{ color: "var(--text)" }}
              >
                {step.title}
              </h3>
              <p className="text-sm leading-relaxed" style={{ color: "var(--text-muted)" }}>
                {step.desc}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
