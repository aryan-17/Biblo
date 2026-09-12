"use client";

import dynamic from "next/dynamic";

// ssr: false is only valid inside a Client Component (Next.js 16)
const HeroShader = dynamic(() => import("./HeroShader"), { ssr: false });

export default HeroShader;
