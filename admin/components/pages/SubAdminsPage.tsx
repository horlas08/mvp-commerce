"use client";

import React, { useEffect, useState, useCallback, useMemo } from "react";
import {
  Plus,
  Pencil,
  Trash2,
  RefreshCw,
  Shield,
  CheckCircle2,
  XCircle,
  Search,
  X,
  Check,
  Sparkles,
  SlidersHorizontal,
  Layers,
  Lock,
  CheckSquare2,
  LayoutDashboard,
  ShoppingBag,
  Coins,
  RotateCcw,
  Ticket,
  Package,
  Tag,
  MapPin,
  CreditCard,
  MessageSquare,
  Users,
  Settings,
} from "lucide-react";
import { adminApi, SubAdmin } from "@/lib/api";
import { useLang } from "@/lib/lang-context";
import {
  PERMISSION_MODULES,
  PERMISSION_PRESETS,
  getAllPermissionKeys,
  PagePermissionModule,
  PermissionAction,
} from "@/lib/permissions-config";

const MODULE_ICONS: Record<string, React.ElementType> = {
  LayoutDashboard,
  ShoppingBag,
  Coins,
  RotateCcw,
  Ticket,
  Package,
  Tag,
  MapPin,
  CreditCard,
  MessageSquare,
  Users,
  Settings,
};

export default function SubAdminsPage() {
  const { t, lang } = useLang();
  const [subAdmins, setSubAdmins] = useState<SubAdmin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // Modal State
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [modalMode, setModalMode] = useState<"create" | "edit">("create");
  const [selectedSubAdmin, setSelectedSubAdmin] = useState<SubAdmin | null>(null);

  // Form Fields
  const [formName, setFormName] = useState("");
  const [formEmail, setFormEmail] = useState("");
  const [formPassword, setFormPassword] = useState("");

  // Permissions state in modal
  const [permsState, setPermsState] = useState<Record<string, boolean>>({});
  const [searchQuery, setSearchQuery] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const allKeys = useMemo(() => getAllPermissionKeys(), []);

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

  // Open Create Modal
  const openCreateModal = () => {
    setModalMode("create");
    setSelectedSubAdmin(null);
    setFormName("");
    setFormEmail("");
    setFormPassword("");
    setSearchQuery("");

    // Default to the first preset (Orders & Shipping Specialist)
    const initialPerms: Record<string, boolean> = {};
    allKeys.forEach((k) => {
      initialPerms[k] = false;
    });
    PERMISSION_PRESETS[0].keys.forEach((k) => {
      initialPerms[k] = true;
    });
    setPermsState(initialPerms);
    setIsModalOpen(true);
  };

  // Open Edit Modal
  const openEditModal = (admin: SubAdmin) => {
    setModalMode("edit");
    setSelectedSubAdmin(admin);
    setFormName(admin.name);
    setFormEmail(admin.email);
    setFormPassword("");
    setSearchQuery("");

    // Populate current permissions
    const currentPerms: Record<string, boolean> = {};
    allKeys.forEach((k) => {
      currentPerms[k] = !!admin.admin_permissions?.[k];
    });
    setPermsState(currentPerms);
    setIsModalOpen(true);
  };

  // Apply a preset template
  const applyPreset = (presetKeys: string[]) => {
    const updated: Record<string, boolean> = {};
    allKeys.forEach((k) => {
      updated[k] = false;
    });
    presetKeys.forEach((k) => {
      updated[k] = true;
    });
    setPermsState(updated);
  };

  // Select all or clear all
  const selectAllPermissions = () => {
    const updated: Record<string, boolean> = {};
    allKeys.forEach((k) => {
      updated[k] = true;
    });
    setPermsState(updated);
  };

  const clearAllPermissions = () => {
    const updated: Record<string, boolean> = {};
    allKeys.forEach((k) => {
      updated[k] = false;
    });
    setPermsState(updated);
  };

  // Toggle single action
  const toggleAction = (module: PagePermissionModule, action: PermissionAction) => {
    setPermsState((prev) => {
      const isCurrentlyActive = !!prev[action.key];
      const willBeActive = !isCurrentlyActive;
      const next = { ...prev, [action.key]: willBeActive };

      // If turning ON an action inside a module, automatically grant the view permission
      if (willBeActive && !action.isViewAction) {
        next[module.viewPermissionKey] = true;
      }

      // If turning OFF the view permission of a module, turn off all actions in that module
      if (!willBeActive && action.isViewAction) {
        module.actions.forEach((a) => {
          next[a.key] = false;
        });
      }

      return next;
    });
  };

  // Toggle all actions in a single module
  const toggleModuleAll = (module: PagePermissionModule) => {
    const moduleKeys = module.actions.map((a) => a.key);
    const allModuleActive = moduleKeys.every((k) => !!permsState[k]);

    setPermsState((prev) => {
      const next = { ...prev };
      moduleKeys.forEach((k) => {
        next[k] = !allModuleActive;
      });
      return next;
    });
  };

  // Handle Form Submission
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (modalMode === "create") {
      if (!formName.trim() || !formEmail.trim() || !formPassword.trim()) {
        setError(lang === "ar" ? "يرجى ملء جميع الحقول المطلوبة." : "Please fill in all required fields.");
        return;
      }
    }

    setIsSubmitting(true);
    try {
      if (modalMode === "create") {
        await adminApi.createSubAdmin({
          name: formName.trim(),
          email: formEmail.trim(),
          password: formPassword.trim(),
          permissions: permsState,
        });
        setSuccess(lang === "ar" ? "تم إنشاء حساب المشرف بنجاح!" : "Sub-admin created successfully!");
      } else if (selectedSubAdmin) {
        await adminApi.updateSubAdminPermissions(selectedSubAdmin.id, permsState);
        setSuccess(lang === "ar" ? "تم تحديث الصلاحيات بنجاح!" : "Permissions updated successfully!");
      }

      setIsModalOpen(false);
      setTimeout(() => setSuccess(""), 4000);
      loadSubAdmins();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : t("failedToUpdate"));
    } finally {
      setIsSubmitting(false);
    }
  };

  // Delete Sub Admin
  const handleDelete = async (admin: SubAdmin) => {
    if (
      !confirm(
        lang === "ar"
          ? `هل أنت متأكد من رغبتك بحذف المشرف "${admin.name}"؟ لا يمكن التراجع عن هذا الإجراء.`
          : `Are you sure you want to delete supervisor "${admin.name}"? This cannot be undone.`
      )
    ) {
      return;
    }

    setError("");
    try {
      await adminApi.deleteSubAdmin(admin.id);
      setSuccess(lang === "ar" ? "تم حذف المشرف بنجاح" : "Sub-admin deleted successfully");
      setTimeout(() => setSuccess(""), 3000);
      loadSubAdmins();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : t("failedToDelete"));
    }
  };

  // Filter modules based on search query
  const filteredModules = useMemo(() => {
    if (!searchQuery.trim()) return PERMISSION_MODULES;
    const q = searchQuery.toLowerCase().trim();

    return PERMISSION_MODULES.filter((module) => {
      const matchModule =
        module.nameEn.toLowerCase().includes(q) ||
        module.nameAr.toLowerCase().includes(q) ||
        module.descriptionEn.toLowerCase().includes(q) ||
        module.descriptionAr.toLowerCase().includes(q);

      const matchAction = module.actions.some(
        (a) =>
          a.labelEn.toLowerCase().includes(q) ||
          a.labelAr.toLowerCase().includes(q) ||
          a.descEn.toLowerCase().includes(q) ||
          a.descAr.toLowerCase().includes(q) ||
          a.key.toLowerCase().includes(q)
      );

      return matchModule || matchAction;
    });
  }, [searchQuery]);

  // Statistics
  const activeCount = useMemo(() => {
    return Object.values(permsState).filter(Boolean).length;
  }, [permsState]);

  const activeModulesCount = useMemo(() => {
    return PERMISSION_MODULES.filter((m) => m.actions.some((a) => !!permsState[a.key])).length;
  }, [permsState]);

  const initials = (name: string) =>
    name
      ?.split(" ")
      .map((n) => n[0])
      .join("")
      .toUpperCase()
      .slice(0, 2) || "S";

  return (
    <div style={{ maxWidth: 1400, margin: "0 auto" }}>
      {/* Alerts */}
      {error && (
        <div className="alert alert-error" style={{ marginBottom: 16 }}>
          {error}
        </div>
      )}
      {success && (
        <div
          className="alert"
          style={{
            marginBottom: 16,
            background: "rgba(16, 185, 129, 0.12)",
            color: "#10b981",
            border: "1px solid rgba(16, 185, 129, 0.25)",
            padding: "12px 16px",
            borderRadius: 10,
            display: "flex",
            alignItems: "center",
            gap: 8,
          }}
        >
          <CheckCircle2 size={18} />
          <span>{success}</span>
        </div>
      )}

      {/* Header Bar */}
      <div className="section-header" style={{ marginBottom: 24, justifyContent: "space-between" }}>
        <div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div
              style={{
                width: 38,
                height: 38,
                borderRadius: 10,
                background: "linear-gradient(135deg, #3b82f6, #6366f1)",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                color: "white",
              }}
            >
              <Shield size={22} />
            </div>
            <div>
              <h2 style={{ fontSize: 20, fontWeight: 700, margin: 0 }}>
                {lang === "ar" ? "المشرفين الفرعيين والصلاحيات" : "Sub-Admins & Permissions"}
              </h2>
              <p style={{ color: "var(--text-secondary)", fontSize: 13, marginTop: 2 }}>
                {lang === "ar"
                  ? "إدارة حسابات المشرفين وتخصيص صلاحيات الوصول والعمليات (CRUD) عبر كل صفحة في النظام."
                  : "Manage supervisor accounts and customize granular page-level permissions and action controls."}
              </p>
            </div>
          </div>
        </div>

        <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
          <button className="btn btn-ghost btn-icon" onClick={loadSubAdmins} title={t("refresh")}>
            <RefreshCw size={16} />
          </button>
          <button
            id="add-subadmin-btn"
            className="btn btn-primary"
            onClick={openCreateModal}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              padding: "10px 18px",
              fontWeight: 600,
              boxShadow: "0 4px 14px rgba(59, 130, 246, 0.35)",
            }}
          >
            <Plus size={18} />
            <span>{lang === "ar" ? "إضافة مشرف جديد" : "Add Sub-Admin"}</span>
          </button>
        </div>
      </div>

      {/* Sub-Admins Table */}
      <div className="table-container card" style={{ overflow: "hidden", borderRadius: 14 }}>
        {loading ? (
          <div style={{ padding: 80, display: "flex", justifyContent: "center" }}>
            <div className="spinner" style={{ width: 40, height: 40 }} />
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th style={{ width: "22%" }}>{t("user")}</th>
                <th style={{ width: "12%" }}>{t("role")}</th>
                <th style={{ width: "42%" }}>
                  {lang === "ar" ? "الصلاحيات والأقسام المتاحة" : "Granted Modules & Permissions"}
                </th>
                <th style={{ width: "10%" }}>{t("status")}</th>
                <th style={{ width: "14%", textAlign: "right" }}>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {subAdmins.length === 0 ? (
                <tr>
                  <td colSpan={5} style={{ textAlign: "center", padding: 60, color: "var(--text-muted)" }}>
                    <Shield size={40} style={{ margin: "0 auto 12px", opacity: 0.3 }} />
                    <div style={{ fontSize: 15, fontWeight: 600 }}>
                      {lang === "ar" ? "لا يوجد مشرفين فرعيين حالياً" : "No sub-admins found"}
                    </div>
                    <div style={{ fontSize: 13, marginTop: 4 }}>
                      {lang === "ar"
                        ? "اضغط على زر 'إضافة مشرف جديد' لإنشاء أول حساب وتحديد صلاحياته."
                        : "Click 'Add Sub-Admin' to create the first supervisor with restricted permissions."}
                    </div>
                  </td>
                </tr>
              ) : (
                subAdmins.map((admin) => {
                  const perms = admin.admin_permissions || {};
                  const enabledKeys = Object.entries(perms).filter(([_, v]) => Boolean(v)).map(([k]) => k);
                  const totalEnabled = enabledKeys.length;

                  // Find modules with at least 1 enabled action
                  const activeModules = PERMISSION_MODULES.filter((m) =>
                    m.actions.some((a) => Boolean(perms[a.key]))
                  );

                  return (
                    <tr key={admin.id}>
                      {/* User Info */}
                      <td>
                        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                          <div
                            className="avatar"
                            style={{
                              width: 40,
                              height: 40,
                              fontSize: 14,
                              fontWeight: 700,
                              background: "linear-gradient(135deg, #1e293b, #334155)",
                              color: "#38bdf8",
                              border: "1px solid rgba(56, 189, 248, 0.3)",
                            }}
                          >
                            {initials(admin.name)}
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: 14, color: "var(--text-primary)" }}>
                              {admin.name}
                            </div>
                            <div style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 2 }}>
                              {admin.email}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Role Badge */}
                      <td>
                        <span
                          className="badge"
                          style={{
                            background: "rgba(99, 102, 241, 0.12)",
                            color: "#818cf8",
                            border: "1px solid rgba(99, 102, 241, 0.3)",
                            fontSize: 12,
                            padding: "4px 10px",
                            fontWeight: 600,
                          }}
                        >
                          {t("subAdminBadge")}
                        </span>
                      </td>

                      {/* Permissions Overview */}
                      <td>
                        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                            <span
                              style={{
                                fontSize: 12,
                                fontWeight: 700,
                                color: totalEnabled > 0 ? "#38bdf8" : "var(--text-muted)",
                                background: "rgba(56, 189, 248, 0.1)",
                                padding: "2px 8px",
                                borderRadius: 6,
                              }}
                            >
                              {lang === "ar"
                                ? `${totalEnabled} صلاحية مفعلة`
                                : `${totalEnabled} of ${allKeys.length} permissions`}
                            </span>
                            <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
                              ({activeModules.length}/12 {lang === "ar" ? "أقسام" : "modules"})
                            </span>
                          </div>

                          {/* Chips of Active Modules */}
                          <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
                            {activeModules.length === 0 ? (
                              <span style={{ fontSize: 12, color: "var(--text-muted)", fontStyle: "italic" }}>
                                {lang === "ar" ? "لا توجد صلاحيات مفعلة" : "No permissions assigned"}
                              </span>
                            ) : (
                              activeModules.slice(0, 5).map((mod) => {
                                const modActiveCount = mod.actions.filter((a) => Boolean(perms[a.key])).length;
                                return (
                                  <span
                                    key={mod.id}
                                    style={{
                                      fontSize: 11,
                                      background: "var(--bg-secondary)",
                                      border: "1px solid var(--border)",
                                      color: "var(--text-secondary)",
                                      padding: "3px 8px",
                                      borderRadius: 6,
                                      display: "inline-flex",
                                      alignItems: "center",
                                      gap: 4,
                                    }}
                                  >
                                    <span style={{ color: "#38bdf8" }}>•</span>
                                    <span>{lang === "ar" ? mod.nameAr : mod.nameEn}</span>
                                    <span style={{ color: "var(--text-muted)", fontSize: 10 }}>
                                      ({modActiveCount}/{mod.actions.length})
                                    </span>
                                  </span>
                                );
                              })
                            )}
                            {activeModules.length > 5 && (
                              <span
                                style={{
                                  fontSize: 11,
                                  background: "rgba(255,255,255,0.06)",
                                  color: "var(--text-muted)",
                                  padding: "3px 8px",
                                  borderRadius: 6,
                                }}
                              >
                                +{activeModules.length - 5} {lang === "ar" ? "أقسام أخرى" : "more"}
                              </span>
                            )}
                          </div>
                        </div>
                      </td>

                      {/* Status */}
                      <td>
                        <span className={`badge ${admin.is_active ? "badge-success" : "badge-inactive"}`}>
                          {admin.is_active ? t("active") : t("inactive")}
                        </span>
                      </td>

                      {/* Actions */}
                      <td style={{ textAlign: "right" }}>
                        <div style={{ display: "inline-flex", gap: 8 }}>
                          <button
                            className="btn btn-ghost btn-sm"
                            onClick={() => openEditModal(admin)}
                            title={lang === "ar" ? "تعديل الصلاحيات الشاملة" : "Configure Granular Permissions"}
                            style={{
                              display: "flex",
                              alignItems: "center",
                              gap: 6,
                              background: "rgba(59, 130, 246, 0.1)",
                              color: "#60a5fa",
                              border: "1px solid rgba(59, 130, 246, 0.25)",
                              padding: "6px 12px",
                              borderRadius: 8,
                            }}
                          >
                            <SlidersHorizontal size={14} />
                            <span style={{ fontWeight: 600 }}>
                              {lang === "ar" ? "تعديل الصلاحيات" : "Permissions"}
                            </span>
                          </button>
                          <button
                            className="btn btn-ghost btn-icon btn-sm"
                            style={{
                              color: "var(--danger)",
                              background: "rgba(239, 68, 68, 0.1)",
                              border: "1px solid rgba(239, 68, 68, 0.2)",
                              borderRadius: 8,
                            }}
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

      {/* ─────────────────────────────────────────────────────────────
          LARGE COMPREHENSIVE PERMISSIONS MODAL
      ───────────────────────────────────────────────────────────── */}
      {isModalOpen && (
        <div
          className="modal-overlay"
          onClick={(e) => {
            if (e.target === e.currentTarget && !isSubmitting) {
              setIsModalOpen(false);
            }
          }}
          style={{
            backdropFilter: "blur(8px)",
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 16,
          }}
        >
          <div
            className="modal"
            style={{
              maxWidth: 1140,
              width: "95vw",
              height: "90vh",
              maxHeight: "92vh",
              display: "flex",
              flexDirection: "column",
              padding: 0,
              borderRadius: 18,
              border: "1px solid var(--border-light)",
              backgroundColor: "#111422",
              boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.7)",
              overflow: "hidden",
            }}
          >
            {/* Modal Header */}
            <div
              style={{
                padding: "20px 24px",
                borderBottom: "1px solid var(--border)",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                backgroundColor: "#161a2e",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <div
                  style={{
                    width: 42,
                    height: 42,
                    borderRadius: 12,
                    background: "linear-gradient(135deg, #3b82f6, #8b5cf6)",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    color: "white",
                  }}
                >
                  <Shield size={22} />
                </div>
                <div>
                  <h3 style={{ fontSize: 18, fontWeight: 700, margin: 0, color: "var(--text-primary)" }}>
                    {modalMode === "create"
                      ? lang === "ar"
                        ? "إضافة حساب مشرف فرعي وتحديد الصلاحيات"
                        : "Create Sub-Admin & Configure Access Matrix"
                      : lang === "ar"
                      ? `تعديل صلاحيات المشرف: ${selectedSubAdmin?.name}`
                      : `Edit Sub-Admin Permissions: ${selectedSubAdmin?.name}`}
                  </h3>
                  <p style={{ fontSize: 13, color: "var(--text-secondary)", marginTop: 2, margin: 0 }}>
                    {lang === "ar"
                      ? "حدد الصفحات والعمليات الدقيقة المسموح للمشرف إدارتها داخل لوحة التحكم."
                      : "Define granular page access, CRUD actions, and functional permissions across all 12 modules."}
                  </p>
                </div>
              </div>

              {/* Header Right: Stats Badge & Close */}
              <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
                <div
                  style={{
                    background: activeCount > 0 ? "rgba(56, 189, 248, 0.12)" : "rgba(255,255,255,0.06)",
                    border: `1px solid ${activeCount > 0 ? "rgba(56, 189, 248, 0.3)" : "var(--border)"}`,
                    padding: "6px 14px",
                    borderRadius: 20,
                    fontSize: 13,
                    fontWeight: 600,
                    color: activeCount > 0 ? "#38bdf8" : "var(--text-muted)",
                    display: "flex",
                    alignItems: "center",
                    gap: 6,
                  }}
                >
                  <CheckSquare2 size={15} />
                  <span>
                    {lang === "ar"
                      ? `${activeCount} من ${allKeys.length} صلاحية مفعلة (${activeModulesCount} أقسام)`
                      : `${activeCount}/${allKeys.length} Permissions Active (${activeModulesCount}/12 Pages)`}
                  </span>
                </div>

                <button
                  type="button"
                  className="btn btn-ghost btn-icon"
                  onClick={() => setIsModalOpen(false)}
                  disabled={isSubmitting}
                  style={{ color: "var(--text-muted)" }}
                >
                  <X size={20} />
                </button>
              </div>
            </div>

            {/* Presets & Filter Toolbar */}
            <div
              style={{
                padding: "14px 24px",
                borderBottom: "1px solid var(--border)",
                backgroundColor: "#131728",
                display: "flex",
                flexWrap: "wrap",
                gap: 12,
                alignItems: "center",
                justifyContent: "space-between",
              }}
            >
              {/* Presets Chips */}
              <div style={{ display: "flex", flexWrap: "wrap", alignItems: "center", gap: 8 }}>
                <span
                  style={{
                    fontSize: 12,
                    fontWeight: 600,
                    color: "var(--text-muted)",
                    display: "flex",
                    alignItems: "center",
                    gap: 4,
                  }}
                >
                  <Sparkles size={14} style={{ color: "#f59e0b" }} />
                  {lang === "ar" ? "قوالب سريعة:" : "Quick Presets:"}
                </span>

                {PERMISSION_PRESETS.map((preset) => (
                  <button
                    key={preset.id}
                    type="button"
                    onClick={() => applyPreset(preset.keys)}
                    style={{
                      background: "rgba(255, 255, 255, 0.05)",
                      border: "1px solid rgba(255, 255, 255, 0.1)",
                      color: "var(--text-primary)",
                      padding: "5px 12px",
                      borderRadius: 20,
                      fontSize: 12,
                      fontWeight: 500,
                      cursor: "pointer",
                      transition: "all 0.2s",
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.borderColor = "#38bdf8";
                      e.currentTarget.style.background = "rgba(56, 189, 248, 0.1)";
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.borderColor = "rgba(255, 255, 255, 0.1)";
                      e.currentTarget.style.background = "rgba(255, 255, 255, 0.05)";
                    }}
                  >
                    {lang === "ar" ? preset.nameAr : preset.nameEn}
                  </button>
                ))}

                <button
                  type="button"
                  onClick={selectAllPermissions}
                  style={{
                    background: "rgba(34, 197, 94, 0.1)",
                    border: "1px solid rgba(34, 197, 94, 0.3)",
                    color: "#22c55e",
                    padding: "5px 12px",
                    borderRadius: 20,
                    fontSize: 12,
                    fontWeight: 600,
                    cursor: "pointer",
                  }}
                >
                  {lang === "ar" ? "تحديد الكل" : "Select All"}
                </button>

                <button
                  type="button"
                  onClick={clearAllPermissions}
                  style={{
                    background: "rgba(239, 68, 68, 0.1)",
                    border: "1px solid rgba(239, 68, 68, 0.25)",
                    color: "#ef4444",
                    padding: "5px 12px",
                    borderRadius: 20,
                    fontSize: 12,
                    fontWeight: 500,
                    cursor: "pointer",
                  }}
                >
                  {lang === "ar" ? "إلغاء التحديد" : "Clear All"}
                </button>
              </div>

              {/* Search Filter Input */}
              <div
                style={{
                  position: "relative",
                  minWidth: 260,
                  flexGrow: 1,
                  maxWidth: 360,
                }}
              >
                <Search
                  size={15}
                  style={{
                    position: "absolute",
                    top: "50%",
                    transform: "translateY(-50%)",
                    left: lang === "ar" ? "auto" : 12,
                    right: lang === "ar" ? 12 : "auto",
                    color: "var(--text-muted)",
                  }}
                />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder={
                    lang === "ar"
                      ? "تصفية الصلاحيات أو الأقسام..."
                      : "Search modules or actions..."
                  }
                  style={{
                    width: "100%",
                    background: "#0c0e18",
                    border: "1px solid var(--border)",
                    borderRadius: 10,
                    padding: lang === "ar" ? "7px 34px 7px 12px" : "7px 12px 7px 34px",
                    fontSize: 13,
                    color: "var(--text-primary)",
                    outline: "none",
                  }}
                />
                {searchQuery && (
                  <button
                    type="button"
                    onClick={() => setSearchQuery("")}
                    style={{
                      position: "absolute",
                      top: "50%",
                      transform: "translateY(-50%)",
                      right: lang === "ar" ? "auto" : 10,
                      left: lang === "ar" ? 10 : "auto",
                      background: "transparent",
                      border: "none",
                      color: "var(--text-muted)",
                      cursor: "pointer",
                    }}
                  >
                    <X size={14} />
                  </button>
                )}
              </div>
            </div>

            {/* Modal Body (Scrollable) */}
            <form
              id="subadmin-permissions-form"
              onSubmit={handleSubmit}
              style={{
                flex: 1,
                overflowY: "auto",
                padding: "20px 24px",
                display: "flex",
                flexDirection: "column",
                gap: 20,
              }}
            >
              {/* If Create Mode: Account Info Inputs */}
              {modalMode === "create" && (
                <div
                  style={{
                    background: "rgba(255, 255, 255, 0.03)",
                    border: "1px solid var(--border)",
                    borderRadius: 14,
                    padding: 18,
                  }}
                >
                  <div
                    style={{
                      fontSize: 14,
                      fontWeight: 700,
                      marginBottom: 12,
                      color: "#38bdf8",
                      display: "flex",
                      alignItems: "center",
                      gap: 6,
                    }}
                  >
                    <Lock size={16} />
                    <span>{lang === "ar" ? "بيانات تسجيل الدخول للمشرف" : "Supervisor Account Details"}</span>
                  </div>

                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
                      gap: 14,
                    }}
                  >
                    <div className="form-group" style={{ margin: 0 }}>
                      <label className="form-label" style={{ fontSize: 12, fontWeight: 600 }}>
                        {lang === "ar" ? "الاسم الكامل *" : "Full Name *"}
                      </label>
                      <input
                        required
                        className="input"
                        value={formName}
                        onChange={(e) => setFormName(e.target.value)}
                        placeholder={lang === "ar" ? "مثال: عبد الله سالم" : "e.g. John Doe"}
                        style={{ height: 40 }}
                      />
                    </div>

                    <div className="form-group" style={{ margin: 0 }}>
                      <label className="form-label" style={{ fontSize: 12, fontWeight: 600 }}>
                        {t("email")} *
                      </label>
                      <input
                        required
                        type="email"
                        className="input"
                        value={formEmail}
                        onChange={(e) => setFormEmail(e.target.value)}
                        placeholder="supervisor@example.com"
                        style={{ height: 40 }}
                      />
                    </div>

                    <div className="form-group" style={{ margin: 0 }}>
                      <label className="form-label" style={{ fontSize: 12, fontWeight: 600 }}>
                        {t("password")} *
                      </label>
                      <input
                        required
                        type="password"
                        className="input"
                        value={formPassword}
                        onChange={(e) => setFormPassword(e.target.value)}
                        placeholder="••••••••••••"
                        style={{ height: 40 }}
                      />
                    </div>
                  </div>
                </div>
              )}

              {/* If Edit Mode: Account Details Banner */}
              {modalMode === "edit" && selectedSubAdmin && (
                <div
                  style={{
                    background: "rgba(59, 130, 246, 0.05)",
                    border: "1px solid rgba(59, 130, 246, 0.2)",
                    borderRadius: 14,
                    padding: "14px 18px",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    flexWrap: "wrap",
                    gap: 12,
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                    <div
                      className="avatar"
                      style={{
                        width: 44,
                        height: 44,
                        fontSize: 15,
                        fontWeight: 700,
                        background: "linear-gradient(135deg, #1e293b, #334155)",
                        color: "#38bdf8",
                        border: "1px solid rgba(56, 189, 248, 0.3)",
                      }}
                    >
                      {initials(selectedSubAdmin.name)}
                    </div>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: 15, color: "var(--text-primary)" }}>
                        {selectedSubAdmin.name}
                      </div>
                      <div style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                        {selectedSubAdmin.email}
                      </div>
                    </div>
                  </div>

                  <div style={{ display: "flex", gap: 8 }}>
                    <span
                      className="badge"
                      style={{
                        background: "rgba(99, 102, 241, 0.15)",
                        color: "#818cf8",
                        border: "1px solid rgba(99, 102, 241, 0.3)",
                      }}
                    >
                      {t("subAdminBadge")}
                    </span>
                    <span className={`badge ${selectedSubAdmin.is_active ? "badge-success" : "badge-inactive"}`}>
                      {selectedSubAdmin.is_active ? t("active") : t("inactive")}
                    </span>
                  </div>
                </div>
              )}

              {/* Modules & Granular Actions Grid */}
              <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
                {filteredModules.length === 0 ? (
                  <div
                    style={{
                      padding: 40,
                      textAlign: "center",
                      color: "var(--text-muted)",
                      background: "rgba(255,255,255,0.02)",
                      borderRadius: 12,
                      border: "1px dashed var(--border)",
                    }}
                  >
                    {lang === "ar" ? "لا توجد نتائج مطابقة لبحثك" : "No permissions matching your filter"}
                  </div>
                ) : (
                  filteredModules.map((module) => {
                    const IconComponent = MODULE_ICONS[module.iconName] || Layers;
                    const moduleKeys = module.actions.map((a) => a.key);
                    const activeCountInModule = moduleKeys.filter((k) => !!permsState[k]).length;
                    const isAllModuleActive = activeCountInModule === module.actions.length;
                    const isAnyModuleActive = activeCountInModule > 0;
                    const isViewActive = !!permsState[module.viewPermissionKey];

                    return (
                      <div
                        key={module.id}
                        style={{
                          background: isAnyModuleActive ? "#15192c" : "#121420",
                          border: `1px solid ${
                            isAnyModuleActive ? "rgba(59, 130, 246, 0.35)" : "var(--border)"
                          }`,
                          borderRadius: 14,
                          overflow: "hidden",
                          transition: "all 0.2s ease",
                        }}
                      >
                        {/* Module Card Header */}
                        <div
                          style={{
                            padding: "14px 18px",
                            background: isAnyModuleActive ? "rgba(59, 130, 246, 0.08)" : "rgba(255,255,255,0.02)",
                            borderBottom: "1px solid var(--border)",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "space-between",
                            flexWrap: "wrap",
                            gap: 10,
                          }}
                        >
                          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                            <div
                              style={{
                                width: 34,
                                height: 34,
                                borderRadius: 8,
                                background: isAnyModuleActive
                                  ? "linear-gradient(135deg, #3b82f6, #6366f1)"
                                  : "rgba(255,255,255,0.06)",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                color: isAnyModuleActive ? "white" : "var(--text-muted)",
                              }}
                            >
                              <IconComponent size={18} />
                            </div>

                            <div>
                              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                                <span
                                  style={{
                                    fontWeight: 700,
                                    fontSize: 14,
                                    color: isAnyModuleActive ? "var(--text-primary)" : "var(--text-secondary)",
                                  }}
                                >
                                  {lang === "ar" ? module.nameAr : module.nameEn}
                                </span>
                                <span
                                  style={{
                                    fontSize: 11,
                                    padding: "2px 8px",
                                    borderRadius: 12,
                                    fontWeight: 600,
                                    background: isAllModuleActive
                                      ? "rgba(34, 197, 94, 0.15)"
                                      : isAnyModuleActive
                                      ? "rgba(59, 130, 246, 0.15)"
                                      : "rgba(255,255,255,0.05)",
                                    color: isAllModuleActive
                                      ? "#22c55e"
                                      : isAnyModuleActive
                                      ? "#60a5fa"
                                      : "var(--text-muted)",
                                    border: `1px solid ${
                                      isAllModuleActive
                                        ? "rgba(34, 197, 94, 0.3)"
                                        : isAnyModuleActive
                                        ? "rgba(59, 130, 246, 0.3)"
                                        : "transparent"
                                    }`,
                                  }}
                                >
                                  {activeCountInModule}/{module.actions.length} {lang === "ar" ? "مفعل" : "active"}
                                </span>
                              </div>
                              <p style={{ fontSize: 12, color: "var(--text-muted)", margin: "2px 0 0" }}>
                                {lang === "ar" ? module.descriptionAr : module.descriptionEn}
                              </p>
                            </div>
                          </div>

                          {/* Module Quick Toggle Button */}
                          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                            <button
                              type="button"
                              onClick={() => toggleModuleAll(module)}
                              style={{
                                background: isAllModuleActive
                                  ? "rgba(239, 68, 68, 0.1)"
                                  : "rgba(59, 130, 246, 0.12)",
                                border: `1px solid ${
                                  isAllModuleActive ? "rgba(239, 68, 68, 0.25)" : "rgba(59, 130, 246, 0.3)"
                                }`,
                                color: isAllModuleActive ? "#f87171" : "#60a5fa",
                                padding: "4px 10px",
                                borderRadius: 8,
                                fontSize: 12,
                                fontWeight: 600,
                                cursor: "pointer",
                                display: "flex",
                                alignItems: "center",
                                gap: 6,
                              }}
                            >
                              <span>
                                {isAllModuleActive
                                  ? lang === "ar"
                                    ? "إلغاء تحديد القسم"
                                    : "Deselect Page"
                                  : lang === "ar"
                                  ? "تحديد الكل لهذه الصفحة"
                                  : "Select All on Page"}
                              </span>
                            </button>
                          </div>
                        </div>

                        {/* Actions List Grid */}
                        <div
                          style={{
                            padding: "14px 16px",
                            display: "grid",
                            gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
                            gap: 10,
                          }}
                        >
                          {module.actions.map((action) => {
                            const isChecked = !!permsState[action.key];

                            return (
                              <label
                                key={action.key}
                                onClick={(e) => {
                                  // Prevent standard label double-trigger
                                  e.preventDefault();
                                  toggleAction(module, action);
                                }}
                                style={{
                                  display: "flex",
                                  alignItems: "flex-start",
                                  gap: 12,
                                  padding: "10px 14px",
                                  borderRadius: 10,
                                  cursor: "pointer",
                                  userSelect: "none",
                                  transition: "all 0.15s ease",
                                  background: isChecked ? "rgba(59, 130, 246, 0.1)" : "rgba(255, 255, 255, 0.02)",
                                  border: `1px solid ${
                                    isChecked ? "rgba(59, 130, 246, 0.4)" : "rgba(255, 255, 255, 0.05)"
                                  }`,
                                }}
                              >
                                {/* Custom Styled Checkbox */}
                                <div
                                  style={{
                                    width: 20,
                                    height: 20,
                                    borderRadius: 5,
                                    border: `2px solid ${isChecked ? "#3b82f6" : "var(--border-light)"}`,
                                    background: isChecked ? "#3b82f6" : "rgba(0, 0, 0, 0.2)",
                                    display: "flex",
                                    alignItems: "center",
                                    justifyContent: "center",
                                    color: "white",
                                    flexShrink: 0,
                                    marginTop: 2,
                                    transition: "all 0.15s ease",
                                  }}
                                >
                                  {isChecked && <Check size={14} strokeWidth={3} />}
                                </div>

                                <div style={{ flex: 1 }}>
                                  <div style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap" }}>
                                    <span
                                      style={{
                                        fontSize: 13,
                                        fontWeight: 600,
                                        color: isChecked ? "var(--text-primary)" : "var(--text-secondary)",
                                      }}
                                    >
                                      {lang === "ar" ? action.labelAr : action.labelEn}
                                    </span>

                                    {action.isViewAction && (
                                      <span
                                        style={{
                                          fontSize: 10,
                                          background: "rgba(168, 85, 247, 0.15)",
                                          color: "#c084fc",
                                          border: "1px solid rgba(168, 85, 247, 0.3)",
                                          padding: "1px 6px",
                                          borderRadius: 4,
                                          fontWeight: 600,
                                        }}
                                      >
                                        {lang === "ar" ? "رؤية الصفحة" : "Page View"}
                                      </span>
                                    )}
                                  </div>

                                  <div
                                    style={{
                                      fontSize: 11,
                                      color: "var(--text-muted)",
                                      marginTop: 2,
                                      lineHeight: 1.4,
                                    }}
                                  >
                                    {lang === "ar" ? action.descAr : action.descEn}
                                  </div>
                                </div>
                              </label>
                            );
                          })}
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </form>

            {/* Modal Sticky Footer */}
            <div
              style={{
                padding: "16px 24px",
                borderTop: "1px solid var(--border)",
                backgroundColor: "#161a2e",
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                flexWrap: "wrap",
                gap: 12,
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                  {lang === "ar"
                    ? `الإجمالي المحدد: ${activeCount} صلاحية موزعة على ${activeModulesCount} صفحة`
                    : `Selection Summary: ${activeCount} actions across ${activeModulesCount} pages`}
                </span>
              </div>

              <div style={{ display: "flex", gap: 10 }}>
                <button
                  type="button"
                  className="btn btn-ghost"
                  onClick={() => setIsModalOpen(false)}
                  disabled={isSubmitting}
                  style={{ padding: "8px 18px" }}
                >
                  {t("cancel")}
                </button>
                <button
                  type="submit"
                  form="subadmin-permissions-form"
                  className="btn btn-primary"
                  disabled={isSubmitting}
                  style={{
                    padding: "8px 24px",
                    fontWeight: 600,
                    boxShadow: "0 4px 14px rgba(59, 130, 246, 0.35)",
                    display: "flex",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  {isSubmitting ? (
                    <div className="spinner" style={{ width: 16, height: 16 }} />
                  ) : (
                    <>
                      <Check size={16} />
                      <span>
                        {modalMode === "create"
                          ? lang === "ar"
                            ? "إنشاء المشرف وتطبيق الصلاحيات"
                            : "Create Sub-Admin"
                          : lang === "ar"
                          ? "حفظ وتطبيق الصلاحيات"
                          : "Save Permissions"}
                      </span>
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}