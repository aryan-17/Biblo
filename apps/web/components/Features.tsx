const features = [
  {
    icon: "⬡",
    title: "Muscle Memory",
    body: "Eight directions, eight habits. Your hands learn the wheel in minutes. After a week, you stop thinking about it entirely — you just move.",
  },
  {
    icon: "⇄",
    title: "Two-Level Actions",
    body: "Each segment can hold a single action or a scrollable stack. Hover and scroll to select; release to fire. No menus. No clicking.",
  },
  {
    icon: "⚙",
    title: "Fully Configurable",
    body: "Set any segment to launch an app, run a shell script, execute a Shortcut, or send a keystroke. The control panel keeps it native and fast.",
  },
  {
    icon: "⚡",
    title: "Zero Latency",
    body: "The wheel pre-renders at launch. Keydown to visible in under 16ms. The frontmost app never changes — context stays intact.",
  },
];

export default function Features() {
  return (
    <section
      id="features"
      className="py-32 px-6"
      style={{ background: "#07070a" }}
    >
      <div className="max-w-5xl mx-auto">
        <p
          className="text-center text-xs font-semibold tracking-widest uppercase mb-4"
          style={{ color: "var(--accent)" }}
        >
          Why Biblo
        </p>
        <h2
          className="text-4xl sm:text-5xl font-bold text-center mb-16 leading-tight"
          style={{ color: "#e8e8f0" }}
        >
          Built for people who
          <br />
          hate reaching for the mouse.
        </h2>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          {features.map((f) => (
            <div
              key={f.title}
              className="rounded-2xl p-8 transition-all duration-300 hover:scale-[1.02]"
              style={{
                background: "var(--surface)",
                border: "1px solid var(--border)",
              }}
            >
              <span
                className="text-3xl block mb-4"
                style={{ color: "var(--accent)" }}
              >
                {f.icon}
              </span>
              <h3
                className="text-lg font-semibold mb-2"
                style={{ color: "#e8e8f0" }}
              >
                {f.title}
              </h3>
              <p className="text-sm leading-relaxed" style={{ color: "#5a5a72" }}>
                {f.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
