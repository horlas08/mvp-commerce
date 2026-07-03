"use client";

import { useEffect, useState, useCallback } from "react";
import { Search, Pencil, Trash2, UserCheck, UserX, RefreshCw, Wallet, History } from "lucide-react";
import { adminApi, AdminUser, WalletTransaction } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

export default function UsersPage() {
  const { t, lang } = useLang();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Edit user state
  const [editUser, setEditUser] = useState<AdminUser | null>(null);
  const [editRole, setEditRole] = useState("");
  const [saving, setSaving] = useState(false);

  // Wallet adjustment state
  const [adjustingUser, setAdjustingUser] = useState<AdminUser | null>(null);
  const [adjustAmount, setAdjustAmount] = useState("");
  const [adjustType, setAdjustType] = useState<"credit" | "debit">("credit");
  const [adjustReason, setAdjustReason] = useState("");
  const [submittingAdjust, setSubmittingAdjust] = useState(false);

  // Ledger state
  const [ledgerUser, setLedgerUser] = useState<AdminUser | null>(null);
  const [transactions, setTransactions] = useState<WalletTransaction[]>([]);
  const [loadingLedger, setLoadingLedger] = useState(false);
  const [ledgerPage, setLedgerPage] = useState(1);
  const [ledgerTotal, setLedgerTotal] = useState(0);
  const ledgerLimit = 10;

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

  // Load wallet transactions
  const loadLedger = useCallback(async () => {
    if (!ledgerUser) return;
    setLoadingLedger(true);
    try {
      const res = await adminApi.listWalletTransactions(ledgerUser.id, {
        page: ledgerPage,
        limit: ledgerLimit,
      });
      setTransactions(res.transactions);
      setLedgerTotal(res.total);
    } catch (err: any) {
      alert("Failed to load transactions ledger: " + err.message);
    } finally {
      setLoadingLedger(false);
    }
  }, [ledgerUser, ledgerPage]);

  useEffect(() => {
    if (ledgerUser) {
      loadLedger();
    }
  }, [ledgerUser, ledgerPage, loadLedger]);

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
    if (!confirm(t("confirmDelete"))) return;
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
      await adminApi.updateUser(editUser.id, { role: editRole });
      setEditUser(null);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setSaving(false);
    }
  };

  const handleAdjustWalletSubmit = async () => {
    if (!adjustingUser || !adjustAmount || !adjustReason.trim()) return;
    const amt = parseFloat(adjustAmount);
    if (isNaN(amt) || amt <= 0) {
      alert("Please enter a positive amount");
      return;
    }
    setSubmittingAdjust(true);
    try {
      await adminApi.adjustUserWallet(adjustingUser.id, amt, adjustType, adjustReason.trim());
      setAdjustingUser(null);
      setAdjustAmount("");
      setAdjustReason("");
      load();
    } catch (err: any) {
      alert(err.message || "Failed to adjust wallet balance");
    } finally {
      setSubmittingAdjust(false);
    }
  };

  const totalPages = Math.ceil(total / LIMIT);
  const initials = (name: string) => name?.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "?";

  return (
    <div>
      {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

      {/* Header */}
      <div className="section-header" style={{ display: "flex", gap: 16, flexWrap: "wrap", alignItems: "center", justifyContent: "space-between" }}>
        <form onSubmit={handleSearch} className="search-bar" style={{ flex: 1, minWidth: 280 }}>
          <Search size={16} />
          <input
            id="user-search"
            placeholder={t("searchUsersPlaceholder")}
            value={search}
            onChange={e => { setSearch(e.target.value); setPage(1); }}
          />
        </form>

        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
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
                <th>{t("walletBalance")}</th>
                <th>{lang === "ar" ? "الانضمام" : "Joined"}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
                    {lang === "ar" ? "لا يوجد مستخدمين" : "No users found"}
                  </td>
                </tr>
              ) : users.map(user => (
                <tr key={user.id}>
                  <td>
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <div className="avatar">{initials(user.name)}</div>
                      <div>
                        <div style={{ fontWeight: 600 }}>{user.name}</div>
                        <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{user.email}</div>
                        {user.phone && <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 2 }}>{user.phone}</div>}
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
                  <td style={{ fontWeight: 600 }}>﷼ {user.credit_balance.toFixed(2)}</td>
                  <td style={{ color: "var(--text-secondary)", fontSize: 13 }}>
                    {new Date(user.created_at).toLocaleDateString(lang === "ar" ? "ar-EG" : "en-US")}
                  </td>
                  <td>
                    <div style={{ display: "flex", gap: 6 }}>
                      <button
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={() => { setEditUser(user); setEditRole(user.role); }}
                        title={t("edit")}
                      >
                        <Pencil size={13} />
                      </button>
                      <button
                        className="btn btn-ghost btn-icon btn-sm"
                        style={{ color: "var(--accent-light)" }}
                        onClick={() => {
                          setAdjustingUser(user);
                          setAdjustAmount("");
                          setAdjustReason("");
                          setAdjustType("credit");
                        }}
                        title={t("adjustWallet")}
                      >
                        <Wallet size={13} />
                      </button>
                      <button
                        className="btn btn-ghost btn-icon btn-sm"
                        style={{ color: "var(--info)" }}
                        onClick={() => {
                          setLedgerUser(user);
                          setTransactions([]);
                          setLedgerPage(1);
                        }}
                        title={t("walletLedger")}
                      >
                        <History size={13} />
                      </button>
                      <button
                        className={`btn btn-icon btn-sm ${user.is_active ? "btn-danger" : "btn-ghost"}`}
                        onClick={() => handleToggleActive(user)}
                        title={user.is_active ? t("deactivate") : t("activate")}
                      >
                        {user.is_active ? <UserX size={13} /> : <UserCheck size={13} />}
                      </button>
                      <button
                        className="btn btn-danger btn-icon btn-sm"
                        onClick={() => handleDelete(user.id)}
                        title={t("delete")}
                      >
                        <Trash2 size={13} />
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
          {Array.from({ length: totalPages }, (_, i) => i + 1).map(p => (
            <button key={p} className={`pagination-btn${page === p ? " active" : ""}`} onClick={() => setPage(p)}>{p}</button>
          ))}
          <button className="pagination-btn" disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}>{t("next")}</button>
        </div>
      )}

      {/* Edit Role Modal */}
      {editUser && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setEditUser(null)}>
          <div className="modal">
            <div className="modal-title">{t("editUserTitle" as any) || t("edit")} — {editUser.name}</div>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="form-group">
                <label className="form-label">{t("role")}</label>
                <select className="input" value={editRole} onChange={e => setEditRole(e.target.value)}>
                  <option value="customer">{t("customerRole")}</option>
                  <option value="seller">{t("sellerRole")}</option>
                  <option value="admin">{t("adminRole")}</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setEditUser(null)}>{t("cancel")}</button>
              <button className="btn btn-primary" onClick={handleEditSubmit} disabled={saving}>
                {saving ? <div className="spinner" /> : t("saveChanges")}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Adjust Wallet Balance Modal */}
      {adjustingUser && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setAdjustingUser(null)}>
          <div className="modal">
            <div className="modal-title">{t("adjustWalletTitle")}</div>
            <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 16 }}>
              {lang === "ar"
                ? `تعديل رصيد العميل: ${adjustingUser.name} (الرصيد الحالي: ${adjustingUser.credit_balance.toFixed(2)} SAR)`
                : `Adjusting balance for: ${adjustingUser.name} (Current balance: ${adjustingUser.credit_balance.toFixed(2)} SAR)`}
            </p>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="form-group">
                <label className="form-label">{t("adjustmentType")}</label>
                <div style={{ display: "flex", gap: 16, marginTop: 4 }}>
                  <label style={{ display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
                    <input
                      type="radio"
                      name="adjType"
                      checked={adjustType === "credit"}
                      onChange={() => setAdjustType("credit")}
                    />
                    <span>{t("creditOption")}</span>
                  </label>
                  <label style={{ display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
                    <input
                      type="radio"
                      name="adjType"
                      checked={adjustType === "debit"}
                      onChange={() => setAdjustType("debit")}
                    />
                    <span>{t("debitOption")}</span>
                  </label>
                </div>
              </div>
              <div className="form-group">
                <label className="form-label">{t("amount")} (SAR)</label>
                <input
                  type="number"
                  step="0.01"
                  min="0.01"
                  className="input"
                  value={adjustAmount}
                  onChange={e => setAdjustAmount(e.target.value)}
                  placeholder="100.00"
                />
              </div>
              <div className="form-group">
                <label className="form-label">{lang === "ar" ? "سبب التعديل" : "Reason for Adjustment"}</label>
                <input
                  type="text"
                  className="input"
                  value={adjustReason}
                  onChange={e => setAdjustReason(e.target.value)}
                  placeholder={t("reasonPlaceholder")}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setAdjustingUser(null)}>{t("cancel")}</button>
              <button
                className="btn btn-primary"
                onClick={handleAdjustWalletSubmit}
                disabled={submittingAdjust}
              >
                {submittingAdjust ? <div className="spinner" /> : t("submit")}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Wallet Ledger Modal */}
      {ledgerUser && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setLedgerUser(null)}>
          <div className="modal" style={{ maxWidth: 640 }}>
            <div className="modal-title">{t("walletLedger")} — {ledgerUser.name}</div>
            {loadingLedger && transactions.length === 0 ? (
              <div style={{ display: "flex", justifyContent: "center", padding: 40 }}>
                <div className="spinner" style={{ width: 32, height: 32, borderWidth: 3 }} />
              </div>
            ) : transactions.length === 0 ? (
              <div style={{ textAlign: "center", padding: 30, color: "var(--text-muted)" }}>
                {lang === "ar" ? "لا توجد معاملات رصيد مسجلة" : "No balance transactions logged."}
              </div>
            ) : (
              <div>
                <div className="table-container" style={{ border: "1px solid var(--border)", borderRadius: 10, overflowX: "auto" }}>
                  <table style={{ fontSize: 13 }}>
                    <thead>
                      <tr>
                        <th>{t("amount")}</th>
                        <th>{lang === "ar" ? "النوع" : "Type"}</th>
                        <th>{lang === "ar" ? "السبب" : "Reason"}</th>
                        <th>{lang === "ar" ? "الرصيد بعد" : "Balance After"}</th>
                        <th>{t("date")}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {transactions.map(tx => (
                        <tr key={tx.id}>
                          <td style={{
                            fontWeight: 600,
                            color: tx.type === "credit" ? "var(--success)" : "var(--danger)"
                          }}>
                            {tx.type === "credit" ? "+" : "-"}{tx.amount.toFixed(2)} SAR
                          </td>
                          <td>
                            <span className={`badge ${tx.type === "credit" ? "badge-active" : "badge-inactive"}`} style={{ fontSize: 11 }}>
                              {t(tx.type as any)}
                            </span>
                          </td>
                          <td>
                            <div style={{ maxWidth: 160, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }} title={tx.reason}>
                              {tx.reason}
                            </div>
                          </td>
                          <td style={{ fontWeight: 500 }}>{tx.balance_after.toFixed(2)} SAR</td>
                          <td style={{ fontSize: 11, color: "var(--text-muted)" }}>
                            {new Date(tx.created_at).toLocaleDateString()}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Ledger Pagination */}
                {ledgerTotal > ledgerLimit && (
                  <div className="pagination" style={{ marginTop: 16 }}>
                    <button
                      className="pagination-btn"
                      disabled={ledgerPage === 1}
                      onClick={() => setLedgerPage(p => p - 1)}
                    >
                      {t("prev")}
                    </button>
                    <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
                      {ledgerPage} / {Math.ceil(ledgerTotal / ledgerLimit)}
                    </span>
                    <button
                      className="pagination-btn"
                      disabled={ledgerPage * ledgerLimit >= ledgerTotal}
                      onClick={() => setLedgerPage(p => p + 1)}
                    >
                      {t("next")}
                    </button>
                  </div>
                )}
              </div>
            )}
            <div className="modal-footer" style={{ marginTop: 16, paddingTop: 12 }}>
              <button className="btn btn-ghost" onClick={() => setLedgerUser(null)}>{t("close")}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
