// TypeScript
export type Locale = "en" | "es" | "fr";

const dict: Record<Locale, Record<string, string>> = {
  en: {
    slowdownAhead: "Slowdown ahead",
    followSpeed: "Follow safe speed",
  },
  es: {
    slowdownAhead: "Reducción de velocidad adelante",
    followSpeed: "Siga la velocidad segura",
  },
  fr: {
    slowdownAhead: "Ralentissement en avant",
    followSpeed: "Respectez la vitesse sûre",
  },
};

export function t(key: string, locale: Locale = "en") {
  return dict[locale]?.[key] ?? dict.en[key] ?? key;
}
