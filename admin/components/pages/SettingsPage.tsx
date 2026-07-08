"use client";

import { useEffect, useState, useCallback } from "react";
import { Save, RefreshCw, AlertCircle } from "lucide-react";
import { adminApi } from "@/lib/api";
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

  // Policies form state
  const [shippingConfirmation, setShippingConfirmation] = useState<PolicyState>({ value_en: "", value_ar: "" });
  const [inspectionPolicy, setInspectionPolicy] = useState<PolicyState>({ value_en: "", value_ar: "" });
  const [pickupDelivery, setPickupDelivery] = useState<PolicyState>({ value_en: "", value_ar: "" });

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
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to load settings");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSettings();
  }, [loadSettings]);

  const handleSave = async (key: string, data: PolicyState) => {
    setSaving(key);
    setError("");
    setSuccess("");
    try {
      await adminApi.updateAppSetting(key, data);
      setSuccess("Settings updated successfully!");
      // Auto clear success message after 3 seconds
      setTimeout(() => setSuccess(""), 3000);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to update settings");
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
          <h1 className="page-title">App Settings & Policies</h1>
          <p className="page-subtitle" style={{ color: "var(--text-muted)", fontSize: 13, marginTop: 4 }}>
            Customize policies and informational content displayed in the mobile app.
          </p>
        </div>
        <button className="btn btn-secondary btn-sm" onClick={loadSettings}>
          <RefreshCw size={14} style={{ marginRight: 6 }} />
          Reload
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
        {/* Shipping & Confirmation Policy */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700 }}>Shipping & Confirmation Policy</h3>
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
                  Save Section
                </>
              )}
            </button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <div className="form-group">
              <label className="form-label">Policy Text (English)</label>
              <textarea
                className="input"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={shippingConfirmation.value_en}
                onChange={e => setShippingConfirmation(f => ({ ...f, value_en: e.target.value }))}
                placeholder="Markdown supported..."
              />
            </div>
            <div className="form-group">
              <label className="form-label">Policy Text (Arabic)</label>
              <textarea
                className="input"
                dir="rtl"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={shippingConfirmation.value_ar}
                onChange={e => setShippingConfirmation(f => ({ ...f, value_ar: e.target.value }))}
                placeholder="دعم لغة المارك داون..."
              />
            </div>
          </div>
        </div>

        {/* Inspection Policy */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700 }}>Inspection Policy</h3>
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
                  Save Section
                </>
              )}
            </button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <div className="form-group">
              <label className="form-label">Policy Text (English)</label>
              <textarea
                className="input"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={inspectionPolicy.value_en}
                onChange={e => setInspectionPolicy(f => ({ ...f, value_en: e.target.value }))}
                placeholder="Markdown supported..."
              />
            </div>
            <div className="form-group">
              <label className="form-label">Policy Text (Arabic)</label>
              <textarea
                className="input"
                dir="rtl"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={inspectionPolicy.value_ar}
                onChange={e => setInspectionPolicy(f => ({ ...f, value_ar: e.target.value }))}
                placeholder="دعم لغة المارك داون..."
              />
            </div>
          </div>
        </div>

        {/* Pickup & Delivery Policy */}
        <div className="card" style={{ padding: 20, background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 12 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700 }}>Pickup & Delivery Policy</h3>
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
                  Save Section
                </>
              )}
            </button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <div className="form-group">
              <label className="form-label">Policy Text (English)</label>
              <textarea
                className="input"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={pickupDelivery.value_en}
                onChange={e => setPickupDelivery(f => ({ ...f, value_en: e.target.value }))}
                placeholder="Markdown supported..."
              />
            </div>
            <div className="form-group">
              <label className="form-label">Policy Text (Arabic)</label>
              <textarea
                className="input"
                dir="rtl"
                style={{ minHeight: 120, fontFamily: "inherit", padding: 10, fontSize: 13 }}
                value={pickupDelivery.value_ar}
                onChange={e => setPickupDelivery(f => ({ ...f, value_ar: e.target.value }))}
                placeholder="دعم لغة المارك داون..."
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
