"use client";

import { useState } from "react";
import { useAuth } from "@/lib/auth-context";
import { adminApi } from "@/lib/api";
import { useLang } from "@/lib/lang-context";
import LangSwitcher from "@/components/LangSwitcher";

export default function LoginPage() {
  const { login } = useAuth();
  const { t, lang } = useLang();
  const [email, setEmail] = useState("admin@koon.sa");
  const [password, setPassword] = useState("admin123");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [seeding, setSeeding] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      await login(email, password);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  };

  const handleSeedAdmin = async () => {
    setSeeding(true);
    try {
      const res = await adminApi.seedAdmin();
      setEmail(res.email);
      setPassword("admin123");
      setError("");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : t("failedToLoad"));
    } finally {
      setSeeding(false);
    }
  };

  return (
    <div className="login-page">
      {/* Floating Language Switcher */}
      <div style={{
        position: "absolute",
        top: 20,
        right: lang === "ar" ? "auto" : 20,
        left: lang === "ar" ? 20 : "auto",
        zIndex: 10,
      }}>
        <LangSwitcher />
      </div>

      <div className="login-bg-gradient" />
      <div className="login-card">
        {/* Logo */}
        <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 32 }}>
          <div className="logo-icon" style={{ width: 52, height: 52, fontSize: 24, borderRadius: 14 }}>K</div>
          <div>
            <div style={{ fontSize: 22, fontWeight: 800, color: "var(--text-primary)", letterSpacing: -0.5 }}>
              {t("koonAdmin")}
            </div>
            <div style={{ fontSize: 13, color: "var(--text-muted)" }}>{t("commerceDashboard")}</div>
          </div>
        </div>

        <div style={{ marginBottom: 24 }}>
          <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 6 }}>{t("welcomeBack")}</h1>
          <p style={{ color: "var(--text-secondary)", fontSize: 14 }}>{t("signInSubtitle")}</p>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <div className="form-group">
            <label className="form-label" htmlFor="email">{t("email")}</label>
            <input
              id="email"
              type="email"
              className="input"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="admin@koon.sa"
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="password">{t("password")}</label>
            <input
              id="password"
              type="password"
              className="input"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />
          </div>

          <button
            id="login-submit"
            type="submit"
            className="btn btn-primary"
            disabled={loading}
            style={{ width: "100%", justifyContent: "center", padding: "12px" }}
          >
            {loading ? <div className="spinner" /> : t("signIn")}
          </button>
        </form>

        {/* Setup helper */}
        <div style={{
          marginTop: 24,
          paddingTop: 20,
          borderTop: "1px solid var(--border)",
          display: "flex",
          flexDirection: "column",
          gap: 8,
        }}>
          <p style={{ fontSize: 12, color: "var(--text-muted)", textAlign: "center" }}>
            {t("firstTimeTitle")}
          </p>
          <button
            id="seed-admin"
            onClick={handleSeedAdmin}
            disabled={seeding}
            className="btn btn-ghost"
            style={{ justifyContent: "center" }}
          >
            {seeding ? <div className="spinner" /> : t("createAdminAccount")}
          </button>
        </div>
      </div>
    </div>
  );
}
