// ponytail: static version for MVP — swap for GitHub Releases API fetch when first release ships
const VERSION = "0.1.0";
const DMG_URL =
  "https://github.com/yourusername/biblo/releases/latest/download/Biblo.dmg";

export default function Download() {
  return (
    <section
      id="download"
      className="py-32 px-6"
      style={{ background: "var(--surface)", borderTop: "1px solid var(--border)" }}
    >
      <div className="max-w-2xl mx-auto text-center">
        <p
          className="text-xs font-semibold tracking-widest uppercase mb-4"
          style={{ color: "var(--accent)" }}
        >
          Download
        </p>

        <h2
          className="text-4xl sm:text-5xl font-bold mb-4 leading-tight"
          style={{ color: "#e8e8f0" }}
        >
          Get Biblo
        </h2>

        <p className="text-sm mb-2" style={{ color: "#5a5a72" }}>
          Version {VERSION} · Requires macOS 13 Ventura or later
        </p>

        <p className="text-sm mb-10" style={{ color: "#5a5a72" }}>
          Developer ID signed & notarized by Apple
        </p>

        <a
          href={DMG_URL}
          className="inline-flex items-center gap-3 px-10 py-4 rounded-full font-semibold text-base transition-all duration-200 hover:opacity-90 active:scale-95"
          style={{
            background: "linear-gradient(135deg, #7c6af7, #5b4fd4)",
            color: "#fff",
            boxShadow: "0 0 40px rgba(124,106,247,0.4)",
          }}
        >
          {/* Apple logo */}
          <svg width="18" height="22" viewBox="0 0 18 22" fill="currentColor">
            <path d="M14.94 11.61c-.03-3.1 2.54-4.6 2.65-4.67-1.44-2.1-3.68-2.39-4.48-2.43-1.9-.19-3.72 1.12-4.69 1.12-.97 0-2.46-1.1-4.05-1.07C2.13 4.61.3 5.74-.6 7.5c-1.82 3.16-.47 7.84 1.3 10.4.87 1.25 1.9 2.65 3.25 2.6 1.31-.05 1.81-.84 3.4-.84 1.58 0 2.04.84 3.42.81 1.41-.02 2.3-1.27 3.16-2.53.99-1.45 1.4-2.86 1.42-2.93-.03-.01-2.72-1.04-2.75-4.1.03-.01.06-.01.09-.01zM12.19 2.8C12.92 1.9 13.4.69 13.26-.58c-1.09.05-2.41.73-3.19 1.64-.7.8-1.31 2.08-1.15 3.3 1.22.09 2.46-.62 3.27-1.56z" />
          </svg>
          Download for Mac
        </a>

        <p className="text-xs mt-6" style={{ color: "#3a3a50" }}>
          Free during beta · Auto-updates via Sparkle
        </p>
      </div>
    </section>
  );
}
