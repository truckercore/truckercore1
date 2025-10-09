"use client";
import { useEffect, useState } from "react";

const M = {
  en: {
    "Emergency vehicle ahead": "Emergency vehicle ahead",
    why: "Why",
    confidence: "confidence",
  },
  es: {
    "Emergency vehicle ahead": "Vehículo de emergencia adelante",
    why: "Por qué",
    confidence: "confianza",
  },
};

export function useLocale() {
  const [lang, setLang] = useState<keyof typeof M>("en");
  useEffect(() => {
    const l = (navigator.language || "en").toLowerCase();
    setLang(l.startsWith("es") ? "es" : "en");
  }, []);
  return {
    t: (s: string) => ((M[lang] as any)[s] as string) ?? s,
    lang,
  };
}
