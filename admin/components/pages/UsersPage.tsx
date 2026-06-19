"use client";

import { useEffect, useState, useCallback } from "react";
import { Search, Plus, Pencil, Trash2, UserCheck, UserX, RefreshCw } from "lucide-react";
import { adminApi, AdminUser } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

export default function UsersPage() {
  const { t } = useLang();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [editUser, setEditUser] = useState<AdminUser | null>(null);
  const [editRole, setEditRole] = useState("");
  const [editCredit, setEditCredit] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const LIMIT = 15;

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.listUsers({ page, limit: LIMIT, search: search || undefined, role: roleFilter || undefined });
      setUsers(res.users);
      setTotal(res.total);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [page, search, roleFilter, t]);

  useEffect(() => { load(); }, [load]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setPage(1);
    load();
  };

  const handleToggleActive = async (user: AdminUser) => {
    try {
      await adminApi.updateUser(user.id, { is_active: !user.is_active });
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm(t("deleteUserConfirm"))) return;
    try {
      await adminApi.deleteUser(id);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToDelete"));
    }
  };

  const handleEditSubmit = async () => {
    if (!editUser) return;
    setSaving(true);
    try {
      await adminApi.updateUser(editUser.id, {
        role: editRole,
        credit_balance: parseFloat(editCredit) || 0,
      });
      setEditUser(null);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSaving(false);
    }
  };

  const totalPages = Math.ceil(total / LIMIT);
  const initials = (name: string) => name?.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "?";

  return (
    <div>
      {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

      {/* Header */}
      <div className="section-header">
        <form onSubmit={handleSearch} className="search-bar">
          <Search size={16} />
          <input
            id="user-search"
            placeholder={t("searchUsersPlaceholder")}
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1); }}
          />
        </form>

        <select
          id="user-role-filter"
          className="input"
          style={{ width: "auto", minWidth: 140 }}
          value={roleFilter}
          onChange={e => { setRoleFilter(e.target.value); setPage(1); }}
        >
          <option value="">{t("allRoles")}</option>
          <option value="customer">{t("customerRole")}</option>
          <option value="seller">{t("sellerRole")}</option>
          <option value="admin">{t("adminRole")}</option>
        </select>

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
                <th>{t("user")}</th>
                <th>{t("role")}</th>
                <th>{t("status")}</th>
                <th>{t("verified")}</th>
                <th>{t("credit")}</th>
                <th>{t("joined")}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr><td colSpan={7} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>{t("noUsersFound")}</td></tr>
              ) : users.map(user => (
                <tr key={user.id}>
                  <td>
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div className="avatar">{initials(user.name)}</div>
                      <div>
                        <div style={{ fontWeight: 500 }}>{user.name}</div>
                        <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{user.email}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span className={`badge badge-${user.role}`}>
                      {t((user.role + "Role") as any)}
                    </span>
                  </td>
                  <td>
                    <span className={`badge ${user.is_active ? "badge-active" : "badge-inactive"}`}>
                      {user.is_active ? t("active") : t("inactive")}
                    </span>
                  </td>
                  <td>
                    <span className={`badge ${user.is_verified ? "badge-active" : "badge-inactive"}`}>
                      {user.is_verified ? t("verified") : t("unverified")}
                    </span>
                  </td>
                  <td style={{ fontWeight: 500 }}>﷼ {user.credit_balance.toFixed(2)}</td>
                  <td style={{ color: "var(--text-secondary)", fontSize: 13 }}>
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                  <td>
                    <div style={{ display: "flex", gap: 6 }}>
                      <button
                        id={`edit-user-${user.id}`}
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={() => { setEditUser(user); setEditRole(user.role); setEditCredit(String(user.credit_balance)); }}
                        title={t("edit")}
                      >
                        <Pencil size={14} />
                      </button>
                      <button
                        id={`toggle-user-${user.id}`}
                        className={`btn btn-icon btn-sm ${user.is_active ? "btn-danger" : "btn-ghost"}`}
                        onClick={() => handleToggleActive(user)}
                        title={user.is_active ? t("deactivate") : t("activate")}
                      >
                        {user.is_active ? <UserX size={14} /> : <UserCheck size={14} />}
                      </button>
                      <button
                        id={`delete-user-${user.id}`}
                        className="btn btn-danger btn-icon btn-sm"
                        onClick={() => handleDelete(user.id)}
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

      {/* Edit modal */}
      {editUser && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setEditUser(null)}>
          <div className="modal">
            <div className="modal-title">{t("editUserTitle")} — {editUser.name}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
              <div className="form-group">
                <label className="form-label">{t("role")}</label>
                <select id="edit-role" className="input" value={editRole} onChange={e => setEditRole(e.target.value)}>
                  <option value="customer">{t("customerRole")}</option>
                  <option value="seller">{t("sellerRole")}</option>
                  <option value="admin">{t("adminRole")}</option>
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">{t("creditBalance")}</label>
                <input
                  id="edit-credit"
                  type="number"
                  step="0.01"
                  className="input"
                  value={editCredit}
                  onChange={e => setEditCredit(e.target.value)}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setEditUser(null)}>{t("cancel")}</button>
              <button id="save-user" className="btn btn-primary" onClick={handleEditSubmit} disabled={saving}>
                {saving ? <div className="spinner" /> : t("saveChanges")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
