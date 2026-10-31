"use client";

import { useEffect, useState, useCallback } from "react";
import { Plus, Pencil, Trash2, RefreshCw, Shield, CheckCircle2, XCircle } from "lucide-react";
import { adminApi, SubAdmin } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

interface CreateSubAdminForm {
  name: string;
  email: string;
  password: string;
  can_manage_products: boolean;
  can_view_orders: boolean;
  can_update_order_status: boolean;
}

const EMPTY_CREATE_FORM: CreateSubAdminForm = {
  name: "",
  email: "",
  password: "",
  can_manage_products: true,
  can_view_orders: true,
  can_update_order_status: true,
};

export default function SubAdminsPage() {
  const { t, lang } = useLang();
  const [subAdmins, setSubAdmins] = useState<SubAdmin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // Create Modal
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [createForm, setCreateForm] = useState<CreateSubAdminForm>({ ...EMPTY_CREATE_FORM });
  const [creating, setCreating] = useState(false);

  // Edit Permissions Modal
  const [editTarget, setEditTarget] = useState<SubAdmin | null>(null);
  const [editPermissions, setEditPermissions] = useState<{
    can_manage_products: boolean;
    can_view_orders: boolean;
    can_update_order_status: boolean;
  }>({
    can_manage_products: false,
    can_view_orders: false,
    can_update_order_status: false,
  });
  const [savingPermissions, setSavingPermissions] = useState(false);

  const loadSubAdmins = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await adminApi.listSubAdmins();
      setSubAdmins(res);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    loadSubAdmins();
  }, [loadSubAdmins]);

  const openCreateModal = () => {
    setCreateForm({ ...EMPTY_CREATE_FORM });
    setShowCreateModal(true);
  };

  const handleCreateSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!createForm.name || !createForm.email || !createForm.password) return;

    setCreating(true);
    setError("");
    try {
      await adminApi.createSubAdmin({
        name: createForm.name,
        email: createForm.email,
        password: createForm.password,
        permissions: {
          can_manage_products: createForm.can_manage_products,
          can_view_orders: createForm.can_view_orders,
          can_update_order_status: createForm.can_update_order_status,
        },
      });
      setShowCreateModal(false);
      setSuccess(lang === "ar" ? "تمت إضافة المشرف بنجاح" : "Sub-admin added successfully");
      setTimeout(() => setSuccess(""), 3000);
      loadSubAdmins();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setCreating(false);
    }
  };

  const openEditPermissions = (subAdmin: SubAdmin) => {
    setEditTarget(subAdmin);
    setEditPermissions({
      can_manage_products: !!subAdmin.admin_permissions?.can_manage_products,
      can_view_orders: !!subAdmin.admin_permissions?.can_view_orders,
      can_update_order_status: !!subAdmin.admin_permissions?.can_update_order_status,
    });
  };

  const handleUpdatePermissions = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editTarget) return;

    setSavingPermissions(true);
    setError("");
    try {
      await adminApi.updateSubAdminPermissions(editTarget.id, editPermissions);
      setEditTarget(null);
      setSuccess(lang === "ar" ? "تم تحديث الصلاحيات بنجاح" : "Permissions updated successfully");
      setTimeout(() => setSuccess(""), 3000);
      loadSubAdmins();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSavingPermissions(false);
    }
  };

  const handleDelete = async (subAdmin: SubAdmin) => {
    if (!confirm(t("deleteSubAdminConfirm"))) return;
    setError("");
    try {
      await adminApi.deleteSubAdmin(subAdmin.id);
      setSuccess(lang === "ar" ? "تم حذف المشرف بنجاح" : "Sub-admin deleted successfully");
      setTimeout(() => setSuccess(""), 3000);
      loadSubAdmins();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToDelete"));
    }
  };

  const initials = (name: string) =>
    name?.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "S";

  return (
    <div>
      {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}
      {success && (
        <div
          className="alert"
          style={{
            marginBottom: 16,
            background: "var(--success-bg, rgba(16, 185, 129, 0.1))",
            color: "var(--success, #10b981)",
            border: "1px solid var(--success-border, rgba(16, 185, 129, 0.2))",
            padding: "10px 14px",
            borderRadius: 8,
          }}
        >
          {success}
        </div>
      )}

      {/* Header bar */}
      <div className="section-header" style={{ marginBottom: 20 }}>
        <div>
          <h2 style={{ fontSize: 18, fontWeight: 700, display: "flex", alignItems: "center", gap: 8 }}>
            <Shield size={20} className="text-primary" />
            {t("subAdmins")}
          </h2>
          <p style={{ color: "var(--text-secondary)", fontSize: 13, marginTop: 4 }}>
            {lang === "ar"
              ? "إدارة المشرفين الفرعيين وتحديد صلاحياتهم في لوحة التحكم."
              : "Manage supervisor accounts and restrict their administrative privileges."}
          </p>
        </div>
        <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
          <button className="btn btn-ghost btn-icon" onClick={loadSubAdmins} title={t("refresh")}>
            <RefreshCw size={16} />
          </button>
          <button id="add-subadmin-btn" className="btn btn-primary" onClick={openCreateModal}>
            <Plus size={16} /> {t("addSubAdmin")}
          </button>
        </div>
      </div>

      {/* Table container */}
      <div className="table-container card">
        {loading ? (
          <div style={{ padding: 60, display: "flex", justifyContent: "center" }}>
            <div className="spinner" style={{ width: 36, height: 36 }} />
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>{t("user")}</th>
                <th>{t("role")}</th>
                <th>{t("permissions")}</th>
                <th>{t("status")}</th>
                <th>{lang === "ar" ? "تاريخ الإنشاء" : "Created Date"}</th>
                <th style={{ textAlign: "right" }}>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {subAdmins.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
                    {t("noSubAdminsFound")}
                  </td>
                </tr>
              ) : (
                subAdmins.map(admin => {
                  const perms = admin.admin_permissions;
                  return (
                    <tr key={admin.id}>
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                          <div className="avatar" style={{ width: 36, height: 36, fontSize: 13 }}>
                            {initials(admin.name)}
                          </div>
                          <div>
                            <div style={{ fontWeight: 600 }}>{admin.name}</div>
                            <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{admin.email}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className="badge badge-admin" style={{ fontSize: 11 }}>
                          {t("subAdminBadge")}
                        </span>
                      </td>
                      <td>
                        <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
                          {perms?.can_manage_products && (
                            <span
                              className="badge"
                              style={{
                                background: "rgba(59, 130, 246, 0.12)",
                                color: "#3b82f6",
                                border: "1px solid rgba(59, 130, 246, 0.3)",
                                fontSize: 11,
                              }}
                            >
                              ✓ {t("canManageProducts")}
                            </span>
                          )}
                          {perms?.can_view_orders && (
                            <span
                              className="badge"
                              style={{
                                background: "rgba(16, 185, 129, 0.12)",
                                color: "#10b981",
                                border: "1px solid rgba(16, 185, 129, 0.3)",
                                fontSize: 11,
                              }}
                            >
                              ✓ {t("canViewOrders")}
                            </span>
                          )}
                          {perms?.can_update_order_status && (
                            <span
                              className="badge"
                              style={{
                                background: "rgba(168, 85, 247, 0.12)",
                                color: "#a855f7",
                                border: "1px solid rgba(168, 85, 247, 0.3)",
                                fontSize: 11,
                              }}
                            >
                              ✓ {t("canUpdateOrderStatus")}
                            </span>
                          )}
                          {!perms?.can_manage_products && !perms?.can_view_orders && !perms?.can_update_order_status && (
                            <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
                              {lang === "ar" ? "لا توجد صلاحيات" : "No permissions"}
                            </span>
                          )}
                        </div>
                      </td>
                      <td>
                        <span className={`badge ${admin.is_active ? "badge-success" : "badge-inactive"}`}>
                          {admin.is_active ? t("active") : t("inactive")}
                        </span>
                      </td>
                      <td style={{ fontSize: 12, color: "var(--text-muted)" }}>
                        {admin.created_at ? new Date(admin.created_at).toLocaleDateString(lang === "ar" ? "ar-EG" : "en-US") : "—"}
                      </td>
                      <td style={{ textAlign: "right" }}>
                        <div style={{ display: "inline-flex", gap: 6 }}>
                          <button
                            className="btn btn-ghost btn-sm"
                            onClick={() => openEditPermissions(admin)}
                            title={t("editPermissions")}
                            style={{ display: "flex", alignItems: "center", gap: 4 }}
                          >
                            <Pencil size={13} />
                            <span>{t("permissions")}</span>
                          </button>
                          <button
                            className="btn btn-ghost btn-icon btn-sm"
                            style={{ color: "var(--danger)" }}
                            onClick={() => handleDelete(admin)}
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

      {/* Modal: Add Sub-Admin */}
      {showCreateModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowCreateModal(false)}>
          <div className="modal" style={{ maxWidth: 520 }}>
            <div className="modal-title" style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <Shield size={20} className="text-primary" />
              {t("addSubAdmin")}
            </div>
            <form onSubmit={handleCreateSubmit}>
              <div style={{ display: "flex", flexDirection: "column", gap: 14, margin: "16px 0" }}>
                <div className="form-group">
                  <label className="form-label">{lang === "ar" ? "الاسم الكامل *" : "Full Name *"}</label>
                  <input
                    required
                    className="input"
                    value={createForm.name}
                    onChange={e => setCreateForm(f => ({ ...f, name: e.target.value }))}
                    placeholder={lang === "ar" ? "مثال: أحمد محمد" : "e.g. John Doe"}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">{t("email")} *</label>
                  <input
                    required
                    type="email"
                    className="input"
                    value={createForm.email}
                    onChange={e => setCreateForm(f => ({ ...f, email: e.target.value }))}
                    placeholder="supervisor@example.com"
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">{t("password")} *</label>
                  <input
                    required
                    type="password"
                    className="input"
                    value={createForm.password}
                    onChange={e => setCreateForm(f => ({ ...f, password: e.target.value }))}
                    placeholder="••••••••"
                  />
                </div>

                {/* Permissions checkboxes */}
                <div style={{ borderTop: "1px solid var(--border)", paddingTop: 14 }}>
                  <label className="form-label" style={{ fontWeight: 600, marginBottom: 10, display: "block" }}>
                    {t("permissions")}
                  </label>
                  <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                    <label style={{ display: "flex", alignItems: "center", gap: 10, cursor: "pointer", fontSize: 13 }}>
                      <input
                        type="checkbox"
                        checked={createForm.can_manage_products}
                        onChange={e => setCreateForm(f => ({ ...f, can_manage_products: e.target.checked }))}
                        style={{ width: 16, height: 16, cursor: "pointer" }}
                      />
                      <span>{t("canManageProducts")}</span>
                    </label>

                    <label style={{ display: "flex", alignItems: "center", gap: 10, cursor: "pointer", fontSize: 13 }}>
                      <input
                        type="checkbox"
                        checked={createForm.can_view_orders}
                        onChange={e => setCreateForm(f => ({ ...f, can_view_orders: e.target.checked }))}
                        style={{ width: 16, height: 16, cursor: "pointer" }}
                      />
                      <span>{t("canViewOrders")}</span>
                    </label>

                    <label style={{ display: "flex", alignItems: "center", gap: 10, cursor: "pointer", fontSize: 13 }}>
                      <input
                        type="checkbox"
                        checked={createForm.can_update_order_status}
                        onChange={e => setCreateForm(f => ({ ...f, can_update_order_status: e.target.checked }))}
                        style={{ width: 16, height: 16, cursor: "pointer" }}
                      />
                      <span>{t("canUpdateOrderStatus")}</span>
                    </label>
                  </div>
                </div>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setShowCreateModal(false)}>
                  {t("cancel")}
                </button>
                <button type="submit" className="btn btn-primary" disabled={creating || !createForm.name || !createForm.email || !createForm.password}>
                  {creating ? <div className="spinner" /> : t("addSubAdmin")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Edit Permissions */}
      {editTarget && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setEditTarget(null)}>
          <div className="modal" style={{ maxWidth: 480 }}>
            <div className="modal-title" style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <Shield size={20} className="text-primary" />
              {t("editPermissions")}
            </div>
            <div style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 16 }}>
              <strong style={{ color: "var(--text-primary)" }}>{editTarget.name}</strong> ({editTarget.email})
            </div>
            <form onSubmit={handleUpdatePermissions}>
              <div style={{ display: "flex", flexDirection: "column", gap: 12, marginBottom: 20 }}>
                <label style={{ display: "flex", alignItems: "center", gap: 10, cursor: "pointer", fontSize: 13 }}>
                  <input
                    type="checkbox"
                    checked={editPermissions.can_manage_products}
                    onChange={e => setEditPermissions(p => ({ ...p, can_manage_products: e.target.checked }))}
                    style={{ width: 16, height: 16, cursor: "pointer" }}
                  />
                  <span>{t("canManageProducts")}</span>
                </label>

                <label style={{ display: "flex", alignItems: "center", gap: 10, cursor: "pointer", fontSize: 13 }}>
                  <input
                    type="checkbox"
                    checked={editPermissions.can_view_orders}
                    onChange={e => setEditPermissions(p => ({ ...p, can_view_orders: e.target.checked }))}
                    style={{ width: 16, height: 16, cursor: "pointer" }}
                  />
                  <span>{t("canViewOrders")}</span>
                </label>

                <label style={{ display: "flex", alignItems: "center", gap: 10, cursor: "pointer", fontSize: 13 }}>
                  <input
                    type="checkbox"
                    checked={editPermissions.can_update_order_status}
                    onChange={e => setEditPermissions(p => ({ ...p, can_update_order_status: e.target.checked }))}
                    style={{ width: 16, height: 16, cursor: "pointer" }}
                  />
                  <span>{t("canUpdateOrderStatus")}</span>
                </label>
              </div>

              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setEditTarget(null)}>
                  {t("cancel")}
                </button>
                <button type="submit" className="btn btn-primary" disabled={savingPermissions}>
                  {savingPermissions ? <div className="spinner" /> : t("saveChanges")}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
