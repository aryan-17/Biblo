"use client";

import { useRef, useMemo } from "react";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import * as THREE from "three";

// ─── GLSL ────────────────────────────────────────────────────────────────────

const vertexShader = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position, 1.0);
  }
`;

const fragmentShader = /* glsl */ `
  uniform float u_time;
  uniform vec2  u_resolution;
  uniform vec2  u_mouse;        // normalised 0-1
  varying vec2  vUv;

  // ── Simplex noise helpers ──────────────────────────────────────────────────
  vec3 mod289(vec3 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
  vec4 mod289(vec4 x) { return x - floor(x * (1.0/289.0)) * 289.0; }
  vec4 permute(vec4 x) { return mod289(((x*34.0)+1.0)*x); }
  vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

  float snoise(vec3 v) {
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g  = step(x0.yzx, x0.xyz);
    vec3 l  = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    i = mod289(i);
    vec4 p = permute(permute(permute(
      i.z + vec4(0.0, i1.z, i2.z, 1.0))
      + i.y + vec4(0.0, i1.y, i2.y, 1.0))
      + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    vec4 j  = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    vec4 x  = x_ * ns.x + ns.yyyy;
    vec4 y  = y_ * ns.x + ns.yyyy;
    vec4 h  = 1.0 - abs(x) - abs(y);
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
  }

  // ── Turbulence ────────────────────────────────────────────────────────────
  float turbulence(vec3 p) {
    float w = 100.0;
    float t = -0.5;
    for (float f = 1.0; f <= 10.0; f++) {
      float power = pow(2.0, f);
      t += abs(snoise(vec3(power * p.xy, p.z)) / power);
    }
    return t;
  }

  void main() {
    // Mouse repulsion: push uv away from cursor slightly
    vec2 uv = vUv;
    vec2 toMouse = uv - u_mouse;
    float mouseDist = length(toMouse);
    uv += normalize(toMouse) * smoothstep(0.3, 0.0, mouseDist) * 0.04;

    float t = u_time * 0.12;

    // Two layers of turbulence for depth
    float n1 = turbulence(vec3(uv * 1.8, t));
    float n2 = turbulence(vec3(uv * 3.2 + 0.5, t * 0.7));

    float n = n1 * 0.7 + n2 * 0.3;

    // Deep dark background
    vec3 base = vec3(0.027, 0.027, 0.04);

    // Purple vein colour
    vec3 vein = vec3(0.42, 0.34, 0.97);

    // Blue-teal secondary
    vec3 cold = vec3(0.14, 0.28, 0.72);

    float blend = smoothstep(-0.1, 0.35, n);
    vec3 col = mix(base, mix(cold, vein, smoothstep(0.3, 0.7, uv.x + n * 0.3)), blend * 0.55);

    // Subtle radial vignette — darker edges
    float vig = 1.0 - length((vUv - 0.5) * 1.4);
    col *= smoothstep(0.0, 0.6, vig);

    gl_FragColor = vec4(col, 1.0);
  }
`;

// ─── Scene ───────────────────────────────────────────────────────────────────

function ShaderPlane() {
  const meshRef = useRef<THREE.Mesh>(null);
  const { size } = useThree();

  const uniforms = useMemo(
    () => ({
      u_time: { value: 0 },
      u_resolution: {
        value: new THREE.Vector2(size.width, size.height),
      },
      u_mouse: { value: new THREE.Vector2(0.5, 0.5) },
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    []
  );

  // Track mouse
  if (typeof window !== "undefined") {
    // Store handler ref to avoid leaking listeners
  }

  useFrame(({ clock, pointer }) => {
    uniforms.u_time.value = clock.elapsedTime;
    // pointer is -1..1, convert to 0..1
    uniforms.u_mouse.value.set(
      (pointer.x + 1) / 2,
      (pointer.y + 1) / 2
    );
  });

  return (
    <mesh ref={meshRef}>
      {/* fullscreen plane in clip space — no camera math needed */}
      <planeGeometry args={[2, 2]} />
      <shaderMaterial
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
      />
    </mesh>
  );
}

// ─── Hero ────────────────────────────────────────────────────────────────────

export default function HeroShader() {
  return (
    <section className="relative w-full h-screen flex items-center justify-center overflow-hidden">
      {/* WebGL backdrop */}
      <div className="absolute inset-0">
        <Canvas
          camera={{ position: [0, 0, 1] }}
          gl={{ antialias: false, alpha: false }}
          style={{ display: "block", width: "100%", height: "100%" }}
        >
          <ShaderPlane />
        </Canvas>
      </div>

      {/* Content overlay */}
      <div className="relative z-10 flex flex-col items-center text-center px-6 max-w-3xl">
        {/* Pill badge */}
        <span
          className="mb-6 px-4 py-1.5 rounded-full text-xs font-medium tracking-widest uppercase"
          style={{
            background: "rgba(124,106,247,0.12)",
            border: "1px solid rgba(124,106,247,0.3)",
            color: "#a89ef9",
          }}
        >
          macOS · v0.1 Now Available
        </span>

        <h1
          className="text-6xl sm:text-7xl md:text-8xl font-bold tracking-tight leading-none mb-6"
          style={{ color: "#e8e8f0" }}
        >
          Biblo
        </h1>

        <p
          className="text-xl sm:text-2xl font-light mb-3 leading-relaxed"
          style={{ color: "#9090a8" }}
        >
          Command at the speed of thought.
        </p>

        <p
          className="text-base max-w-md mb-10 leading-relaxed"
          style={{ color: "#5a5a72" }}
        >
          Hold a key. Flick a direction. Release. Your tools snap to your
          fingertips — no searching, no clicking, no thinking.
        </p>

        <div className="flex flex-col sm:flex-row gap-4">
          <a
            href="#download"
            className="px-8 py-3.5 rounded-full font-semibold text-sm transition-all duration-200"
            style={{
              background: "linear-gradient(135deg, #7c6af7, #5b4fd4)",
              color: "#fff",
              boxShadow: "0 0 32px rgba(124,106,247,0.35)",
            }}
          >
            Download for macOS
          </a>
          <a
            href="#features"
            className="px-8 py-3.5 rounded-full font-semibold text-sm transition-all duration-200"
            style={{
              border: "1px solid rgba(255,255,255,0.1)",
              color: "#9090a8",
            }}
          >
            How it works
          </a>
        </div>
      </div>

      {/* Bottom fade to dark */}
      <div
        className="absolute bottom-0 left-0 right-0 h-32 pointer-events-none"
        style={{
          background: "linear-gradient(to bottom, transparent, #07070a)",
        }}
      />
    </section>
  );
}
