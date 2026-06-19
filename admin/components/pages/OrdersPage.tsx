"use client";

import { useEffect, useState, useCallback } from "react";
import { RefreshCw, ChevronDown } from "lucide-react";
import { adminApi, Order } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const ORDER_STATUSES = ["pending", "confirmed", "processing", "shipped", "delivered", "cancelled"];

export default function OrdersPage() {
  const { t, lang } = useLang();
  const [orders, setOrders] = useState<Order[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [loading, setLoading] = useState(true);
  const [expandedOrder, setExpandedOrder] = useState<string | null>(null);
  const [updatingStatus, setUpdatingStatus] = useState<string | null>(null);
  const [error, setError] = useState("");

  const LIMIT = 12;

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.listOrders({ page, limit: LIMIT, status: statusFilter || undefined });
      setOrders(res.orders);
      setTotal(res.total);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, t]);

  useEffect(() => { load(); }, [load]);

  const handleStatusChange = async (orderId: string, newStatus: string) => {
    setUpdatingStatus(orderId);
    try {
      await adminApi.updateOrderStatus(orderId, newStatus);
      load();
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToUpdate"));
    } finally {
      setUpdatingStatus(null);
    }
  };

  const totalPages = Math.ceil(total / LIMIT);

  return (
    <div>
      {error && <div className="alert alert-error">{error}</div>}

      {/* Header */}
      <div className="section-header">
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap", flex: 1 }}>
          {["", ...ORDER_STATUSES].map(s => (
            <button
              key={s}
              id={`filter-${s || "all"}`}
              className={`btn ${statusFilter === s ? "btn-primary" : "btn-ghost"} btn-sm`}
              onClick={() => { setStatusFilter(s); setPage(1); }}
            >
              {s ? t(s as any) : t("allOrders")}
            </button>
          ))}
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
                <th style={{ width: 32 }}></th>
                <th>{t("orderId")}</th>
                <th>{t("customer")}</th>
                <th>{t("itemsCount")}</th>
                <th>{t("total")}</th>
                <th>{t("status")}</th>
                <th>{t("date")}</th>
                <th>{t("updateStatus")}</th>
              </tr>
            </thead>
            <tbody>
              {orders.length === 0 ? (
                <tr><td colSpan={8} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>{t("noOrdersFound")}</td></tr>
              ) : orders.map(order => (
                <>
                  <tr key={order.id}>
                    <td>
                      <button
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={() => setExpandedOrder(expandedOrder === order.id ? null : order.id)}
                        title={t("viewItems")}
                      >
                        <ChevronDown
                          size={14}
                          style={{ transform: expandedOrder === order.id ? "rotate(180deg)" : "none", transition: "transform 0.2s" }}
                        />
                      </button>
                    </td>
                    <td style={{ fontFamily: "monospace", fontSize: 12, color: "var(--text-muted)" }}>
                      #{order.id.slice(0, 8)}
                    </td>
                    <td>
                      <div style={{ fontWeight: 500 }}>{order.user_name || "—"}</div>
                      <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{order.user_email}</div>
                    </td>
                    <td style={{ color: "var(--text-secondary)" }}>{order.items?.length || 0} {t("itemsCount")}</td>
                    <td style={{ fontWeight: 600 }}>
                      ﷼ {order.total.toFixed(2)}
                      {order.discount_amount > 0 && (
                        <div style={{ fontSize: 11, color: "var(--success)" }}>-﷼ {order.discount_amount.toFixed(2)}</div>
                      )}
                    </td>
                    <td>
                      <span className={`badge badge-${order.status}`}>
                        {t(order.status as any)}
                      </span>
                    </td>
                    <td style={{ color: "var(--text-secondary)", fontSize: 13 }}>
                      {new Date(order.created_at).toLocaleDateString(lang === "ar" ? "ar-EG" : "en-US")}
                      <div style={{ fontSize: 11, color: "var(--text-muted)" }}>
                        {new Date(order.created_at).toLocaleTimeString(lang === "ar" ? "ar-EG" : "en-US")}
                      </div>
                    </td>
                    <td>
                      <select
                        id={`status-${order.id}`}
                        className="input"
                        style={{ width: "auto", minWidth: 130, fontSize: 12, padding: "5px 10px" }}
                        value={order.status}
                        onChange={e => handleStatusChange(order.id, e.target.value)}
                        disabled={updatingStatus === order.id}
                      >
                        {ORDER_STATUSES.map(s => (
                          <option key={s} value={s}>{t(s as any)}</option>
                        ))}
                      </select>
                    </td>
                  </tr>

                  {/* Expanded order items */}
                  {expandedOrder === order.id && (
                    <tr key={`${order.id}-items`}>
                      <td colSpan={8} style={{ padding: 0, background: "var(--bg-secondary)" }}>
                        <div style={{ padding: "12px 20px" }}>
                          <div style={{ fontSize: 12, fontWeight: 600, color: "var(--text-muted)", marginBottom: 10, textTransform: "uppercase", letterSpacing: "0.5px" }}>
                            {t("orderItemsTitle")}
                          </div>
                          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                            {order.items?.map(item => (
                              <div key={item.id} style={{
                                display: "flex",
                                alignItems: "center",
                                gap: 12,
                                padding: "8px 12px",
                                background: "var(--bg-card)",
                                borderRadius: 8,
                                border: "1px solid var(--border)",
                              }}>
                                {item.image_url ? (
                                  // eslint-disable-next-line @next/next/no-img-element
                                  <img src={item.image_url} alt={item.title} style={{ width: 36, height: 36, borderRadius: 6, objectFit: "cover" }} />
                                ) : (
                                  <div style={{ width: 36, height: 36, borderRadius: 6, background: "var(--bg-secondary)", display: "flex", alignItems: "center", justifyContent: "center" }}>📦</div>
                                )}
                                <div style={{ flex: 1 }}>
                                  <div style={{ fontSize: 13, fontWeight: 500 }}>{item.title}</div>
                                  <div style={{ fontSize: 11, color: "var(--text-muted)" }}>{t("source")}: {item.source}</div>
                                </div>
                                <div style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                                  × {item.quantity}
                                </div>
                                <div style={{ fontWeight: 600, fontSize: 13 }}>
                                  ﷼ {(item.price * item.quantity).toFixed(2)}
                                </div>
                              </div>
                            ))}
                          </div>
                          {order.shipping_address && (
                            <div style={{ marginTop: 12, fontSize: 12, color: "var(--text-muted)" }}>
                              <strong style={{ color: "var(--text-secondary)" }}>{t("shippingAddress")}:</strong>{" "}
                              {typeof order.shipping_address === "object"
                                ? Object.values(order.shipping_address).filter(Boolean).join(", ")
                                : String(order.shipping_address)}
                            </div>
                          )}
                        </div>
                      </td>
                    </tr>
                  )}
                </>
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
    </div>
  );
}
