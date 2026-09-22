"use client";

export default function VideoSection() {
  return (
    <section
      id="demo"
      style={{ background: "var(--bg)" }}
      className="py-24 px-6"
    >
      <div className="max-w-5xl mx-auto flex flex-col items-center">
        <p
          className="text-xs font-semibold tracking-widest uppercase mb-3 text-center"
          style={{ color: "var(--accent)" }}
        >
          Demo
        </p>
        <h2
          className="text-4xl sm:text-5xl font-bold tracking-tight text-center mb-12"
          style={{ color: "var(--text)" }}
        >
          See it in action
        </h2>

        <div
          className="w-full max-w-4xl rounded-2xl overflow-hidden relative"
          style={{
            background: "var(--surface)",
            border: "1px solid rgba(124,106,247,0.25)",
            boxShadow: "0 0 48px rgba(124,106,247,0.12)",
          }}
        >
          <video
            autoPlay
            muted
            loop
            playsInline
            className="w-full block"
            style={{ aspectRatio: "16/9", objectFit: "cover" }}
          >
            <source src="/biblo_1.mp4" type="video/mp4" />
          </video>
        </div>
      </div>
    </section>
  );
}
