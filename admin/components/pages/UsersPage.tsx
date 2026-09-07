"use client";

import { useEffect, useState, useCallback } from "react";
import { Search, Pencil, Trash2, UserCheck, UserX, RefreshCw, Wallet, History, Download, MapPin, Calendar, CheckSquare, Square } from "lucide-react";
import { adminApi, AdminUser, WalletTransaction } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

export default function UsersPage() {
  const { t, lang } = useLang();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState("");
  const [roleFilter, setRoleFilter] = useState("");
  const [governorateFilter, setGovernorateFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [governorates, setGovernorates] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [exporting, setExporting] = useState(false);

  // Multi-select state
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

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

  // Load governorates list once
  useEffect(() => {
    adminApi.listUserGovernorates()
      .then(res => setGovernorates(res || []))
      .catch(() => {});
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.listUsers({
        page,
        limit: LIMIT,
        search: search || undefined,
        role: roleFilter || undefined,
        governorate: governorateFilter || undefined,
        date_from: dateFrom || undefined,
        date_to: dateTo || undefined,
      });
      setUsers(res.users);
      setTotal(res.total);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [page, search, roleFilter, governorateFilter, dateFrom, dateTo, t]);

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
      setSelectedIds(prev => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
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

  // Selection handlers
  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedIds(new Set(users.map(u => u.id)));
    } else {
      setSelectedIds(new Set());
    }
  };

  const handleToggleSelect = (id: string) => {
    setSelectedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const allSelected = users.length > 0 && users.every(u => selectedIds.has(u.id));
  const someSelected = users.some(u => selectedIds.has(u.id)) && !allSelected;

  // Export to Excel handler
  const handleExport = async (selectedOnly = false) => {
    setExporting(true);
    try {
      const params: any = {};
      if (selectedOnly && selectedIds.size > 0) {
        params.user_ids = Array.from(selectedIds).join(",");
      } else {
        if (search) params.search = search;
        if (roleFilter) params.role = roleFilter;
        if (governorateFilter) params.governorate = governorateFilter;
        if (dateFrom) params.date_from = dateFrom;
        if (dateTo) params.date_to = dateTo;
      }
      const response = await adminApi.exportUsersExcel(params);
      if (!response.ok) {
        const text = await response.text();
        throw new Error(text || "Export failed");
      }
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `users_export_${new Date().toISOString().slice(0, 10)}.xlsx`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch (err: any) {
      alert("Export failed: " + err.message);
    } finally {
      setExporting(false);
    }
  };

  const totalPages = Math.ceil(total / LIMIT);
  const initials = (name: string) => name?.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "?";

  return (
    <div>
      {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

      {/* Header & Filters */}
      <div style={{ display: "flex", flexDirection: "column", gap: 12, marginBottom: 16 }}>
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center", justifyContent: "space-between" }}>
          {/* Search bar */}
          <form onSubmit={handleSearch} className="search-bar" style={{ flex: 1, minWidth: 260 }}>
            <Search size={16} />
            <input
              id="user-search"
              placeholder={t("searchUsersPlaceholder")}
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
            />
          </form>

          {/* Role filter */}
          <select
            id="user-role-filter"
            className="input"
            style={{ width: "auto", minWidth: 130 }}
            value={roleFilter}
            onChange={e => { setRoleFilter(e.target.value); setPage(1); }}
          >
            <option value="">{t("allRoles")}</option>
            <option value="customer">{t("customerRole")}</option>
            <option value="seller">{t("sellerRole")}</option>
            <option value="admin">{t("adminRole")}</option>
          </select>

          {/* Governorate filter */}
          <select
            id="user-governorate-filter"
            className="input"
            style={{ width: "auto", minWidth: 150 }}
            value={governorateFilter}
            onChange={e => { setGovernorateFilter(e.target.value); setPage(1); }}
          >
            <option value="">{t("allGovernorates") || (lang === "ar" ? "جميع المحافظات" : "All Governorates")}</option>
            {governorates.map(gov => (
              <option key={gov} value={gov}>{gov}</option>
            ))}
          </select>

          {/* Date range filters */}
          <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
            <input
              type="date"
              className="input"
              style={{ width: "auto", fontSize: 12, padding: "6px 10px" }}
              value={dateFrom}
              onChange={e => { setDateFrom(e.target.value); setPage(1); }}
              title={t("dateFrom") || "Date From"}
            />
            <span style={{ color: "var(--text-muted)", fontSize: 12 }}>—</span>
            <input
              type="date"
              className="input"
              style={{ width: "auto", fontSize: 12, padding: "6px 10px" }}
              value={dateTo}
              onChange={e => { setDateTo(e.target.value); setPage(1); }}
              title={t("dateTo") || "Date To"}
            />
          </div>

          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            {/* Refresh */}
            <button className="btn btn-ghost btn-icon" onClick={load} title={t("refresh")}>
              <RefreshCw size={16} />
            </button>

            {/* Export all filtered */}
            <button
              className="btn btn-secondary"
              onClick={() => handleExport(false)}
              disabled={exporting || users.length === 0}
              style={{ display: "flex", alignItems: "center", gap: 6 }}
              title={t("exportUsers") || "Export Users"}
            >
              <Download size={15} />
              <span>{exporting ? (lang === "ar" ? "جار التصدير..." : "Exporting...") : (t("exportUsers") || (lang === "ar" ? "تصدير المستخدمين" : "Export Users"))}</span>
            </button>
          </div>
        </div>

        {/* Bulk action toolbar */}
        {selectedIds.size > 0 && (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "10px 16px",
              backgroundColor: "var(--accent-subtle, rgba(99, 102, 241, 0.1))",
              border: "1px solid var(--accent, #6366f1)",
              borderRadius: 8,
              fontSize: 14,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 8, fontWeight: 500 }}>
              <CheckSquare size={18} color="var(--accent, #6366f1)" />
              <span>
                {selectedIds.size} {t("selectedCount") || (lang === "ar" ? "محدد" : "selected")}
              </span>
            </div>
            <div style={{ display: "flex", gap: 8 }}>
              <button
                className="btn btn-primary btn-sm"
                onClick={() => handleExport(true)}
                disabled={exporting}
                style={{ display: "flex", alignItems: "center", gap: 6 }}
              >
                <Download size={14} />
                <span>{t("exportSelected") || (lang === "ar" ? "تصدير المحددين" : "Export Selected")} ({selectedIds.size})</span>
              </button>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => setSelectedIds(new Set())}
              >
                {lang === "ar" ? "إلغاء التحديد" : "Deselect All"}
              </button>
            </div>
          </div>
        )}
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
                <th style={{ width: 40, textAlign: "center" }}>
                  <input
                    type="checkbox"
                    checked={allSelected}
                    ref={el => {
                      if (el) el.indeterminate = someSelected;
                    }}
                    onChange={e => handleSelectAll(e.target.checked)}
                    style={{ cursor: "pointer" }}
                    title={t("selectAll") || "Select All"}
                  />
                </th>
                <th>{t("user")}</th>
                <th>{t("role")}</th>
                <th>{t("governorate") || (lang === "ar" ? "المحافظة" : "Governorate")}</th>
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
                  <td colSpan={9} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
                    {lang === "ar" ? "لا يوجد مستخدمين" : "No users found"}
                  </td>
                </tr>
              ) : users.map(user => {
                const isSelected = selectedIds.has(user.id);
                return (
                  <tr key={user.id} style={{ backgroundColor: isSelected ? "var(--bg-highlight, rgba(99, 102, 241, 0.05))" : undefined }}>
                    <td style={{ textAlign: "center" }}>
                      <input
                        type="checkbox"
                        checked={isSelected}
                        onChange={() => handleToggleSelect(user.id)}
                        style={{ cursor: "pointer" }}
                      />
                    </td>
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
                      {user.governorate ? (
                        <span style={{ display: "inline-flex", alignItems: "center", gap: 4, fontSize: 13, color: "var(--text-primary)" }}>
                          <MapPin size={12} style={{ color: "var(--text-muted)" }} />
                          {user.governorate}
                        </span>
                      ) : (
                        <span style={{ color: "var(--text-muted)", fontSize: 12 }}>—</span>
                      )}
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
                );
              })}
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
