"use client";

import { useEffect, useState, useCallback } from "react";
import { Plus, Pencil, Trash2, RefreshCw } from "lucide-react";
import { adminApi, Category, API_BASE } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const EMPTY_FORM = { name_en: "", name_ar: "", icon: "", image_url: "", sort_order: "0" };

export default function CategoriesPage() {
  const { t, lang } = useLang();
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editCat, setEditCat] = useState<Category | null>(null);
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.listCategories();
      setCategories(res);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => { load(); }, [load]);

  const openCreate = () => {
    setEditCat(null);
    setForm({ ...EMPTY_FORM });
    setShowModal(true);
  };

  const openEdit = (c: Category) => {
    setEditCat(c);
    setForm({
      name_en: c.name_en,
      name_ar: c.name_ar,
      icon: c.icon || "",
      image_url: c.image_url || "",
      sort_order: String(c.sort_order),
    });
    setShowModal(true);
  };

  const handleSubmit = async () => {
    setSaving(true);
    try {
      const payload = {
        name_en: form.name_en,
        name_ar: form.name_ar,
        icon: form.icon || undefined,
        image_url: form.image_url || undefined,
        sort_order: parseInt(form.sort_order) || 0,
      };
      if (editCat) {
        await adminApi.updateCategory(editCat.id, payload);
      } else {
        await adminApi.createCategory(payload);
      }
      setShowModal(false);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm(t("deleteCategoryConfirm"))) return;
    try {
      await adminApi.deleteCategory(id);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToDelete"));
    }
  };

  return (
    <div>
      {error && <div className="alert alert-error">{error}</div>}

      {/* Header */}
      <div className="section-header">
        <p style={{ color: "var(--text-secondary)", fontSize: 14, flex: 1 }}>
          {categories.length} {t("categoriesTotal")}
        </p>
        <button className="btn btn-ghost btn-icon" onClick={load} title={t("refresh")}>
          <RefreshCw size={16} />
        </button>
        <button id="add-category" className="btn btn-primary" onClick={openCreate}>
          <Plus size={16} /> {t("addCategory")}
        </button>
      </div>

      {/* Category grid */}
      {loading ? (
        <div style={{ padding: 60, display: "flex", justifyContent: "center" }}>
          <div className="spinner" style={{ width: 36, height: 36, borderWidth: 3 }} />
        </div>
      ) : (
        <div style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))",
          gap: 16,
        }}>
          {categories.map(cat => (
            <div key={cat.id} className="card" style={{ padding: 0, overflow: "hidden" }}>
              {/* Category image */}
              <div style={{
                height: 100,
                background: cat.image_url
                  ? `url(${cat.image_url}) center/cover`
                  : "linear-gradient(135deg, var(--accent), #a855f7)",
                position: "relative",
              }}>
                <div style={{
                  position: "absolute",
                  inset: 0,
                  background: "linear-gradient(to bottom, transparent, rgba(0,0,0,0.5))",
                }} />
                <div style={{
                  position: "absolute",
                  bottom: 10,
                  left: lang === "ar" ? "auto" : 14,
                  right: lang === "ar" ? 14 : "auto",
                  fontSize: 28,
                }}>
                  {cat.icon}
                </div>
                {/* Actions */}
                <div style={{
                  position: "absolute",
                  top: 8,
                  right: lang === "ar" ? "auto" : 8,
                  left: lang === "ar" ? 8 : "auto",
                  display: "flex",
                  gap: 6
                }}>
                  <button
                    id={`edit-cat-${cat.id}`}
                    className="btn btn-ghost btn-icon btn-sm"
                    onClick={() => openEdit(cat)}
                    style={{ background: "rgba(0,0,0,0.4)", border: "none", color: "white" }}
                    title={t("edit")}
                  >
                    <Pencil size={13} />
                  </button>
                  <button
                    id={`delete-cat-${cat.id}`}
                    className="btn btn-icon btn-sm"
                    onClick={() => handleDelete(cat.id)}
                    style={{ background: "rgba(239,68,68,0.4)", border: "none", color: "white" }}
                    title={t("delete")}
                  >
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>

              {/* Info */}
              <div style={{ padding: "14px 16px" }}>
                <div style={{ fontWeight: 600, fontSize: 15, marginBottom: 4 }}>
                  {lang === "ar" ? (cat.name_ar || cat.name_en) : cat.name_en}
                </div>
                <div style={{ fontSize: 13, color: "var(--text-muted)" }}>
                  {lang === "ar" ? cat.name_en : cat.name_ar}
                </div>
                <div style={{ marginTop: 8, display: "flex", gap: 8, alignItems: "center" }}>
                  <span style={{ fontSize: 11, color: "var(--text-muted)" }}>{t("sortOrder")}: {cat.sort_order}</span>
                  <span style={{
                    fontSize: 11,
                    color: "var(--text-muted)",
                    fontFamily: "monospace",
                    marginLeft: lang === "ar" ? "0" : "auto",
                    marginRight: lang === "ar" ? "auto" : "0"
                  }}>
                    {cat.id.slice(4, 10)}
                  </span>
                </div>
              </div>
            </div>
          ))}

          {categories.length === 0 && (
            <div style={{ gridColumn: "1 / -1", textAlign: "center", padding: 60, color: "var(--text-muted)" }}>
              {t("noCategoriesYet")}
            </div>
          )}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowModal(false)}>
          <div className="modal">
            <div className="modal-title">{editCat ? t("editCategoryTitle") : t("newCategoryTitle")}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("nameEn")}</label>
                  <input id="cat-name-en" className="input" value={form.name_en} onChange={e => setForm(f => ({ ...f, name_en: e.target.value }))} />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("nameAr")}</label>
                  <input id="cat-name-ar" className="input" value={form.name_ar} onChange={e => setForm(f => ({ ...f, name_ar: e.target.value }))} dir="rtl" />
                </div>
              </div>

              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("iconEmoji")}</label>
                  <input id="cat-icon" className="input" value={form.icon} onChange={e => setForm(f => ({ ...f, icon: e.target.value }))} placeholder="📱" />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("sortOrder")}</label>
                  <input id="cat-sort" type="number" className="input" value={form.sort_order} onChange={e => setForm(f => ({ ...f, sort_order: e.target.value }))} />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">{t("imageUrl")}</label>
                <div style={{ display: "flex", gap: 10 }}>
                  <input id="cat-image" type="url" className="input" value={form.image_url} onChange={e => setForm(f => ({ ...f, image_url: e.target.value }))} placeholder="https://..." style={{ flex: 1 }} />
                  <input
                    type="file"
                    accept="image/*"
                    id="cat-image-file"
                    style={{ display: "none" }}
                    onChange={async (e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      try {
                        setSaving(true);
                        const res = await adminApi.uploadImage(file);
                        const uploadedUrl = res.image_url.startsWith('/') ? `${API_BASE.replace('/api/v1', '')}${res.image_url}` : res.image_url;
                        setForm(f => ({ ...f, image_url: uploadedUrl }));
                      } catch (err: any) {
                        alert(err.message || "Upload failed");
                      } finally {
                        setSaving(false);
                      }
                    }}
                  />
                  <button
                    type="button"
                    className="btn btn-secondary"
                    onClick={() => document.getElementById("cat-image-file")?.click()}
                    disabled={saving}
                  >
                    {saving ? "..." : "Upload / Capture"}
                  </button>
                </div>
                {form.image_url && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={form.image_url} alt="preview" style={{ marginTop: 8, height: 80, borderRadius: 8, objectFit: "cover", width: "100%", border: "1px solid var(--border)" }} />
                )}
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setShowModal(false)}>{t("cancel")}</button>
              <button id="save-category" className="btn btn-primary" onClick={handleSubmit} disabled={saving || !form.name_en || !form.name_ar}>
                {saving ? <div className="spinner" /> : editCat ? t("saveChanges") : t("addCategory")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
