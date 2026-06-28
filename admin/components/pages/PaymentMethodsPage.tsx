"use client";

import { useEffect, useState, useCallback } from "react";
import { Plus, Pencil, Trash2, CheckCircle, XCircle, RefreshCw, Layers } from "lucide-react";
import { adminApi, PaymentMethod } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

interface DynamicField {
  key: string;
  label_en: string;
  label_ar: string;
  type: "text" | "number" | "select" | "file";
  options?: string[];
}

export default function PaymentMethodsPage() {
  const { t } = useLang();
  const [methods, setMethods] = useState<PaymentMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Modal / Form state
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedMethod, setSelectedMethod] = useState<PaymentMethod | null>(null);
  const [titleEn, setTitleEn] = useState("");
  const [titleAr, setTitleAr] = useState("");
  const [detailsEn, setDetailsEn] = useState("");
  const [detailsAr, setDetailsAr] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [isActive, setIsActive] = useState(true);
  
  // Dynamic fields list state
  const [dynamicFields, setDynamicFields] = useState<DynamicField[]>([]);
  const [newFieldKey, setNewFieldKey] = useState("");
  const [newFieldLabelEn, setNewFieldLabelEn] = useState("");
  const [newFieldLabelAr, setNewFieldLabelAr] = useState("");
  const [newFieldType, setNewFieldType] = useState<"text" | "number" | "select" | "file">("text");
  const [newFieldOptions, setNewFieldOptions] = useState("");
  
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await adminApi.listPaymentMethods();
      setMethods(res);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    load();
  }, [load]);

  const openAddModal = () => {
    setSelectedMethod(null);
    setTitleEn("");
    setTitleAr("");
    setDetailsEn("");
    setDetailsAr("");
    setImageUrl("");
    setIsActive(true);
    setDynamicFields([]);
    setNewFieldType("text");
    setModalOpen(true);
  };

  const openEditModal = (method: PaymentMethod) => {
    setSelectedMethod(method);
    setTitleEn(method.title_en);
    setTitleAr(method.title_ar);
    setDetailsEn(method.details_en || "");
    setDetailsAr(method.details_ar || "");
    setImageUrl(method.image_url || "");
    setIsActive(method.is_active);
    
    // Parse raw fields
    const raw = method.raw_fields || [];
    setDynamicFields(
      raw.map((f: any) => ({
        key: f.key || "",
        label_en: f.label_en || f.label || "",
        label_ar: f.label_ar || f.label || "",
        type: f.type || "text",
      }))
    );
    setNewFieldType("text");
    
    setModalOpen(true);
  };

  const handleAddField = () => {
    if (!newFieldKey.trim()) {
      alert("Field key is required");
      return;
    }
    const keyPattern = /^[a-zA-Z0-9_]+$/;
    if (!keyPattern.test(newFieldKey)) {
      alert("Field key can only contain letters, numbers, and underscores");
      return;
    }
    if (dynamicFields.some(f => f.key === newFieldKey)) {
      alert("A field with this key already exists");
      return;
    }

    let optionsList: string[] | undefined = undefined;
    if (newFieldType === "select") {
      optionsList = newFieldOptions
        .split(",")
        .map(o => o.trim())
        .filter(o => o.length > 0);
      if (!optionsList || optionsList.length === 0) {
        alert("Please enter options for the select field");
        return;
      }
    }

    setDynamicFields([
      ...dynamicFields,
      {
        key: newFieldKey.trim(),
        label_en: newFieldLabelEn.trim() || newFieldKey,
        label_ar: newFieldLabelAr.trim() || newFieldKey,
        type: newFieldType,
        options: optionsList,
      },
    ]);

    setNewFieldKey("");
    setNewFieldLabelEn("");
    setNewFieldLabelAr("");
    setNewFieldType("text");
    setNewFieldOptions("");
  };

  const handleRemoveField = (index: number) => {
    setDynamicFields(dynamicFields.filter((_, i) => i !== index));
  };

  const handleToggleActive = async (method: PaymentMethod) => {
    try {
      await adminApi.updatePaymentMethod(method.id, {
        title_en: method.title_en,
        title_ar: method.title_ar,
        details_en: method.details_en,
        details_ar: method.details_ar,
        image_url: method.image_url,
        is_active: !method.is_active,
      });
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm(t("deletePaymentMethodConfirm"))) return;
    try {
      await adminApi.deletePaymentMethod(id);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToDelete"));
    }
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const res = await adminApi.uploadImage(file);
      setImageUrl(res.image_url);
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : "Image upload failed");
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!titleEn.trim() || !titleAr.trim()) {
      alert("Title is required in both English and Arabic");
      return;
    }

    setSaving(true);
    const payload = {
      title_en: titleEn.trim(),
      title_ar: titleAr.trim(),
      details_en: detailsEn.trim() || null,
      details_ar: detailsAr.trim() || null,
      image_url: imageUrl.trim() || null,
      is_active: isActive,
      fields: dynamicFields,
    };

    try {
      if (selectedMethod) {
        await adminApi.updatePaymentMethod(selectedMethod.id, payload);
      } else {
        await adminApi.createPaymentMethod(payload);
      }
      setModalOpen(false);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

      {/* Header */}
      <div className="section-header">
        <div>
          <button className="btn btn-primary" onClick={openAddModal}>
            <Plus size={16} />
            {t("addPaymentMethod")}
          </button>
        </div>
        <button className="btn btn-ghost btn-icon" onClick={load} title={t("refresh")}>
          <RefreshCw size={16} />
        </button>
      </div>

      {/* Table */}
      <div className="table-container">
        {loading ? (
          <div style={{ padding: 60, display: "flex", justifyContent: "center" }}>
            <div className="spinner" style={{ width: 36, height: 36, borderWidth: 3 }} />
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>{t("paymentMethods")}</th>
                <th>{t("detailsEn")}</th>
                <th>{t("detailsAr")}</th>
                <th>{t("status")}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {methods.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
                    {t("noPaymentMethodsYet")}
                  </td>
                </tr>
              ) : (
                methods.map(method => (
                  <tr key={method.id}>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                        {method.image_url ? (
                          <img
                            src={method.image_url.startsWith("/static/") ? `http://localhost:8000${method.image_url}` : method.image_url}
                            alt={method.title_en}
                            style={{ width: 44, height: 44, objectFit: "contain", borderRadius: 8, border: "1px solid var(--border)", padding: 4, background: "#fff" }}
                          />
                        ) : (
                          <div className="avatar" style={{ width: 44, height: 44, borderRadius: 8 }}>
                            <Layers size={18} />
                          </div>
                        )}
                        <div>
                          <div style={{ fontWeight: 600, color: "var(--text-primary)" }}>{method.title_en}</div>
                          <div style={{ fontSize: 13, color: "var(--text-muted)", fontWeight: 500 }}>{method.title_ar}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ maxWidth: 200, fontSize: 13, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {method.details_en || "—"}
                    </td>
                    <td style={{ maxWidth: 200, fontSize: 13, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {method.details_ar || "—"}
                    </td>
                    <td>
                      <span className={`badge ${method.is_active ? "badge-active" : "badge-inactive"}`}>
                        {method.is_active ? t("active") : t("inactive")}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: "flex", gap: 6 }}>
                        <button
                          id={`edit-method-${method.id}`}
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => openEditModal(method)}
                          title={t("edit")}
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          id={`toggle-method-${method.id}`}
                          className={`btn btn-icon btn-sm ${method.is_active ? "btn-danger" : "btn-ghost"}`}
                          onClick={() => handleToggleActive(method)}
                          title={method.is_active ? t("deactivate") : t("activate")}
                        >
                          {method.is_active ? <XCircle size={14} /> : <CheckCircle size={14} />}
                        </button>
                        <button
                          id={`delete-method-${method.id}`}
                          className="btn btn-danger btn-icon btn-sm"
                          onClick={() => handleDelete(method.id)}
                          title={t("delete")}
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* Add / Edit modal */}
      {modalOpen && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setModalOpen(false)}>
          <div className="modal" style={{ maxWidth: 650, width: "95%" }}>
            <div className="modal-title">
              {selectedMethod ? t("editPaymentMethodTitle") : t("addNewPaymentMethodTitle")}
            </div>
            <form onSubmit={handleSubmit}>
              <div style={{ display: "flex", flexDirection: "column", gap: 16, maxHeight: "70vh", overflowY: "auto", paddingRight: 8 }}>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                  <div className="form-group">
                    <label className="form-label">{t("titleEn")}</label>
                    <input
                      id="method-title-en"
                      className="input"
                      value={titleEn}
                      onChange={e => setTitleEn(e.target.value)}
                      required
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">{t("titleAr")}</label>
                    <input
                      id="method-title-ar"
                      className="input"
                      value={titleAr}
                      onChange={e => setTitleAr(e.target.value)}
                      required
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">{t("detailsEn")}</label>
                  <textarea
                    id="method-details-en"
                    className="input"
                    rows={2}
                    value={detailsEn}
                    onChange={e => setDetailsEn(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">{t("detailsAr")}</label>
                  <textarea
                    id="method-details-ar"
                    className="input"
                    rows={2}
                    value={detailsAr}
                    onChange={e => setDetailsAr(e.target.value)}
                  />
                </div>

                <div style={{ display: "grid", gridTemplateColumns: "1fr auto", gap: 12, alignItems: "end" }}>
                  <div className="form-group">
                    <label className="form-label">{t("imageUrlLabel")}</label>
                    <input
                      id="method-image-url"
                      className="input"
                      value={imageUrl}
                      onChange={e => setImageUrl(e.target.value)}
                      placeholder="/static/uploads/images/logo.png"
                    />
                  </div>
                  <div className="form-group">
                    <label className="btn btn-ghost" style={{ cursor: "pointer", margin: 0, padding: "8px 12px", border: "1px solid var(--border)", display: "inline-flex", alignItems: "center" }}>
                      Upload
                      <input
                        type="file"
                        accept="image/*"
                        style={{ display: "none" }}
                        onChange={handleImageUpload}
                      />
                    </label>
                  </div>
                </div>

                {/* Fields Builder */}
                <div style={{ border: "1px solid var(--border)", borderRadius: 8, padding: 12, background: "var(--bg-card)" }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: "var(--text-primary)", marginBottom: 10 }}>
                    Custom Checkout Form Fields
                  </div>

                  {/* Field entry inputs */}
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr auto", gap: 8, marginBottom: 12, alignItems: "end" }}>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>Field Key (slug)</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldKey}
                        onChange={e => setNewFieldKey(e.target.value)}
                        placeholder="bank_name"
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>Label (EN)</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldLabelEn}
                        onChange={e => setNewFieldLabelEn(e.target.value)}
                        placeholder="Bank Name"
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>Label (AR)</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldLabelAr}
                        onChange={e => setNewFieldLabelAr(e.target.value)}
                        placeholder="اسم البنك"
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>Type</label>
                      <select
                        className="input"
                        style={{ height: 32, fontSize: 12, padding: "0 4px" }}
                        value={newFieldType}
                        onChange={e => setNewFieldType(e.target.value as "text" | "number" | "select" | "file")}
                      >
                        <option value="text">Text</option>
                        <option value="number">Number</option>
                        <option value="select">Select</option>
                        <option value="file">File</option>
                      </select>
                    </div>
                    <button type="button" className="btn btn-primary" style={{ height: 32, padding: "0 12px", fontSize: 12 }} onClick={handleAddField}>
                      Add
                    </button>
                  </div>

                  {newFieldType === "select" && (
                    <div className="form-group" style={{ marginBottom: 12 }}>
                      <label className="form-label" style={{ fontSize: 11 }}>Select Options (Comma-separated)</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldOptions}
                        onChange={e => setNewFieldOptions(e.target.value)}
                        placeholder="Option 1, Option 2, Option 3"
                      />
                    </div>
                  )}

                  {/* Fields list */}
                  <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                    {dynamicFields.length === 0 ? (
                      <div style={{ fontSize: 11, color: "var(--text-muted)", fontStyle: "italic" }}>
                        No fields required. Users will place orders directly.
                      </div>
                    ) : (
                      dynamicFields.map((field, index) => (
                        <div key={index} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "6px 10px", background: "var(--bg-body)", borderRadius: 6, border: "1px solid var(--border)", fontSize: 12 }}>
                          <div>
                            <span style={{ fontWeight: 600, color: "var(--text-primary)" }}>{field.key}</span>
                            <span style={{ margin: "0 6px", color: "var(--text-muted)" }}>({field.type || "text"})</span>
                            <span style={{ margin: "0 6px", color: "var(--text-muted)" }}>|</span>
                            <span>{field.label_en} / {field.label_ar}</span>
                            {field.options && field.options.length > 0 && (
                              <span style={{ fontSize: 11, color: "var(--text-muted)", marginLeft: 6 }}>
                                Options: {field.options.join(", ")}
                              </span>
                            )}
                          </div>
                          <button type="button" className="btn btn-danger btn-icon btn-sm" style={{ width: 22, height: 22, minWidth: 22 }} onClick={() => handleRemoveField(index)}>
                            <Trash2 size={11} />
                          </button>
                        </div>
                      ))
                    )}
                  </div>
                </div>

                <div className="form-group flex-row" style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <input
                    type="checkbox"
                    id="method-active"
                    checked={isActive}
                    onChange={e => setIsActive(e.target.checked)}
                  />
                  <label htmlFor="method-active" className="form-label" style={{ margin: 0, cursor: "pointer" }}>
                    Active and available for checkout
                  </label>
                </div>
              </div>

              <div className="modal-footer" style={{ marginTop: 20 }}>
                <button type="button" className="btn btn-ghost" onClick={() => setModalOpen(false)}>
                  {t("cancel")}
                </button>
                <button type="submit" id="save-method" className="btn btn-primary" disabled={saving}>
                  {saving ? <div className="spinner" /> : t("saveChanges")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
