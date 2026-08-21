export type Lang = "de" | "en";

const dict: Record<string, Record<Lang, string>> = {
  "nav.start": { de: "Start", en: "Home" },
  "nav.faenge": { de: "Fänge", en: "Catches" },
  "nav.erfassen": { de: "Erfassen", en: "Log" },
  "nav.rueckblick": { de: "Rückblick", en: "Review" },
  "nav.trips": { de: "Trips", en: "Trips" },
  "nav.board": { de: "Board", en: "Board" },
  "nav.forum": { de: "Forum", en: "Forum" },
  "nav.chat": { de: "Chat", en: "Chat" },
  "nav.premium": { de: "Premium", en: "Premium" },
  "nav.profil": { de: "Profil", en: "Profile" },
  "nav.abmelden": { de: "Abmelden", en: "Sign out" },
  "nav.thema": { de: "Thema", en: "Theme" },
  "nav.signin": { de: "Anmelden", en: "Sign In" },
  "nav.statistik": { de: "Statistik", en: "Statistics" },
  "kicker": { de: "PASSION. FISHING. COMMUNITY.", en: "PASSION. FISHING. COMMUNITY." },
  "footer.impressum": { de: "Impressum", en: "Legal" },
  "footer.datenschutz": { de: "Datenschutz", en: "Privacy" },
  "footer.rights": { de: "© 2026 Carp24. All rights reserved.", en: "© 2026 Carp24. All rights reserved." },
};

export function getLang(): Lang {
  if (typeof window !== "undefined") {
    const stored = localStorage.getItem("carp24-lang");
    if (stored === "de" || stored === "en") return stored;
  }
  return "de";
}

export function t(key: string, lang?: Lang): string {
  const l = lang ?? getLang();
  return dict[key]?.[l] ?? dict[key]?.de ?? key;
}

export const LANGS: { code: Lang; label: string }[] = [
  { code: "de", label: "DE" },
  { code: "en", label: "EN" },
];
