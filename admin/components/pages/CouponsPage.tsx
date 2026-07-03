"use client";

import { useEffect, useState, useCallback } from "react";
import { Plus, Pencil, Trash2, RefreshCw, Tag, Calendar, ShoppingBag } from "lucide-react";
import { adminApi, Coupon, CreateCouponPayload } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const EMPTY_COUPON_FORM: CreateCouponPayload = {
  code: "",
  description_en: "",
  description_ar: "",
  discount_type: "percentage",
  discount_value: 0,
  min_order_amount: 0,
  max_discount: undefined,
  usage_limit: undefined,
  is_active: true,
  expires_at: "",
  applicability: "all",
};

export default function CouponsPage() {
  const { t, lang } = useLang();
  const [coupons, setCoupons] = useState<Coupon[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Modal State
  const [showModal, setShowModal] = useState(false);
  const [editCoupon, setEditCoupon] = useState<Coupon | null>(null);
  const [form, setForm] = useState<CreateCouponPayload>({ ...EMPTY_COUPON_FORM });
  const [saving, setSaving] = useState(false);

  const LIMIT = 12;

  const loadCoupons = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await adminApi.listCoupons({ page, limit: LIMIT });
      setCoupons(res.coupons);
      setTotal(res.total);
    } catch (err: any) {
      setError(err.message || t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [page, t]);

  useEffect(() => {
    loadCoupons();
  }, [loadCoupons]);

  const openCreate = () => {
    setEditCoupon(null);
    setForm({ ...EMPTY_COUPON_FORM });
    setError(null);
    setShowModal(true);
  };

  const openEdit = (coupon: Coupon) => {
    setEditCoupon(coupon);
    
    // Format expiration date for input type datetime-local (YYYY-MM-DDThh:mm)
    let formattedDate = "";
    if (coupon.expires_at) {
      const date = new Date(coupon.expires_at);
      // Adjust to local ISO string
      const offset = date.getTimezoneOffset();
      const localDate = new Date(date.getTime() - offset * 60 * 1000);
      formattedDate = localDate.toISOString().slice(0, 16);
    }

    setForm({
      code: coupon.code,
      description_en: coupon.description_en || "",
      description_ar: coupon.description_ar || "",
      discount_type: coupon.discount_type,
      discount_value: coupon.discount_value,
      min_order_amount: coupon.min_order_amount,
      max_discount: coupon.max_discount || undefined,
      usage_limit: coupon.usage_limit || undefined,
      is_active: coupon.is_active,
      expires_at: formattedDate,
      applicability: coupon.applicability,
    });
    setError(null);
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.code.trim() || form.discount_value <= 0) {
      alert("Please check required fields (Code and Discount Value must be valid)");
      return;
    }

    setSaving(true);
    setError(null);
    try {
      // Build ISO string for UTC from local input time
      let expiryIso: string | undefined = undefined;
      if (form.expires_at) {
        expiryIso = new Date(form.expires_at).toISOString();
      }

      const payload: CreateCouponPayload = {
        ...form,
        code: form.code.toUpperCase().trim(),
        discount_value: Number(form.discount_value),
        min_order_amount: Number(form.min_order_amount || 0),
        max_discount: form.max_discount ? Number(form.max_discount) : undefined,
        usage_limit: form.usage_limit ? Number(form.usage_limit) : undefined,
        expires_at: expiryIso,
      };

      if (editCoupon) {
        await adminApi.updateCoupon(editCoupon.id, payload);
      } else {
        await adminApi.createCoupon(payload);
      }

      setShowModal(false);
      loadCoupons();
    } catch (err: any) {
      setError(err.message || t("failedToUpdate"));
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm(t("deleteCouponConfirm"))) return;
    try {
      await adminApi.deleteCoupon(id);
      loadCoupons();
    } catch (err: any) {
      alert(err.message || "Failed to delete coupon");
    }
  };

  const totalPages = Math.ceil(total / LIMIT);

  return (
    <div>
      {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

      {/* Header */}
      <div className="section-header" style={{ justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <h1 className="section-title" style={{ margin: 0 }}>{t("coupons")}</h1>
          <button className="btn btn-ghost btn-icon btn-sm" onClick={loadCoupons} title={t("refresh")}>
            <RefreshCw size={14} />
          </button>
        </div>
        <button id="add-coupon-btn" className="btn btn-primary" onClick={openCreate}>
          <Plus size={16} />
          <span>{t("addCoupon")}</span>
        </button>
      </div>

      {loading ? (
        <div style={{ padding: 60, display: "flex", justifyContent: "center" }}>
          <div className="spinner" style={{ width: 36, height: 36, borderWidth: 3 }} />
        </div>
      ) : coupons.length === 0 ? (
        <div style={{ textAlign: "center", padding: 60, color: "var(--text-muted)" }}>
          <Tag size={48} style={{ marginBottom: 12, opacity: 0.5 }} />
          <h3>{lang === "ar" ? "لا توجد كوبونات" : "No coupons found"}</h3>
          <p style={{ fontSize: 13, marginTop: 4 }}>
            {lang === "ar" ? "اضغط على إضافة كوبون لإنشاء كود خصم جديد للعملاء." : "Click Add Coupon to create a new discount code for your customers."}
          </p>
        </div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>{t("couponCode")}</th>
                <th>{lang === "ar" ? "الوصف" : "Description"}</th>
                <th>{t("discountType")}</th>
                <th>{t("discountValue")}</th>
                <th>{t("applicability")}</th>
                <th>{t("minOrderAmount")}</th>
                <th>{t("usageLimit")}</th>
                <th>{t("expiresAt")}</th>
                <th>{t("status")}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {coupons.map((c) => {
                const isExpired = c.expires_at && new Date(c.expires_at) < new Date();
                const isActive = c.is_active && !isExpired;

                let appLabel = t("allProducts");
                if (c.applicability === "internal") appLabel = t("internalProducts");
                if (c.applicability === "external") appLabel = t("externalProducts");

                let discTypeLabel = c.discount_type === "percentage" ? t("percentage") : t("fixed");

                return (
                  <tr key={c.id}>
                    <td>
                      <span style={{
                        fontFamily: "monospace",
                        fontSize: 13,
                        fontWeight: 700,
                        background: "rgba(124, 90, 240, 0.1)",
                        color: "var(--accent-light)",
                        padding: "4px 8px",
                        borderRadius: 6,
                        border: "1px solid rgba(124, 90, 240, 0.2)"
                      }}>
                        {c.code}
                      </span>
                    </td>
                    <td>
                      <div style={{ fontSize: 13, fontWeight: 500 }}>
                        {lang === "ar" ? (c.description_ar || c.description_en || "—") : (c.description_en || c.description_ar || "—")}
                      </div>
                    </td>
                    <td style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                      {discTypeLabel}
                    </td>
                    <td style={{ fontWeight: 600 }}>
                      {c.discount_type === "percentage" ? `${c.discount_value}%` : `﷼ ${c.discount_value.toFixed(2)}`}
                    </td>
                    <td>
                      <span className="badge badge-secondary" style={{ background: "var(--bg-secondary)", border: "1px solid var(--border)", fontSize: 11 }}>
                        {appLabel}
                      </span>
                    </td>
                    <td style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                      ﷼ {c.min_order_amount.toFixed(2)}
                    </td>
                    <td style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                      {c.usage_limit ? `${c.used_count} / ${c.usage_limit}` : `${c.used_count} / ∞`}
                    </td>
                    <td style={{ fontSize: 12, color: "var(--text-secondary)" }}>
                      {c.expires_at ? (
                        <div style={{ display: "flex", alignItems: "center", gap: 4, color: isExpired ? "var(--danger)" : undefined }}>
                          <Calendar size={12} />
                          <span>{new Date(c.expires_at).toLocaleDateString()}</span>
                        </div>
                      ) : (
                        <span style={{ color: "var(--text-muted)" }}>—</span>
                      )}
                    </td>
                    <td>
                      <span className={`badge ${isActive ? "badge-active" : "badge-inactive"}`}>
                        {isExpired ? (lang === "ar" ? "منتهي" : "Expired") : c.is_active ? t("active") : t("inactive")}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: "flex", gap: 6 }}>
                        <button
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => openEdit(c)}
                          title={t("edit")}
                        >
                          <Pencil size={13} />
                        </button>
                        <button
                          className="btn btn-danger btn-icon btn-sm"
                          onClick={() => handleDelete(c.id)}
                          title={t("delete")}
                        >
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="pagination">
          <button className="pagination-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>{t("prev")}</button>
          {Array.from({ length: totalPages }, (_, i) => i + 1).map(p => (
            <button key={p} className={`pagination-btn${page === p ? " active" : ""}`} onClick={() => setPage(p)}>{p}</button>
          ))}
          <button className="pagination-btn" disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}>{t("next")}</button>
        </div>
      )}

      {/* Add / Edit Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowModal(false)}>
          <form onSubmit={handleSubmit} className="modal" style={{ maxWidth: 580 }}>
            <div className="modal-title">{editCoupon ? t("editCoupon") : t("addCoupon")}</div>
            
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              {/* Row 1: Code & Applicability */}
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("couponCode")} *</label>
                  <input
                    type="text"
                    required
                    className="input"
                    placeholder={t("couponPlaceholder")}
                    value={form.code}
                    onChange={e => setForm(f => ({ ...f, code: e.target.value.toUpperCase() }))}
                    disabled={saving}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("applicability")} *</label>
                  <select
                    className="input"
                    value={form.applicability}
                    onChange={e => setForm(f => ({ ...f, applicability: e.target.value as any }))}
                    disabled={saving}
                  >
                    <option value="all">{t("allProducts")}</option>
                    <option value="internal">{t("internalProducts")}</option>
                    <option value="external">{t("externalProducts")}</option>
                  </select>
                </div>
              </div>

              {/* Row 2: Type & Value */}
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("discountType")} *</label>
                  <select
                    className="input"
                    value={form.discount_type}
                    onChange={e => setForm(f => ({ ...f, discount_type: e.target.value as any }))}
                    disabled={saving}
                  >
                    <option value="percentage">{t("percentage")}</option>
                    <option value="fixed">{t("fixed")}</option>
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">
                    {t("discountValue")} * ({form.discount_type === "percentage" ? "%" : "SAR"})
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0.01"
                    required
                    className="input"
                    value={form.discount_value || ""}
                    onChange={e => setForm(f => ({ ...f, discount_value: parseFloat(e.target.value) || 0 }))}
                    disabled={saving}
                    placeholder={form.discount_type === "percentage" ? "20" : "50.00"}
                  />
                </div>
              </div>

              {/* Row 3: Descriptions */}
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{lang === "ar" ? "الوصف (إنجليزي)" : "Description (English)"}</label>
                  <input
                    type="text"
                    className="input"
                    value={form.description_en}
                    onChange={e => setForm(f => ({ ...f, description_en: e.target.value }))}
                    disabled={saving}
                    placeholder="20% Off Your Purchase"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">{lang === "ar" ? "الوصف (عربي)" : "Description (Arabic)"}</label>
                  <input
                    type="text"
                    className="input"
                    value={form.description_ar}
                    onChange={e => setForm(f => ({ ...f, description_ar: e.target.value }))}
                    disabled={saving}
                    placeholder="خصم ٢٠٪ على مشترياتك"
                    dir="rtl"
                  />
                </div>
              </div>

              {/* Row 4: Min Order & Max Discount */}
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("minOrderAmount")} (SAR)</label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="input"
                    value={form.min_order_amount || ""}
                    onChange={e => setForm(f => ({ ...f, min_order_amount: parseFloat(e.target.value) || 0 }))}
                    disabled={saving}
                    placeholder="0.00"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("maxDiscount")} (SAR)</label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="input"
                    value={form.max_discount || ""}
                    onChange={e => setForm(f => ({ ...f, max_discount: parseFloat(e.target.value) || undefined }))}
                    disabled={saving}
                    placeholder={form.discount_type === "percentage" ? "100.00" : "—"}
                  />
                </div>
              </div>

              {/* Row 5: Usage Limit & Expiry Date */}
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("usageLimit")}</label>
                  <input
                    type="number"
                    min="1"
                    className="input"
                    value={form.usage_limit || ""}
                    onChange={e => setForm(f => ({ ...f, usage_limit: parseInt(e.target.value) || undefined }))}
                    disabled={saving}
                    placeholder="∞"
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("expiresAt")}</label>
                  <input
                    type="datetime-local"
                    className="input"
                    value={form.expires_at || ""}
                    onChange={e => setForm(f => ({ ...f, expires_at: e.target.value }))}
                    disabled={saving}
                  />
                </div>
              </div>

              {/* Toggle switch for is_active */}
              <div className="form-group" style={{ flexDirection: "row", alignItems: "center", gap: 10, cursor: "pointer", padding: "4px 0" }}>
                <input
                  type="checkbox"
                  id="coupon-active"
                  checked={form.is_active}
                  onChange={e => setForm(f => ({ ...f, is_active: e.target.checked }))}
                  disabled={saving}
                  style={{ width: 18, height: 18, cursor: "pointer" }}
                />
                <label htmlFor="coupon-active" style={{ cursor: "pointer", fontSize: 13, fontWeight: 600, color: "var(--text-primary)" }}>
                  {t("active")}
                </label>
              </div>
            </div>

            <div className="modal-footer">
              <button
                type="button"
                className="btn btn-ghost"
                onClick={() => setShowModal(false)}
                disabled={saving}
              >
                {t("cancel")}
              </button>
              <button
                type="submit"
                className="btn btn-primary"
                disabled={saving}
              >
                {saving ? <div className="spinner" /> : editCoupon ? t("saveChanges") : t("add")}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
