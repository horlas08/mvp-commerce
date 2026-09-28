"use client";

import { useEffect, useState, useCallback } from "react";
import { Save, RefreshCw, AlertCircle, Truck, Percent, Globe, Plus, Trash2, Receipt } from "lucide-react";
import { adminApi, PricingPolicy, SitePricingPolicy } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

interface PolicyState {
  value_en: string;
  value_ar: string;
}

const AVAILABLE_SITES = [
  { key: "amazon", label: "Amazon" },
  { key: "aliexpress", label: "AliExpress" },
  { key: "shein", label: "Shein" },
  { key: "alibaba", label: "Alibaba" },
  { key: "iherb", label: "iHerb" },
  { key: "internal", label: "Internal Store" },
];

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
    tax_percentage: 0,
    sites: {},
  });
  const [newSiteKey, setNewSiteKey] = useState<string>("amazon");
  const [customSiteInput, setCustomSiteInput] = useState<string>("");
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

  const handleAddSite = () => {
    const siteKey = newSiteKey === "custom" ? customSiteInput.trim().toLowerCase() : newSiteKey;
    if (!siteKey) return;
    setPricingPolicy(prev => ({
      ...prev,
      sites: {
        ...(prev.sites || {}),
        [siteKey]: {
          shipping_mode: prev.shipping_mode,
          shipping_value: prev.shipping_value,
          shipping_hidden: prev.shipping_hidden,
          commission_mode: prev.commission_mode,
          commission_value: prev.commission_value,
          commission_hidden: prev.commission_hidden,
          tax_percentage: prev.tax_percentage || 0,
        },
      },
    }));
    if (newSiteKey === "custom") {
      setCustomSiteInput("");
    }
  };

  const handleRemoveSite = (siteKey: string) => {
    setPricingPolicy(prev => {
      const sites = { ...(prev.sites || {}) };
      delete sites[siteKey];
      return { ...prev, sites };
    });
  };

  const updateSitePolicy = (siteKey: string, updates: Partial<SitePricingPolicy>) => {
    setPricingPolicy(prev => ({
      ...prev,
      sites: {
        ...(prev.sites || {}),
        [siteKey]: {
          ...(prev.sites?.[siteKey] || {}),
          ...updates,
        },
      },
    }));
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

        {/* ── Pricing & Tax Policy ── */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}>
            <div>
              <h3 style={{ fontSize: 16, fontWeight: 700, display: "flex", alignItems: "center", gap: 8 }}>
                <Truck size={16} /> Pricing Policy &amp; Tax
              </h3>
              <p style={{ color: "var(--text-muted)", fontSize: 12, marginTop: 2 }}>
                Configure global fallback rates and per-site dynamic pricing (Amazon, AliExpress, Shein, etc.).
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
                <><Save size={14} style={{ marginRight: 6 }} />Save All Policies</>
              )}
            </button>
          </div>

          {/* Section: Global Default Fallback */}
          <div style={{ marginBottom: 24, padding: 16, background: "var(--bg-subtle, rgba(0,0,0,0.02))", borderRadius: 10, border: "1px solid var(--border)" }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <Globe size={16} style={{ color: "var(--primary)" }} />
                <span style={{ fontWeight: 700, fontSize: 14 }}>Global Fallback Policy</span>
                <span className="badge" style={{ fontSize: 11, background: "rgba(59,130,246,0.1)", color: "#3b82f6", padding: "2px 8px", borderRadius: 4 }}>
                  Default for all sites
                </span>
              </div>
              <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
                Applied whenever a specific site or city/state rate is not set.
              </span>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16 }}>
              {/* Shipping */}
              <div style={{ background: "var(--bg-card)", borderRadius: 8, padding: 14, border: "1px solid var(--border)" }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 10 }}>
                  <Truck size={14} style={{ color: "var(--primary)" }} />
                  <span style={{ fontWeight: 600, fontSize: 13 }}>Shipping Fee</span>
                </div>
                <div className="form-group" style={{ marginBottom: 8 }}>
                  <label className="form-label" style={{ fontSize: 11 }}>Mode</label>
                  <select
                    className="input"
                    style={{ fontSize: 12, padding: "6px 8px" }}
                    value={pricingPolicy.shipping_mode}
                    onChange={e => setPricingPolicy(p => ({ ...p, shipping_mode: e.target.value as "fixed" | "formula" }))}
                  >
                    <option value="fixed">Fixed Amount</option>
                    <option value="formula">Formula (Price × factor)</option>
                  </select>
                </div>
                <div className="form-group" style={{ marginBottom: 8 }}>
                  <label className="form-label" style={{ fontSize: 11 }}>
                    {pricingPolicy.shipping_mode === "fixed" ? "Amount" : "Multiplier (e.g. 0.05 = 5%)"}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="input"
                    style={{ fontSize: 12, padding: "6px 8px" }}
                    value={pricingPolicy.shipping_value}
                    onChange={e => setPricingPolicy(p => ({ ...p, shipping_value: parseFloat(e.target.value) || 0 }))}
                    placeholder={pricingPolicy.shipping_mode === "fixed" ? "e.g. 200" : "0.05"}
                  />
                </div>
              </div>

              {/* Commission */}
              <div style={{ background: "var(--bg-card)", borderRadius: 8, padding: 14, border: "1px solid var(--border)" }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 10 }}>
                  <Percent size={14} style={{ color: "var(--primary)" }} />
                  <span style={{ fontWeight: 600, fontSize: 13 }}>Commission Fee</span>
                </div>
                <div className="form-group" style={{ marginBottom: 8 }}>
                  <label className="form-label" style={{ fontSize: 11 }}>Mode</label>
                  <select
                    className="input"
                    style={{ fontSize: 12, padding: "6px 8px" }}
                    value={pricingPolicy.commission_mode}
                    onChange={e => setPricingPolicy(p => ({ ...p, commission_mode: e.target.value as "fixed" | "formula" }))}
                  >
                    <option value="fixed">Fixed Amount</option>
                    <option value="formula">Formula (Price × factor)</option>
                  </select>
                </div>
                <div className="form-group" style={{ marginBottom: 8 }}>
                  <label className="form-label" style={{ fontSize: 11 }}>
                    {pricingPolicy.commission_mode === "fixed" ? "Amount" : "Multiplier (e.g. 0.05 = 5%)"}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="input"
                    style={{ fontSize: 12, padding: "6px 8px" }}
                    value={pricingPolicy.commission_value}
                    onChange={e => setPricingPolicy(p => ({ ...p, commission_value: parseFloat(e.target.value) || 0 }))}
                    placeholder={pricingPolicy.commission_mode === "fixed" ? "e.g. 50" : "0.05"}
                  />
                </div>
              </div>

              {/* Tax Rate */}
              <div style={{ background: "var(--bg-card)", borderRadius: 8, padding: 14, border: "1px solid var(--border)" }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 10 }}>
                  <Receipt size={14} style={{ color: "var(--primary)" }} />
                  <span style={{ fontWeight: 600, fontSize: 13 }}>Tax Rate (Percentage)</span>
                </div>
                <div className="form-group" style={{ marginBottom: 8 }}>
                  <label className="form-label" style={{ fontSize: 11 }}>Tax Percentage (%)</label>
                  <div style={{ position: "relative" }}>
                    <input
                      type="number"
                      step="0.1"
                      min="0"
                      max="100"
                      className="input"
                      style={{ fontSize: 12, padding: "6px 8px" }}
                      value={pricingPolicy.tax_percentage ?? 0}
                      onChange={e => setPricingPolicy(p => ({ ...p, tax_percentage: parseFloat(e.target.value) || 0 }))}
                      placeholder="0.0"
                    />
                  </div>
                </div>
                <p style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 8 }}>
                  Default is 0%. Set e.g. 15 for 15% tax on taxable subtotal.
                </p>
              </div>
            </div>
          </div>

          {/* Section: Site-Specific Overrides */}
          <div style={{ marginTop: 24 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
              <div>
                <h4 style={{ fontSize: 14, fontWeight: 700, margin: 0, display: "flex", alignItems: "center", gap: 6 }}>
                  Site-Specific Pricing Overrides
                </h4>
                <p style={{ color: "var(--text-muted)", fontSize: 12, margin: "2px 0 0" }}>
                  Set custom shipping, commission, and tax for individual ecommerce sites.
                </p>
              </div>

              {/* Add site bar */}
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <select
                  className="input"
                  style={{ fontSize: 12, padding: "6px 10px", width: "auto" }}
                  value={newSiteKey}
                  onChange={e => setNewSiteKey(e.target.value)}
                >
                  {AVAILABLE_SITES.map(s => {
                    const isConfigured = !!pricingPolicy.sites && Object.keys(pricingPolicy.sites).includes(s.key);
                    return (
                      <option key={s.key} value={s.key}>
                        {s.label} ({s.key}) {isConfigured ? "✓ Configured" : ""}
                      </option>
                    );
                  })}
                  <option value="custom">+ Custom Site...</option>
                </select>

                {newSiteKey === "custom" && (
                  <input
                    type="text"
                    className="input"
                    style={{ fontSize: 12, padding: "6px 10px", width: 140 }}
                    placeholder="site_slug (e.g. ebay)"
                    value={customSiteInput}
                    onChange={e => setCustomSiteInput(e.target.value)}
                  />
                )}

                <button
                  type="button"
                  className="btn btn-secondary btn-sm"
                  style={{ display: "flex", alignItems: "center", gap: 4 }}
                  onClick={handleAddSite}
                >
                  <Plus size={14} /> Add Site
                </button>
              </div>
            </div>

            {(!pricingPolicy.sites || Object.keys(pricingPolicy.sites).length === 0) ? (
              <div style={{ padding: "24px 16px", textAlign: "center", border: "1px dashed var(--border)", borderRadius: 10, color: "var(--text-muted)", fontSize: 13 }}>
                No site-specific policies configured yet. All sites currently use the global fallback above.
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
                {Object.keys(pricingPolicy.sites).map(siteKey => {
                  const sitePolicy = pricingPolicy.sites?.[siteKey] || {};
                  const siteInfo = AVAILABLE_SITES.find(s => s.key === siteKey);
                  const siteName = siteInfo ? siteInfo.label : siteKey.toUpperCase();

                  return (
                    <div
                      key={siteKey}
                      style={{
                        background: "var(--bg-subtle, rgba(0,0,0,0.02))",
                        border: "1px solid var(--border)",
                        borderRadius: 10,
                        padding: 16,
                      }}
                    >
                      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                          <span style={{ fontWeight: 700, fontSize: 14 }}>{siteName}</span>
                          <span className="badge" style={{ fontSize: 11, background: "rgba(0,0,0,0.06)", padding: "2px 6px", borderRadius: 4 }}>
                            {siteKey}
                          </span>
                        </div>
                        <button
                          type="button"
                          className="btn btn-danger btn-sm"
                          style={{ display: "flex", alignItems: "center", gap: 4, padding: "4px 8px", fontSize: 12 }}
                          onClick={() => handleRemoveSite(siteKey)}
                        >
                          <Trash2 size={12} /> Remove (Use Fallback)
                        </button>
                      </div>

                      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16 }}>
                        {/* Site Shipping */}
                        <div style={{ background: "var(--bg-card)", borderRadius: 8, padding: 12, border: "1px solid var(--border)" }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 8 }}>
                            <Truck size={13} style={{ color: "var(--primary)" }} />
                            <span style={{ fontWeight: 600, fontSize: 12 }}>Shipping Fee</span>
                          </div>
                          <div className="form-group" style={{ marginBottom: 6 }}>
                            <label className="form-label" style={{ fontSize: 11 }}>Mode</label>
                            <select
                              className="input"
                              style={{ fontSize: 12, padding: "5px 8px" }}
                              value={sitePolicy.shipping_mode || "fixed"}
                              onChange={e => updateSitePolicy(siteKey, { shipping_mode: e.target.value as "fixed" | "formula" })}
                            >
                              <option value="fixed">Fixed Amount</option>
                              <option value="formula">Formula (Price × factor)</option>
                            </select>
                          </div>
                          <div className="form-group" style={{ marginBottom: 6 }}>
                            <label className="form-label" style={{ fontSize: 11 }}>
                              {sitePolicy.shipping_mode === "formula" ? "Multiplier" : "Amount"}
                            </label>
                            <input
                              type="number"
                              step="0.01"
                              min="0"
                              className="input"
                              style={{ fontSize: 12, padding: "5px 8px" }}
                              value={sitePolicy.shipping_value ?? 0}
                              onChange={e => updateSitePolicy(siteKey, { shipping_value: parseFloat(e.target.value) || 0 })}
                              placeholder="0"
                            />
                          </div>
                        </div>

                        {/* Site Commission */}
                        <div style={{ background: "var(--bg-card)", borderRadius: 8, padding: 12, border: "1px solid var(--border)" }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 8 }}>
                            <Percent size={13} style={{ color: "var(--primary)" }} />
                            <span style={{ fontWeight: 600, fontSize: 12 }}>Commission Fee</span>
                          </div>
                          <div className="form-group" style={{ marginBottom: 6 }}>
                            <label className="form-label" style={{ fontSize: 11 }}>Mode</label>
                            <select
                              className="input"
                              style={{ fontSize: 12, padding: "5px 8px" }}
                              value={sitePolicy.commission_mode || "fixed"}
                              onChange={e => updateSitePolicy(siteKey, { commission_mode: e.target.value as "fixed" | "formula" })}
                            >
                              <option value="fixed">Fixed Amount</option>
                              <option value="formula">Formula (Price × factor)</option>
                            </select>
                          </div>
                          <div className="form-group" style={{ marginBottom: 6 }}>
                            <label className="form-label" style={{ fontSize: 11 }}>
                              {sitePolicy.commission_mode === "formula" ? "Multiplier" : "Amount"}
                            </label>
                            <input
                              type="number"
                              step="0.01"
                              min="0"
                              className="input"
                              style={{ fontSize: 12, padding: "5px 8px" }}
                              value={sitePolicy.commission_value ?? 0}
                              onChange={e => updateSitePolicy(siteKey, { commission_value: parseFloat(e.target.value) || 0 })}
                              placeholder="0"
                            />
                          </div>
                        </div>

                        {/* Site Tax */}
                        <div style={{ background: "var(--bg-card)", borderRadius: 8, padding: 12, border: "1px solid var(--border)" }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 8 }}>
                            <Receipt size={13} style={{ color: "var(--primary)" }} />
                            <span style={{ fontWeight: 600, fontSize: 12 }}>Tax Rate (Percentage)</span>
                          </div>
                          <div className="form-group" style={{ marginBottom: 6 }}>
                            <label className="form-label" style={{ fontSize: 11 }}>Tax (%)</label>
                            <input
                              type="number"
                              step="0.1"
                              min="0"
                              max="100"
                              className="input"
                              style={{ fontSize: 12, padding: "5px 8px" }}
                              value={sitePolicy.tax_percentage ?? 0}
                              onChange={e => updateSitePolicy(siteKey, { tax_percentage: parseFloat(e.target.value) || 0 })}
                              placeholder="0"
                            />
                          </div>
                          <p style={{ fontSize: 11, color: "var(--text-muted)", margin: "4px 0 0" }}>
                            Overrides global tax ({pricingPolicy.tax_percentage ?? 0}%) for {siteName}.
                          </p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
