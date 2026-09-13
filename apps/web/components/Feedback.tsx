"use client";

import { useState, FormEvent } from "react";

const FORMSPREE_ID = process.env.FORMSPREE_ID ?? "";

export default function Feedback() {
  const [status, setStatus] = useState<"idle" | "sending" | "done" | "error">(
    "idle"
  );

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!FORMSPREE_ID) return;
    setStatus("sending");
    const form = e.currentTarget;
    const data = new FormData(form);
    const res = await fetch(`https://formspree.io/f/${FORMSPREE_ID}`, {
      method: "POST",
      body: data,
      headers: { Accept: "application/json" },
    });
    if (res.ok) {
      setStatus("done");
      form.reset();
    } else {
      setStatus("error");
    }
  }

  return (
    <section
      id="feedback"
      className="py-32 px-6"
      style={{ background: "#07070a", borderTop: "1px solid var(--border)" }}
    >
      <div className="max-w-lg mx-auto">
        <p
          className="text-center text-xs font-semibold tracking-widest uppercase mb-4"
          style={{ color: "var(--accent)" }}
        >
          Feedback
        </p>

        <h2
          className="text-4xl font-bold text-center mb-4"
          style={{ color: "#e8e8f0" }}
        >
          Tell us what you think
        </h2>

        <p
          className="text-center text-sm mb-12"
          style={{ color: "#5a5a72" }}
        >
          Biblo is early. Your feedback directly shapes what gets built next.
        </p>

        {status === "done" ? (
          <p
            className="text-center text-sm py-8 rounded-2xl"
            style={{
              background: "var(--surface)",
              border: "1px solid var(--border)",
              color: "#a89ef9",
            }}
          >
            Received. Thank you — we read every message.
          </p>
        ) : (
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            <input
              name="name"
              type="text"
              placeholder="Name"
              required
              className="w-full px-5 py-3.5 rounded-xl text-sm outline-none transition-all"
              style={{
                background: "var(--surface)",
                border: "1px solid var(--border)",
                color: "var(--text)",
              }}
              onFocus={(e) =>
                (e.currentTarget.style.borderColor = "rgba(124,106,247,0.5)")
              }
              onBlur={(e) =>
                (e.currentTarget.style.borderColor = "var(--border)")
              }
            />
            <input
              name="email"
              type="email"
              placeholder="Email"
              required
              className="w-full px-5 py-3.5 rounded-xl text-sm outline-none transition-all"
              style={{
                background: "var(--surface)",
                border: "1px solid var(--border)",
                color: "var(--text)",
              }}
              onFocus={(e) =>
                (e.currentTarget.style.borderColor = "rgba(124,106,247,0.5)")
              }
              onBlur={(e) =>
                (e.currentTarget.style.borderColor = "var(--border)")
              }
            />
            <textarea
              name="message"
              placeholder="What would make Biblo indispensable for you?"
              required
              rows={5}
              className="w-full px-5 py-3.5 rounded-xl text-sm outline-none transition-all resize-none"
              style={{
                background: "var(--surface)",
                border: "1px solid var(--border)",
                color: "var(--text)",
              }}
              onFocus={(e) =>
                (e.currentTarget.style.borderColor = "rgba(124,106,247,0.5)")
              }
              onBlur={(e) =>
                (e.currentTarget.style.borderColor = "var(--border)")
              }
            />

            {status === "error" && (
              <p className="text-xs text-red-400">
                Something went wrong. Try again or email us directly.
              </p>
            )}

            <button
              type="submit"
              disabled={status === "sending" || !FORMSPREE_ID}
              className="w-full py-3.5 rounded-full font-semibold text-sm transition-all duration-200 disabled:opacity-50"
              style={{
                background: "linear-gradient(135deg, #7c6af7, #5b4fd4)",
                color: "#fff",
              }}
            >
              {status === "sending" ? "Sending…" : "Send Feedback"}
            </button>


          </form>
        )}
      </div>
    </section>
  );
}
