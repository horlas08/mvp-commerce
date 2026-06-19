"use client";

import { useLang } from "@/lib/lang-context";
import { Globe } from "lucide-react";

export default function LangSwitcher() {
  const { lang, setLang } = useLang();

  return (
    <button
      onClick={() => setLang(lang === "en" ? "ar" : "en")}
      className="btn btn-ghost"
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 6,
        padding: "6px 12px",
        height: 36,
        fontSize: 13,
        fontWeight: 600,
      }}
      title={lang === "en" ? "تغيير اللغة إلى العربية" : "Change language to English"}
    >
      <Globe size={15} />
      <span>{lang === "en" ? "العربية" : "English"}</span>
    </button>
  );
}
