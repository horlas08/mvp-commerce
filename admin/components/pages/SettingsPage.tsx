"use client";

import { useEffect, useState, useCallback } from "react";
import { Save, RefreshCw, AlertCircle, Truck, Percent } from "lucide-react";
import { adminApi, PricingPolicy } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

interface PolicyState {
  value_en: string;
  value_ar: string;
}

export default function SettingsPage() {
  const { t } = useLang();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // Policies & Checkout fees form state
  const [shippingConfirmation, setShippingConfirmation] = useState<PolicyState>({ value_en: "", value_ar: "" });
  const [inspectionPolicy, setInspectionPolicy] = useState<PolicyState>({ value_en: "", value_ar: "" });
  const [pickupDelivery, setPickupDelivery] = useState<PolicyState>({ value_en: "", value_ar: "" });
  const [teamReviewFee, setTeamReviewFee] = useState<PolicyState>({ value_en: "5.0", value_ar: "5.0" });

  // Pricing Policy
  const [pricingPolicy, setPricingPolicy] = useState<PricingPolicy>({
    shipping_mode: "fixed",
    shipping_value: 0,
    shipping_hidden: false,
    commission_mode: "fixed",
    commission_value: 0,
    commission_hidden: false,
  });
  const [savingPolicy, setSavingPolicy] = useState(false);

  const loadSettings = useCallback(async () => {
    setLoading(true);
    setError("");
    setSuccess("");
    try {
      const res = await adminApi.listAppSettings();
      if (res.shipping_confirmation) {
        setShippingConfirmation({
          value_en: res.shipping_confirmation.value_en,
          value_ar: res.shipping_confirmation.value_ar,
        });
      }
      if (res.inspection_policy) {
        setInspectionPolicy({
          value_en: res.inspection_policy.value_en,
          value_ar: res.inspection_policy.value_ar,
        });
      }
      if (res.pickup_delivery) {
        setPickupDelivery({
          value_en: res.pickup_delivery.value_en,
          value_ar: res.pickup_delivery.value_ar,
        });
      }
      if (res.team_review_fee) {
        setTeamReviewFee({
          value_en: res.team_review_fee.value_en,
          value_ar: res.team_review_fee.value_ar,
        });
      }
      // Load pricing policy
      const policy = await adminApi.getPricingPolicy();
      setPricingPolicy(policy);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to load settings");
    } finally {
      setLoading(false);
    }
  }, []);

  const handleSavePricingPolicy = async () => {
    setSavingPolicy(true);
    setError("");
    setSuccess("");
    try {
      await adminApi.savePricingPolicy(pricingPolicy);
      setSuccess("Pricing policy saved successfully");
      setTimeout(() => setSuccess(""), 3000);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to save pricing policy");
    } finally {
      setSavingPolicy(false);
    }
  };

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  const handleSave = async (key: string, data: PolicyState) => {
    setSaving(key);
    setError("");
    setSuccess("");
    try {
      await adminApi.updateAppSetting(key, data);
      setSuccess(t("settingsUpdatedSuccess"));
      // Auto clear success message after 3 seconds
      setTimeout(() => setSuccess(""), 3000);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSaving(null);
    }
  };

  if (loading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", alignItems: "center", padding: 100 }}>
        <div className="spinner" style={{ width: 40, height: 40 }} />
      </div>
    );
  }

  return (
    <div className="page-container">
      <div className="page-header" style={{ marginBottom: 20 }}>
        <div>
          <h1 className="page-title">{t("appSettingsPolicies")}</h1>
          <p className="page-subtitle" style={{ color: "var(--text-muted)", fontSize: 13, marginTop: 4 }}>
            {t("appSettingsSubtitle")}
          </p>
        </div>
        <button className="btn btn-secondary btn-sm" onClick={loadSettings}>
          <RefreshCw size={14} style={{ marginRight: 6 }} />
          {t("refresh")}
        </button>
      </div>

      {error && (
        <div className="alert alert-danger" style={{ marginBottom: 20, display: "flex", alignItems: "center", gap: 10 }}>
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      {success && (
        <div className="alert alert-success" style={{ marginBottom: 20, display: "flex", alignItems: "center", gap: 10, background: "var(--success-bg)", color: "var(--success)", border: "1px solid var(--success-border)", padding: "12px 16px", borderRadius: 10 }}>
          <span>{success}</span>
        </div>
      )}

      <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
        {/* Team Review Before Shipping Fee */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <div>
              <h3 style={{ fontSize: 16, fontWeight: 700 }}>{t("teamReviewBeforeShippingFee")}</h3>
              <p style={{ color: "var(--text-muted)", fontSize: 12, marginTop: 2 }}>
                {t("teamReviewFeeDesc")}
              </p>
            </div>
            <button
              className="btn btn-primary btn-sm"
              disabled={saving !== null}
              onClick={() => handleSave("team_review_fee", { value_en: teamReviewFee.value_en, value_ar: teamReviewFee.value_en })}
            >
              {saving === "team_review_fee" ? (
                <div className="spinner" style={{ width: 14, height: 14 }} />
              ) : (
                <>
                  <Save size={14} style={{ marginRight: 6 }} />
                  {t("saveFee")}
                </>
              )}
            </button>
          </div>

          <div style={{ maxWidth: 320 }}>
            <div className="form-group">
              <label className="form-label">{t("reviewFeeSar")}</label>
              <input
                type="number"
                step="0.5"
                min="0"
                className="input"
                value={teamReviewFee.value_en}
                onChange={e => setTeamReviewFee({ value_en: e.target.value, value_ar: e.target.value })}
                placeholder="5.0"
              />
            </div>
          </div>
        </div>

        {/* Shipping & Confirmation Policy */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700 }}>{t("shippingConfirmationPolicy")}</h3>
            <button
              className="btn btn-primary btn-sm"
              disabled={saving !== null}
              onClick={() => handleSave("shipping_confirmation", shippingConfirmation)}
            >
              {saving === "shipping_confirmation" ? (
                <div className="spinner" style={{ width: 14, height: 14 }} />
              ) : (
                <>
                  <Save size={14} style={{ marginRight: 6 }} />
                  {t("saveSection")}
                </>
              )}
            </button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <div className="form-group">
              <label className="form-label">{t("policyTextEn")}</label>
              <textarea
                className="input"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={shippingConfirmation.value_en}
                onChange={e => setShippingConfirmation(f => ({ ...f, value_en: e.target.value }))}
                placeholder={t("markdownSupported")}
              />
            </div>
            <div className="form-group">
              <label className="form-label">{t("policyTextAr")}</label>
              <textarea
                className="input"
                dir="rtl"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={shippingConfirmation.value_ar}
                onChange={e => setShippingConfirmation(f => ({ ...f, value_ar: e.target.value }))}
                placeholder={t("markdownSupported")}
              />
            </div>
          </div>
        </div>

        {/* Inspection Policy */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700 }}>{t("inspectionPolicyTitle")}</h3>
            <button
              className="btn btn-primary btn-sm"
              disabled={saving !== null}
              onClick={() => handleSave("inspection_policy", inspectionPolicy)}
            >
              {saving === "inspection_policy" ? (
                <div className="spinner" style={{ width: 14, height: 14 }} />
              ) : (
                <>
                  <Save size={14} style={{ marginRight: 6 }} />
                  {t("saveSection")}
                </>
              )}
            </button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <div className="form-group">
              <label className="form-label">{t("policyTextEn")}</label>
              <textarea
                className="input"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={inspectionPolicy.value_en}
                onChange={e => setInspectionPolicy(f => ({ ...f, value_en: e.target.value }))}
                placeholder={t("markdownSupported")}
              />
            </div>
            <div className="form-group">
              <label className="form-label">{t("policyTextAr")}</label>
              <textarea
                className="input"
                dir="rtl"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={inspectionPolicy.value_ar}
                onChange={e => setInspectionPolicy(f => ({ ...f, value_ar: e.target.value }))}
                placeholder={t("markdownSupported")}
              />
            </div>
          </div>
        </div>

        {/* Pickup & Delivery Policy */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700 }}>{t("pickupDeliveryPolicy")}</h3>
            <button
              className="btn btn-primary btn-sm"
              disabled={saving !== null}
              onClick={() => handleSave("pickup_delivery", pickupDelivery)}
            >
              {saving === "pickup_delivery" ? (
                <div className="spinner" style={{ width: 14, height: 14 }} />
              ) : (
                <>
                  <Save size={14} style={{ marginRight: 6 }} />
                  {t("saveSection")}
                </>
              )}
            </button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <div className="form-group">
              <label className="form-label">{t("policyTextEn")}</label>
              <textarea
                className="input"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={pickupDelivery.value_en}
                onChange={e => setPickupDelivery(f => ({ ...f, value_en: e.target.value }))}
                placeholder={t("markdownSupported")}
              />
            </div>
            <div className="form-group">
              <label className="form-label">{t("policyTextAr")}</label>
              <textarea
                className="input"
                dir="rtl"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={pickupDelivery.value_ar}
                onChange={e => setPickupDelivery(f => ({ ...f, value_ar: e.target.value }))}
                placeholder={t("markdownSupported")}
              />
            </div>
          </div>
        </div>

        {/* ── Pricing Policy ── */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}>
            <div>
              <h3 style={{ fontSize: 16, fontWeight: 700, display: "flex", alignItems: "center", gap: 8 }}>
                <Truck size={16} /> Pricing Policy
              </h3>
              <p style={{ color: "var(--text-muted)", fontSize: 12, marginTop: 2 }}>
                Global default shipping &amp; commission applied when no state/city rate is configured.
              </p>
            </div>
            <button
              className="btn btn-primary btn-sm"
              disabled={savingPolicy}
              onClick={handleSavePricingPolicy}
            >
              {savingPolicy ? (
                <div className="spinner" style={{ width: 14, height: 14 }} />
              ) : (
                <><Save size={14} style={{ marginRight: 6 }} />Save Policy</>
              )}
            </button>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 24 }}>
            {/* Shipping */}
            <div style={{ background: "var(--bg-subtle, rgba(0,0,0,0.03))", borderRadius: 10, padding: 16, border: "1px solid var(--border)" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 14 }}>
                <Truck size={14} style={{ color: "var(--primary)" }} />
                <span style={{ fontWeight: 600, fontSize: 14 }}>Shipping Fee</span>
              </div>

              <div className="form-group" style={{ marginBottom: 12 }}>
                <label className="form-label">Mode</label>
                <select
                  className="input"
                  value={pricingPolicy.shipping_mode}
                  onChange={e => setPricingPolicy(p => ({ ...p, shipping_mode: e.target.value as "fixed" | "formula" }))}
                >
                  <option value="fixed">Fixed Amount (e.g. 200 YER)</option>
                  <option value="formula">Formula — Price × factor (e.g. 0.05)</option>
                </select>
              </div>

              <div className="form-group" style={{ marginBottom: 12 }}>
                <label className="form-label">
                  {pricingPolicy.shipping_mode === "fixed" ? "Amount" : "Multiplier (e.g. 0.05 = 5%)"}
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  className="input"
                  value={pricingPolicy.shipping_value}
                  onChange={e => setPricingPolicy(p => ({ ...p, shipping_value: parseFloat(e.target.value) || 0 }))}
                  placeholder={pricingPolicy.shipping_mode === "fixed" ? "e.g. 200" : "e.g. 0.05"}
                />
              </div>

              <label style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer", fontSize: 13 }}>
                <input
                  type="checkbox"
                  checked={pricingPolicy.shipping_hidden}
                  onChange={e => setPricingPolicy(p => ({ ...p, shipping_hidden: e.target.checked }))}
                />
                Hide shipping statement on product page
              </label>
            </div>

            {/* Commission */}
            <div style={{ background: "var(--bg-subtle, rgba(0,0,0,0.03))", borderRadius: 10, padding: 16, border: "1px solid var(--border)" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 14 }}>
                <Percent size={14} style={{ color: "var(--primary)" }} />
                <span style={{ fontWeight: 600, fontSize: 14 }}>Commission</span>
              </div>

              <div className="form-group" style={{ marginBottom: 12 }}>
                <label className="form-label">Mode</label>
                <select
                  className="input"
                  value={pricingPolicy.commission_mode}
                  onChange={e => setPricingPolicy(p => ({ ...p, commission_mode: e.target.value as "fixed" | "formula" }))}
                >
                  <option value="fixed">Fixed Amount</option>
                  <option value="formula">Formula — Price × factor</option>
                </select>
              </div>

              <div className="form-group" style={{ marginBottom: 12 }}>
                <label className="form-label">
                  {pricingPolicy.commission_mode === "fixed" ? "Amount" : "Multiplier (e.g. 0.05 = 5%)"}
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  className="input"
                  value={pricingPolicy.commission_value}
                  onChange={e => setPricingPolicy(p => ({ ...p, commission_value: parseFloat(e.target.value) || 0 }))}
                  placeholder={pricingPolicy.commission_mode === "fixed" ? "e.g. 50" : "e.g. 0.05"}
                />
              </div>

              <label style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer", fontSize: 13 }}>
                <input
                  type="checkbox"
                  checked={pricingPolicy.commission_hidden}
                  onChange={e => setPricingPolicy(p => ({ ...p, commission_hidden: e.target.checked }))}
                />
                Hide commission statement on product page
              </label>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
