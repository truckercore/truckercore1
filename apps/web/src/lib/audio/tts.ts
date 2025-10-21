// TypeScript
export type Tone = "calm" | "urgent";
export async function playGuidance(text: string, tone: Tone = "calm", locale: string = "en-US") {
  if (typeof window === "undefined") return;
  const synth = window.speechSynthesis;
  if (!synth) return;
  const utter = new SpeechSynthesisUtterance(text);
  utter.lang = locale;
  utter.rate = tone === "urgent" ? 1.15 : 0.95;
  utter.pitch = tone === "urgent" ? 1.1 : 1.0;
  synth.cancel();
  synth.speak(utter);
}
