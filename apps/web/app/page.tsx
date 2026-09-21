import Hero from "@/components/HeroWrapper";
import HowItWorks from "@/components/HowItWorks";
import WheelDemo from "@/components/WheelDemo";
import Features from "@/components/Features";
import VideoSection from "@/components/VideoSection";
import Download from "@/components/Download";
import Feedback from "@/components/Feedback";

export default function Home() {
  return (
    <main>
      <Hero />
      <HowItWorks />
      <WheelDemo />
      <Features />
      <VideoSection />
      <Download />
      <Feedback formspreeId={process.env.FORMSPREE_ID ?? ""} />
    </main>
  );
}
