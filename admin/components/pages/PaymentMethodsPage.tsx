"use client";

import { useEffect, useState, useCallback } from "react";
import { Plus, Pencil, Trash2, CheckCircle, XCircle, RefreshCw, Layers, Building2, Copy, Image as ImageIcon } from "lucide-react";
import { adminApi, PaymentMethod, BankAccount } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

interface DynamicField {
  key: string;
  label_en: string;
  label_ar: string;
  type: "text" | "number" | "select" | "file";
  options?: string[];
}

export default function PaymentMethodsPage() {
  const { t, lang } = useLang();
  const [methods, setMethods] = useState<PaymentMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Modal / Form state
  const [modalOpen, setModalOpen] = useState(false);
  const [selectedMethod, setSelectedMethod] = useState<PaymentMethod | null>(null);
  const [titleEn, setTitleEn] = useState("");
  const [titleAr, setTitleAr] = useState("");
  const [descriptionEn, setDescriptionEn] = useState("");
  const [descriptionAr, setDescriptionAr] = useState("");
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

  // Bank accounts list state
  const [bankAccounts, setBankAccounts] = useState<BankAccount[]>([]);
  const [newBankNameAr, setNewBankNameAr] = useState("");
  const [newBankNameEn, setNewBankNameEn] = useState("");
  const [newAccountNum, setNewAccountNum] = useState("");
  const [newBankLogo, setNewBankLogo] = useState("");
  
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
    setDescriptionEn("");
    setDescriptionAr("");
    setDetailsEn("");
    setDetailsAr("");
    setImageUrl("");
    setIsActive(true);
    setDynamicFields([]);
    setNewFieldType("text");
    setBankAccounts([]);
    setNewBankNameAr("");
    setNewBankNameEn("");
    setNewAccountNum("");
    setNewBankLogo("");
    setModalOpen(true);
  };

  const openEditModal = (method: PaymentMethod) => {
    setSelectedMethod(method);
    setTitleEn(method.title_en);
    setTitleAr(method.title_ar);
    setDescriptionEn(method.description_en || "");
    setDescriptionAr(method.description_ar || "");
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
        options: f.options || undefined,
      }))
    );
    setNewFieldType("text");

    // Parse bank accounts
    const rawAccounts = method.raw_bank_accounts || method.bank_accounts || [];
    setBankAccounts(
      rawAccounts.map((a: any) => ({
        id: a.id || `acc-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
        bank_name_ar: a.bank_name_ar || a.bank_name || "",
        bank_name_en: a.bank_name_en || a.bank_name || "",
        account_number: a.account_number || "",
        account_name: a.account_name || "",
        iban: a.iban || "",
        logo_url: a.logo_url || "",
      }))
    );
    setNewBankNameAr("");
    setNewBankNameEn("");
    setNewAccountNum("");
    setNewBankLogo("");
    
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

  const handleAddBankAccount = () => {
    if (!newBankNameAr.trim() || !newAccountNum.trim()) {
      alert("Bank name (AR) and Account number are required");
      return;
    }

    setBankAccounts([
      ...bankAccounts,
      {
        id: `acc-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
        bank_name_ar: newBankNameAr.trim(),
        bank_name_en: newBankNameEn.trim() || newBankNameAr.trim(),
        account_number: newAccountNum.trim(),
        logo_url: newBankLogo.trim() || "",
      },
    ]);

    setNewBankNameAr("");
    setNewBankNameEn("");
    setNewAccountNum("");
    setNewBankLogo("");
  };

  const handleRemoveBankAccount = (index: number) => {
    setBankAccounts(bankAccounts.filter((_, i) => i !== index));
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

  const handleBankLogoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const res = await adminApi.uploadImage(file);
      setNewBankLogo(res.image_url);
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : "Logo upload failed");
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
      title_en: titleEn,
      title_ar: titleAr,
      description_en: descriptionEn || null,
      description_ar: descriptionAr || null,
      details_en: detailsEn || null,
      details_ar: detailsAr || null,
      image_url: imageUrl || null,
      is_active: isActive,
      fields: dynamicFields,
      bank_accounts: bankAccounts,
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
                <th>{t("bankAccounts")}</th>
                <th>{t("checkoutFields")}</th>
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
                methods.map(method => {
                  const accounts = method.raw_bank_accounts || method.bank_accounts || [];
                  const fields = method.raw_fields || method.fields || [];
                  return (
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
                      <td>
                        {accounts.length > 0 ? (
                          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
                            <span className="badge badge-primary" style={{ display: "inline-flex", alignItems: "center", gap: 4, width: "fit-content" }}>
                              <Building2 size={12} />
                              {accounts.length} {accounts.length === 1 ? t("bankAccount") : t("bankAccounts")}
                            </span>
                            <div style={{ fontSize: 11, color: "var(--text-muted)", maxWidth: 220, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                              {accounts.map((a: any) => lang === "ar" ? (a.bank_name_ar || a.bank_name_en) : (a.bank_name_en || a.bank_name_ar)).join(", ")}
                            </div>
                          </div>
                        ) : (
                          <span style={{ color: "var(--text-muted)", fontSize: 12 }}>—</span>
                        )}
                      </td>
                      <td>
                        {fields.length > 0 ? (
                          <span className="badge badge-secondary">
                            {fields.length} {fields.length === 1 ? t("customField") : t("customFields")}
                          </span>
                        ) : (
                          <span style={{ color: "var(--text-muted)", fontSize: 12 }}>{t("none")}</span>
                        )}
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
                  );
                })
              )}
            </tbody>
          </table>
        )}
      </div>

      {/* Add / Edit modal */}
      {modalOpen && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setModalOpen(false)}>
          <div className="modal" style={{ maxWidth: 720, width: "95%" }}>
            <div className="modal-title">
              {selectedMethod ? t("editPaymentMethodTitle") : t("addNewPaymentMethodTitle")}
            </div>
            <form onSubmit={handleSubmit}>
              <div style={{ display: "flex", flexDirection: "column", gap: 16, maxHeight: "75vh", overflowY: "auto", paddingRight: 8 }}>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                  <div className="form-group">
                    <label className="form-label">{t("titleEn")}</label>
                    <input
                      id="method-title-en"
                      className="input"
                      value={titleEn}
                      onChange={e => setTitleEn(e.target.value)}
                      placeholder="e.g. Bank Transfer 💳"
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
                      placeholder="مثال: حوالة بنكية 💳"
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

                {/* ── Bank Accounts Section ──────────────────────────────── */}
                <div style={{ border: "1px solid var(--border)", borderRadius: 10, padding: 14, background: "var(--bg-card)" }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 14, fontWeight: 700, color: "var(--text-primary)" }}>
                      <Building2 size={16} />
                      {t("bankAccounts")} ({bankAccounts.length})
                    </div>
                  </div>

                  {/* Add new bank account row */}
                  <div style={{ background: "var(--bg-surface)", padding: 12, borderRadius: 8, border: "1px solid var(--border)", marginBottom: 12 }}>
                    <div style={{ fontSize: 12, fontWeight: 600, marginBottom: 8, color: "var(--text-secondary)" }}>
                      {t("addDepositBankAccount")}
                    </div>
                    <div style={{ display: "grid", gridTemplateColumns: "1.2fr 1.2fr 1.2fr 1fr auto", gap: 8, alignItems: "end" }}>
                      <div className="form-group">
                        <label className="form-label" style={{ fontSize: 11 }}>{t("bankNameAr")}</label>
                        <input
                          className="input"
                          style={{ height: 32, fontSize: 12 }}
                          value={newBankNameAr}
                          onChange={e => setNewBankNameAr(e.target.value)}
                          placeholder={lang === "ar" ? "مثال: بنك القطيبي" : "e.g. Al Qutaibi Bank"}
                        />
                      </div>
                      <div className="form-group">
                        <label className="form-label" style={{ fontSize: 11 }}>{t("bankNameEn")}</label>
                        <input
                          className="input"
                          style={{ height: 32, fontSize: 12 }}
                          value={newBankNameEn}
                          onChange={e => setNewBankNameEn(e.target.value)}
                          placeholder="e.g. Al Qutaibi Bank"
                        />
                      </div>
                      <div className="form-group">
                        <label className="form-label" style={{ fontSize: 11 }}>{t("accountNumber")}</label>
                        <input
                          className="input"
                          style={{ height: 32, fontSize: 12 }}
                          value={newAccountNum}
                          onChange={e => setNewAccountNum(e.target.value)}
                          placeholder="78266666"
                        />
                      </div>
                      <div className="form-group">
                        <label className="form-label" style={{ fontSize: 11 }}>{t("bankLogo")}</label>
                        <div style={{ display: "flex", gap: 4 }}>
                          <input
                            className="input"
                            style={{ height: 32, fontSize: 11 }}
                            value={newBankLogo}
                            onChange={e => setNewBankLogo(e.target.value)}
                            placeholder="/static/seed/banks/qutaibi_bank.png"
                          />
                          <label className="btn btn-ghost btn-sm" style={{ padding: "0 6px", height: 32, cursor: "pointer", display: "flex", alignItems: "center" }} title={t("uploadLogo")}>
                            <ImageIcon size={14} />
                            <input type="file" accept="image/*" style={{ display: "none" }} onChange={handleBankLogoUpload} />
                          </label>
                        </div>
                      </div>
                      <button
                        type="button"
                        className="btn btn-primary btn-sm"
                        style={{ height: 32 }}
                        onClick={handleAddBankAccount}
                      >
                        <Plus size={14} /> {t("add")}
                      </button>
                    </div>
                  </div>

                  {/* List of current bank accounts */}
                  {bankAccounts.length === 0 ? (
                    <div style={{ textAlign: "center", padding: "16px 0", color: "var(--text-muted)", fontSize: 12 }}>
                      {t("none")}
                    </div>
                  ) : (
                    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                      {bankAccounts.map((acc, index) => (
                        <div
                          key={acc.id || index}
                          style={{
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "space-between",
                            padding: "8px 12px",
                            background: "var(--bg-surface)",
                            border: "1px solid var(--border)",
                            borderRadius: 8,
                          }}
                        >
                          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                            {acc.logo_url ? (
                              <img
                                src={acc.logo_url.startsWith("/static/") ? `http://localhost:8000${acc.logo_url}` : acc.logo_url}
                                alt={acc.bank_name_en}
                                style={{ width: 36, height: 36, objectFit: "contain", borderRadius: 6, background: "#fff", padding: 2, border: "1px solid var(--border)" }}
                              />
                            ) : (
                              <div style={{ width: 36, height: 36, borderRadius: 6, background: "var(--bg-secondary)", display: "flex", alignItems: "center", justifyContent: "center" }}>
                                <Building2 size={16} />
                              </div>
                            )}
                            <div>
                              <div style={{ fontWeight: 600, fontSize: 13, color: "var(--text-primary)" }}>
                                {lang === "ar" ? (acc.bank_name_ar || acc.bank_name_en) : (acc.bank_name_en || acc.bank_name_ar)}
                              </div>
                              <div style={{ fontSize: 12, color: "var(--text-secondary)", fontFamily: "monospace" }}>
                                {lang === "ar" ? "رقم الحساب: " : "Account: "}<span style={{ fontWeight: 700 }}>{acc.account_number}</span>
                              </div>
                            </div>
                          </div>
                          <button
                            type="button"
                            className="btn btn-danger btn-icon btn-sm"
                            onClick={() => handleRemoveBankAccount(index)}
                            title={t("delete")}
                          >
                            <Trash2 size={13} />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* ── Custom Checkout Fields Builder ────────────────────── */}
                <div style={{ border: "1px solid var(--border)", borderRadius: 10, padding: 14, background: "var(--bg-card)" }}>
                  <div style={{ fontSize: 13, fontWeight: 700, color: "var(--text-primary)", marginBottom: 10 }}>
                    {t("checkoutFields")} ({dynamicFields.length})
                  </div>

                  {/* Field entry inputs */}
                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr auto", gap: 8, marginBottom: 12, alignItems: "end" }}>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>{t("fieldKey")}</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldKey}
                        onChange={e => setNewFieldKey(e.target.value)}
                        placeholder="receipt_proof"
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>{t("fieldLabelEn")}</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldLabelEn}
                        onChange={e => setNewFieldLabelEn(e.target.value)}
                        placeholder="Transfer Receipt"
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>{t("fieldLabelAr")}</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldLabelAr}
                        onChange={e => setNewFieldLabelAr(e.target.value)}
                        placeholder="صورة إشعار التحويل"
                      />
                    </div>
                    <div className="form-group">
                      <label className="form-label" style={{ fontSize: 11 }}>{t("fieldType")}</label>
                      <select
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldType}
                        onChange={e => setNewFieldType(e.target.value as any)}
                      >
                        <option value="text">{t("textType")}</option>
                        <option value="number">{t("numberType")}</option>
                        <option value="select">{t("dropdownSelectType")}</option>
                        <option value="file">{t("fileUploadType")}</option>
                      </select>
                    </div>
                    <button
                      type="button"
                      className="btn btn-primary btn-sm"
                      style={{ height: 32 }}
                      onClick={handleAddField}
                    >
                      <Plus size={14} /> {t("add")}
                    </button>
                  </div>

                  {newFieldType === "select" && (
                    <div className="form-group" style={{ marginBottom: 12 }}>
                      <label className="form-label" style={{ fontSize: 11 }}>{t("optionsCommaSeparated")}</label>
                      <input
                        className="input"
                        style={{ height: 32, fontSize: 12 }}
                        value={newFieldOptions}
                        onChange={e => setNewFieldOptions(e.target.value)}
                        placeholder="Option 1, Option 2, Option 3"
                      />
                    </div>
                  )}

                  {/* List of current dynamic fields */}
                  {dynamicFields.length === 0 ? (
                    <div style={{ textAlign: "center", padding: "12px 0", color: "var(--text-muted)", fontSize: 12 }}>
                      {t("none")}
                    </div>
                  ) : (
                    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                      {dynamicFields.map((field, index) => (
                        <div
                          key={field.key}
                          style={{
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "space-between",
                            padding: "6px 10px",
                            background: "var(--bg-surface)",
                            border: "1px solid var(--border)",
                            borderRadius: 6,
                            fontSize: 12,
                          }}
                        >
                          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                            <span style={{ fontWeight: 600, color: "var(--text-primary)" }}>{field.key}</span>
                            <span style={{ color: "var(--text-muted)" }}>•</span>
                            <span style={{ color: "var(--text-secondary)" }}>{field.label_en} / {field.label_ar}</span>
                            <span className="badge badge-secondary" style={{ textTransform: "uppercase", fontSize: 10 }}>{field.type}</span>
                          </div>
                          <button
                            type="button"
                            className="btn btn-danger btn-icon btn-sm"
                            onClick={() => handleRemoveField(index)}
                          >
                            <Trash2 size={12} />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="form-group" style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 4 }}>
                  <input
                    id="method-is-active"
                    type="checkbox"
                    checked={isActive}
                    onChange={e => setIsActive(e.target.checked)}
                    style={{ width: 16, height: 16, cursor: "pointer" }}
                  />
                  <label htmlFor="method-is-active" className="form-label" style={{ margin: 0, cursor: "pointer" }}>
                    {t("active")}
                  </label>
                </div>
              </div>

              <div className="modal-actions" style={{ marginTop: 20 }}>
                <button type="button" className="btn btn-ghost" onClick={() => setModalOpen(false)}>
                  {t("cancel")}
                </button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? "Saving..." : t("saveChanges")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
