"use client";

import { useEffect, useState } from "react";
import { RefreshCw, Check, X, ShieldAlert, Image as ImageIcon } from "lucide-react";
import { adminApi, Order } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

export default function PaymentsPage() {
  const { t, lang } = useLang();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Reject modal state
  const [rejectingOrder, setRejectingOrder] = useState<Order | null>(null);
  const [rejectReason, setRejectReason] = useState("");
  const [submittingReject, setSubmittingReject] = useState(false);

  useEffect(() => {
    fetchPendingPayments();
  }, []);

  const fetchPendingPayments = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await adminApi.listPendingPayments();
      setOrders(data);
    } catch (err: any) {
      setError(err.message || t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (orderId: string) => {
    if (!confirm(t("approvePayment") + "?")) return;
    try {
      await adminApi.approvePayment(orderId);
      setOrders(orders.filter(o => o.id !== orderId));
    } catch (err: any) {
      alert(err.message || "Failed to approve payment");
    }
  };

  const openRejectModal = (order: Order) => {
    setRejectingOrder(order);
    setRejectReason("");
  };

  const handleReject = async () => {
    if (!rejectingOrder) return;
    try {
      setSubmittingReject(true);
      await adminApi.rejectPayment(rejectingOrder.id, rejectReason.trim() || undefined);
      setOrders(orders.filter(o => o.id !== rejectingOrder.id));
      setRejectingOrder(null);
    } catch (err: any) {
      alert(err.message || "Failed to reject payment");
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

  return (
    <div>
      {error && <div className="alert alert-error">{error}</div>}

      {/* Header */}
      <div className="section-header">
        <h1 className="section-title">{t("payments")}</h1>
        <button className="btn btn-ghost btn-icon" onClick={fetchPendingPayments} title={t("refresh")}>
          <RefreshCw size={16} />
        </button>
      </div>

      {orders.length === 0 ? (
        <div style={{ textAlign: "center", padding: 60, color: "var(--text-muted)" }}>
          <ShieldAlert size={48} style={{ marginBottom: 12, opacity: 0.5 }} />
          <h3>{lang === "ar" ? "لا توجد موافقات دفع معلقة" : "No pending payment approvals"}</h3>
          <p style={{ fontSize: 13, marginTop: 4 }}>
            {lang === "ar" ? "كل المدفوعات تمت مراجعتها بالكامل." : "All manual payments have been reviewed."}
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
                <th>{t("total")}</th>
                <th>{t("paymentMethod")}</th>
                <th>{t("paymentProof")}</th>
                <th>{t("date")}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {orders.map((order) => {
                const shortId = order.id.substring(0, 8).toUpperCase();
                const dateStr = new Date(order.created_at).toLocaleDateString(
                  lang === "ar" ? "ar-EG" : "en-US"
                );
                const proofUrl = order.payment_proof_url
                  ? order.payment_proof_url.startsWith("http")
                    ? order.payment_proof_url
                    : `http://localhost:8000${order.payment_proof_url}`
                  : null;

                return (
                  <tr key={order.id}>
                    <td style={{ fontFamily: "monospace", fontSize: 12, fontWeight: 600 }}>
                      #{shortId}
                    </td>
                    <td>
                      <div style={{ fontWeight: 500 }}>{order.user_name || "—"}</div>
                      <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{order.user_email || "—"}</div>
                    </td>
                    <td>
                      <span className="badge badge-secondary" style={{ background: "var(--bg-secondary)", border: "1px solid var(--border)", textTransform: "uppercase" }}>
                        {order.cart_type || "internal"}
                      </span>
                    </td>
                    <td style={{ fontWeight: 600 }}>
                      ﷼ {order.total.toFixed(2)}
                    </td>
                    <td>
                      <span style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                        {order.payment_method_id === "wallet" ? t("pay_with_wallet") : order.payment_method_id}
                      </span>
                    </td>
                    <td>
                      {proofUrl ? (
                        <a
                          href={proofUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          style={{
                            display: "inline-flex",
                            alignItems: "center",
                            gap: 4,
                            color: "var(--accent-light)",
                            textDecoration: "none",
                            fontSize: 13,
                          }}
                        >
                          <ImageIcon size={14} />
                          <span>{t("viewProduct")}</span>
                        </a>
                      ) : (
                        <span style={{ color: "var(--text-muted)", fontSize: 13 }}>—</span>
                      )}
                    </td>
                    <td style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                      {dateStr}
                    </td>
                    <td>
                      <div style={{ display: "flex", gap: 6 }}>
                        <button
                          className="btn btn-primary btn-sm"
                          style={{ background: "var(--success)" }}
                          onClick={() => handleApprove(order.id)}
                        >
                          <Check size={13} />
                          <span>{lang === "ar" ? "قبول" : "Approve"}</span>
                        </button>
                        <button
                          className="btn btn-danger btn-sm"
                          onClick={() => openRejectModal(order)}
                        >
                          <X size={13} />
                          <span>{lang === "ar" ? "رفض" : "Reject"}</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Reject Modal */}
      {rejectingOrder && (
        <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && setRejectingOrder(null)}>
          <div className="modal">
            <div className="modal-title">{t("rejectPayment")}</div>
            <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 16 }}>
              {lang === "ar"
                ? `طلب رقم #${rejectingOrder.id.substring(0, 8).toUpperCase()}`
                : `Order #${rejectingOrder.id.substring(0, 8).toUpperCase()}`}
            </p>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="form-group">
                <label className="form-label">
                  {lang === "ar" ? "سبب الرفض (سيتم إرساله للمستخدم)" : "Reason for rejection (will be emailed to user)"}
                </label>
                <textarea
                  className="input"
                  rows={4}
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder={t("reasonPlaceholder")}
                  style={{ resize: "vertical", minHeight: 80 }}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button
                className="btn btn-ghost"
                disabled={submittingReject}
                onClick={() => setRejectingOrder(null)}
              >
                {t("cancel")}
              </button>
              <button
                className="btn btn-danger"
                disabled={submittingReject}
                onClick={handleReject}
              >
                {submittingReject ? <div className="spinner" /> : t("rejectPayment")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
