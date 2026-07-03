"use client";

import { useEffect, useState } from "react";
import { RefreshCw, Check, X, Undo } from "lucide-react";
import { adminApi, RefundRequest } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

export default function RefundsPage() {
  const { t, lang } = useLang();
  const [refunds, setRefunds] = useState<RefundRequest[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit] = useState(12);
  const [status, setStatus] = useState<"pending" | "approved" | "rejected" | "">("pending");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Reject Modal state
  const [rejectingRefund, setRejectingRefund] = useState<RefundRequest | null>(null);
  const [adminNote, setAdminNote] = useState("");
  const [submittingReject, setSubmittingReject] = useState(false);

  useEffect(() => {
    fetchRefunds();
  }, [page, status]);

  const fetchRefunds = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminApi.listRefunds({
        page,
        limit,
        status: status || undefined,
      });
      setRefunds(data.refunds);
      setTotal(data.total);
    } catch (err: any) {
      setError(err.message || t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (id: string) => {
    if (!confirm(t("approveRefund") + "?")) return;
    try {
      await adminApi.approveRefund(id);
      fetchRefunds();
    } catch (err: any) {
      alert(err.message || "Failed to approve refund");
    }
  };

  const openRejectModal = (refund: RefundRequest) => {
    setRejectingRefund(refund);
    setAdminNote("");
  };

  const handleReject = async () => {
    if (!rejectingRefund) return;
    try {
      setSubmittingReject(true);
      await adminApi.rejectRefund(rejectingRefund.id, adminNote.trim() || undefined);
      setRejectingRefund(null);
      fetchRefunds();
    } catch (err: any) {
      alert(err.message || "Failed to reject refund");
    } finally {
      setSubmittingReject(false);
    }
  };

  if (loading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", padding: 80 }}>
        <div className="spinner" style={{ width: 40, height: 40, borderWidth: 3 }} />
      </div>
    );
  }

  const totalPages = Math.ceil(total / limit);

  return (
    <div>
      {error && <div className="alert alert-error">{error}</div>}

      {/* Header */}
      <div className="section-header" style={{ display: "flex", gap: 16, alignItems: "center", flexWrap: "wrap" }}>
        <h1 className="section-title" style={{ flex: 1 }}>{t("refunds")}</h1>
        <button className="btn btn-ghost btn-icon" onClick={fetchRefunds} title={t("refresh")}>
          <RefreshCw size={16} />
        </button>
      </div>

      {/* Tabs */}
      <div className="section-header" style={{ marginBottom: 20 }}>
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", flex: 1 }}>
          {(["pending", "approved", "rejected", ""] as const).map((s) => {
            const isActive = status === s;
            let label = t("all");
            if (s === "pending") label = t("pending");
            if (s === "approved") label = t("approved");
            if (s === "rejected") label = t("rejected");

            return (
              <button
                key={s}
                className={`btn ${isActive ? "btn-primary" : "btn-ghost"} btn-sm`}
                onClick={() => {
                  setStatus(s);
                  setPage(1);
                }}
              >
                {label}
              </button>
            );
          })}
        </div>
      </div>

      {refunds.length === 0 ? (
        <div style={{ textAlign: "center", padding: 60, color: "var(--text-muted)" }}>
          <Undo size={48} style={{ marginBottom: 12, opacity: 0.5 }} />
          <h3>{lang === "ar" ? "لا توجد طلبات استرداد أموال" : "No refund requests found"}</h3>
          <p style={{ fontSize: 13, marginTop: 4 }}>
            {lang === "ar" ? "لم يتم تقديم أي طلبات استرداد في هذا القسم." : "No refund requests have been submitted in this status."}
          </p>
        </div>
      ) : (
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>{t("orderId")}</th>
                <th>{t("customer")}</th>
                <th>{t("cartType")}</th>
                <th>{t("refundReason")}</th>
                <th>{t("amount")}</th>
                <th>{t("status")}</th>
                <th>{t("date")}</th>
                {status === "pending" && <th>{t("actions")}</th>}
              </tr>
            </thead>
            <tbody>
              {refunds.map((refund) => {
                const shortId = refund.order_id.substring(0, 8).toUpperCase();
                const dateStr = new Date(refund.created_at).toLocaleDateString(
                  lang === "ar" ? "ar-EG" : "en-US"
                );
                let statusBadge = "badge-pending";
                if (refund.status === "approved" || refund.status === "completed") statusBadge = "badge-delivered";
                if (refund.status === "rejected") statusBadge = "badge-cancelled";

                return (
                  <tr key={refund.id}>
                    <td style={{ fontFamily: "monospace", fontSize: 12, fontWeight: 600 }}>
                      #{shortId}
                    </td>
                    <td>
                      <div style={{ fontWeight: 500 }}>{refund.user_name || "—"}</div>
                      <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{refund.user_email || "—"}</div>
                    </td>
                    <td>
                      <span className="badge badge-secondary" style={{ background: "var(--bg-secondary)", border: "1px solid var(--border)", textTransform: "uppercase" }}>
                        {refund.order_cart_type || "internal"}
                      </span>
                    </td>
                    <td>
                      <div style={{ maxWidth: 220, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }} title={refund.reason}>
                        {refund.reason}
                      </div>
                      {refund.admin_note && (
                        <div style={{ fontSize: 11, color: "var(--danger)", marginTop: 4 }}>
                          <strong>{t("adminNote")}:</strong> {refund.admin_note}
                        </div>
                      )}
                    </td>
                    <td style={{ fontWeight: 600 }}>
                      {refund.order_total ? `﷼ ${refund.order_total.toFixed(2)}` : "—"}
                    </td>
                    <td>
                      <span className={`badge ${statusBadge}`}>
                        {t(refund.status)}
                      </span>
                    </td>
                    <td style={{ fontSize: 13, color: "var(--text-secondary)" }}>{dateStr}</td>
                    {status === "pending" && (
                      <td>
                        <div style={{ display: "flex", gap: 6 }}>
                          <button
                            className="btn btn-primary btn-sm"
                            style={{ background: "var(--success)" }}
                            onClick={() => handleApprove(refund.id)}
                          >
                            <Check size={13} />
                            <span>{lang === "ar" ? "قبول" : "Approve"}</span>
                          </button>
                          <button
                            className="btn btn-danger btn-sm"
                            onClick={() => openRejectModal(refund)}
                          >
                            <X size={13} />
                            <span>{lang === "ar" ? "رفض" : "Reject"}</span>
                          </button>
                        </div>
                      </td>
                    )}
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

      {/* Reject Modal */}
      {rejectingRefund && (
        <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && setRejectingRefund(null)}>
          <div className="modal">
            <div className="modal-title">{t("rejectRefund")}</div>
            <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 16 }}>
              {lang === "ar"
                ? `طلب استرداد لطلب رقم #${rejectingRefund.order_id.substring(0, 8).toUpperCase()}`
                : `Refund request for order #${rejectingRefund.order_id.substring(0, 8).toUpperCase()}`}
            </p>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="form-group">
                <label className="form-label">{t("adminNote")}</label>
                <textarea
                  className="input"
                  rows={4}
                  value={adminNote}
                  onChange={(e) => setAdminNote(e.target.value)}
                  placeholder={t("reasonPlaceholder")}
                  style={{ resize: "vertical", minHeight: 80 }}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button
                className="btn btn-ghost"
                disabled={submittingReject}
                onClick={() => setRejectingRefund(null)}
              >
                {t("cancel")}
              </button>
              <button
                className="btn btn-danger"
                disabled={submittingReject}
                onClick={handleReject}
              >
                {submittingReject ? <div className="spinner" /> : t("rejectRefund")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
