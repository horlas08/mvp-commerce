"use client";

import { useEffect, useState, useCallback } from "react";
import { Search, Plus, Pencil, Trash2, RefreshCw, Eye, EyeOff } from "lucide-react";
import { adminApi, Product, Category } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const EMPTY_FORM = {
  title_en: "", title_ar: "", description_en: "", description_ar: "",
  price: "", discount_price: "", category_id: "", stock: "0", images: "",
};

export default function ProductsPage() {
  const { t, lang } = useLang();
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [catFilter, setCatFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editProduct, setEditProduct] = useState<Product | null>(null);
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const LIMIT = 12;

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [p, c] = await Promise.all([
        adminApi.listProducts({ page, limit: LIMIT, search: search || undefined, category_id: catFilter || undefined }),
        adminApi.listCategories(),
      ]);
      setProducts(p.products);
      setTotal(p.total);
      setCategories(c);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [page, search, catFilter, t]);

  useEffect(() => { load(); }, [load]);

  const openCreate = () => {
    setEditProduct(null);
    setForm({ ...EMPTY_FORM });
    setShowModal(true);
  };

  const openEdit = (p: Product) => {
    setEditProduct(p);
    setForm({
      title_en: p.title_en,
      title_ar: p.title_ar,
      description_en: p.description_en || "",
      description_ar: p.description_ar || "",
      price: String(p.price),
      discount_price: p.discount_price ? String(p.discount_price) : "",
      category_id: p.category_id || "",
      stock: String(p.stock),
      images: (p.images || []).join("\n"),
    });
    setShowModal(true);
  };

  const handleSubmit = async () => {
    setSaving(true);
    try {
      const payload = {
        title_en: form.title_en,
        title_ar: form.title_ar,
        description_en: form.description_en || undefined,
        description_ar: form.description_ar || undefined,
        price: parseFloat(form.price),
        discount_price: form.discount_price ? parseFloat(form.discount_price) : undefined,
        category_id: form.category_id || undefined,
        stock: parseInt(form.stock) || 0,
        images: form.images ? form.images.split("\n").map(s => s.trim()).filter(Boolean) : undefined,
      };
      if (editProduct) {
        await adminApi.updateProduct(editProduct.id, payload);
      } else {
        await adminApi.createProduct(payload);
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
    if (!confirm(t("deleteProductConfirm"))) return;
    try {
      await adminApi.deleteProduct(id);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToDelete"));
    }
  };

  const handleToggle = async (p: Product) => {
    try {
      await adminApi.updateProduct(p.id, { is_active: !p.is_active });
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    }
  };

  const getCatName = (id?: string) => {
    const c = categories.find(cat => cat.id === id);
    if (!c) return "—";
    return lang === "ar" ? (c.name_ar || c.name_en) : c.name_en;
  };

  const totalPages = Math.ceil(total / LIMIT);

  return (
    <div>
      {error && <div className="alert alert-error">{error}</div>}

      {/* Header */}
      <div className="section-header">
        <div className="search-bar">
          <Search size={16} />
          <input
            id="product-search"
            placeholder={t("searchProductsPlaceholder")}
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1); }}
          />
        </div>

        <select
          id="product-cat-filter"
          className="input"
          style={{ width: "auto", minWidth: 160 }}
          value={catFilter}
          onChange={e => { setCatFilter(e.target.value); setPage(1); }}
        >
          <option value="">{t("allCategories")}</option>
          {categories.map(c => (
            <option key={c.id} value={c.id}>
              {c.icon} {lang === "ar" ? (c.name_ar || c.name_en) : c.name_en}
            </option>
          ))}
        </select>

        <button className="btn btn-ghost btn-icon" onClick={load} title={t("refresh")}>
          <RefreshCw size={16} />
        </button>

        <button id="add-product" className="btn btn-primary" onClick={openCreate}>
          <Plus size={16} /> {t("addProduct")}
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
                <th>{t("product")}</th>
                <th>{t("category")}</th>
                <th>{t("price")}</th>
                <th>{t("stock")}</th>
                <th>{t("rating")}</th>
                <th>{t("status")}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {products.length === 0 ? (
                <tr><td colSpan={7} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>{t("noProductsFound")}</td></tr>
              ) : products.map(p => (
                <tr key={p.id}>
                  <td>
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      {p.images?.[0] ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={p.images[0]} alt={p.title_en} className="product-thumb" />
                      ) : (
                        <div className="product-thumb" style={{ display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-muted)", fontSize: 18 }}>📦</div>
                      )}
                      <div>
                        <div style={{ fontWeight: 500, maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                          {lang === "ar" ? (p.title_ar || p.title_en) : p.title_en}
                        </div>
                        <div style={{ fontSize: 12, color: "var(--text-muted)" }}>
                          {lang === "ar" ? p.title_en : p.title_ar}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td style={{ color: "var(--text-secondary)", fontSize: 13 }}>{getCatName(p.category_id)}</td>
                  <td>
                    {p.discount_price ? (
                      <div>
                        <div style={{ fontWeight: 600 }}>﷼ {p.discount_price.toFixed(2)}</div>
                        <div style={{ fontSize: 12, color: "var(--text-muted)", textDecoration: "line-through" }}>﷼ {p.price.toFixed(2)}</div>
                      </div>
                    ) : (
                      <span style={{ fontWeight: 600 }}>﷼ {p.price.toFixed(2)}</span>
                    )}
                  </td>
                  <td>
                    <span style={{
                      fontWeight: 600,
                      color: p.stock === 0 ? "var(--danger)" : p.stock < 10 ? "var(--warning)" : "var(--success)"
                    }}>
                      {p.stock}
                    </span>
                  </td>
                  <td>
                    <span style={{ fontSize: 13 }}>⭐ {p.rating.toFixed(1)} ({p.rating_count})</span>
                  </td>
                  <td>
                    <span className={`badge ${p.is_active ? "badge-active" : "badge-inactive"}`}>
                      {p.is_active ? t("active") : t("inactive")}
                    </span>
                  </td>
                  <td>
                    <div style={{ display: "flex", gap: 6 }}>
                      <button
                        id={`edit-product-${p.id}`}
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={() => openEdit(p)}
                        title={t("edit")}
                      >
                        <Pencil size={14} />
                      </button>
                      <button
                        id={`toggle-product-${p.id}`}
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={() => handleToggle(p)}
                        title={p.is_active ? t("deactivate") : t("activate")}
                      >
                        {p.is_active ? <EyeOff size={14} /> : <Eye size={14} />}
                      </button>
                      <button
                        id={`delete-product-${p.id}`}
                        className="btn btn-danger btn-icon btn-sm"
                        onClick={() => handleDelete(p.id)}
                        title={t("delete")}
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="pagination">
          <button className="pagination-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>{t("prev")}</button>
          {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => i + 1).map(p => (
            <button key={p} className={`pagination-btn${page === p ? " active" : ""}`} onClick={() => setPage(p)}>{p}</button>
          ))}
          <button className="pagination-btn" disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}>{t("next")}</button>
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowModal(false)}>
          <div className="modal" style={{ maxWidth: 600 }}>
            <div className="modal-title">{editProduct ? t("editProductTitle") : t("addNewProductTitle")}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("titleEn")}</label>
                  <input id="form-title-en" className="input" value={form.title_en} onChange={e => setForm(f => ({ ...f, title_en: e.target.value }))} />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("titleAr")}</label>
                  <input id="form-title-ar" className="input" value={form.title_ar} onChange={e => setForm(f => ({ ...f, title_ar: e.target.value }))} dir="rtl" />
                </div>
              </div>

              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("descEn")}</label>
                  <textarea id="form-desc-en" className="input" rows={3} value={form.description_en} onChange={e => setForm(f => ({ ...f, description_en: e.target.value }))} style={{ resize: "vertical" }} />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("descAr")}</label>
                  <textarea id="form-desc-ar" className="input" rows={3} value={form.description_ar} onChange={e => setForm(f => ({ ...f, description_ar: e.target.value }))} dir="rtl" style={{ resize: "vertical" }} />
                </div>
              </div>

              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("priceSar")}</label>
                  <input id="form-price" type="number" step="0.01" className="input" value={form.price} onChange={e => setForm(f => ({ ...f, price: e.target.value }))} />
                </div>
                <div className="form-group">
                  <label className="form-label">{t("discountPrice")}</label>
                  <input id="form-discount" type="number" step="0.01" className="input" value={form.discount_price} onChange={e => setForm(f => ({ ...f, discount_price: e.target.value }))} />
                </div>
              </div>

              <div className="grid-2">
                <div className="form-group">
                  <label className="form-label">{t("category")}</label>
                  <select id="form-cat" className="input" value={form.category_id} onChange={e => setForm(f => ({ ...f, category_id: e.target.value }))}>
                    <option value="">— {t("noCategory")} —</option>
                    {categories.map(c => (
                      <option key={c.id} value={c.id}>
                        {c.icon} {lang === "ar" ? (c.name_ar || c.name_en) : c.name_en}
                      </option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label">{t("stock")}</label>
                  <input id="form-stock" type="number" className="input" value={form.stock} onChange={e => setForm(f => ({ ...f, stock: e.target.value }))} />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">{t("imageUrls")}</label>
                <textarea
                  id="form-images"
                  className="input"
                  rows={3}
                  value={form.images}
                  onChange={e => setForm(f => ({ ...f, images: e.target.value }))}
                  placeholder="https://example.com/image1.jpg&#10;https://example.com/image2.jpg"
                  style={{ resize: "vertical" }}
                />
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setShowModal(false)}>{t("cancel")}</button>
              <button id="save-product" className="btn btn-primary" onClick={handleSubmit} disabled={saving || !form.title_en || !form.price}>
                {saving ? <div className="spinner" /> : editProduct ? t("saveChanges") : t("createProductBtn")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
