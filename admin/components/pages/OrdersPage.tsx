"use client";

import { useEffect, useState, useCallback } from "react";
import { RefreshCw, ChevronDown, Mail, Image as ImageIcon, ExternalLink } from "lucide-react";
import { adminApi, Order } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const ORDER_STATUSES = ["pending", "confirmed", "processing", "shipped", "delivered", "cancelled"];
const CART_TYPES = ["", "internal", "amazon", "aliexpress", "shein", "alibaba", "iherb"];

export default function OrdersPage() {
  const { t, lang } = useLang();
  const [orders, setOrders] = useState<Order[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [cartTypeFilter, setCartTypeFilter] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [expandedOrder, setExpandedOrder] = useState<string | null>(null);
  const [updatingStatus, setUpdatingStatus] = useState<string | null>(null);
  const [error, setError] = useState("");

  // Contact User state
  const [contactOrder, setContactOrder] = useState<Order | null>(null);
  const [contactMessage, setContactMessage] = useState("");
  const [submittingContact, setSubmittingContact] = useState(false);

  const LIMIT = 12;

  // Search debounce
  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedSearch(searchTerm);
      setPage(1);
    }, 400);
    return () => clearTimeout(handler);
  }, [searchTerm]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminApi.listOrders({
        page,
        limit: LIMIT,
        status: statusFilter || undefined,
        cart_type: cartTypeFilter || undefined,
        search: debouncedSearch.trim() || undefined,
      });
      setOrders(res.orders);
      setTotal(res.total);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t("failedToLoad"));
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, cartTypeFilter, debouncedSearch, t]);

  useEffect(() => {
    load();
  }, [load]);

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

  const handleContactUserSubmit = async () => {
    if (!contactOrder || !contactMessage.trim()) return;
    try {
      setSubmittingContact(true);
      await adminApi.contactUser(contactOrder.id, contactMessage.trim());
      setContactOrder(null);
      setContactMessage("");
      alert(lang === "ar" ? "تم إرسال الرسالة وإنشاء تذكرة الدعم بنجاح!" : "Message sent and support ticket created successfully!");
    } catch (err: any) {
      alert(err.message || "Failed to send message");
    } finally {
      setSubmittingContact(false);
    }
  };

  const totalPages = Math.ceil(total / LIMIT);

  return (
    <div>
      {error && <div className="alert alert-error">{error}</div>}

      {/* Header filters */}
      <div className="section-header" style={{ flexDirection: "column", alignItems: "stretch", gap: 12, marginBottom: 20 }}>
        {/* Status filters */}
        <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
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

        {/* Search and Cart Type */}
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", gap: 8, flex: 1, minWidth: 280 }}>
            <input
              type="text"
              className="input"
              style={{ flex: 1 }}
              placeholder={lang === "ar" ? "ابحث برقم الطلب أو البريد الإلكتروني للعميل..." : "Search by Order ID or email..."}
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
            />
            <select
              className="input"
              style={{ width: "auto", minWidth: 160 }}
              value={cartTypeFilter}
              onChange={e => { setCartTypeFilter(e.target.value); setPage(1); }}
            >
              <option value="">{lang === "ar" ? "كل مصادر السلة" : "All Cart Sources"}</option>
              {CART_TYPES.filter(Boolean).map(ct => (
                <option key={ct} value={ct}>{ct.toUpperCase()}</option>
              ))}
            </select>
          </div>
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
                <th style={{ width: 32 }}></th>
                <th>{t("orderId")}</th>
                <th>{t("customer")}</th>
                <th>{t("cartType")}</th>
                <th>{t("total")}</th>
                <th>{t("status")}</th>
                <th>{t("paymentStatus")}</th>
                <th>{t("date")}</th>
                <th>{t("updateStatus")}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {orders.length === 0 ? (
                <tr>
                  <td colSpan={10} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
                    {lang === "ar" ? "لا توجد طلبات مطابقة" : "No orders found."}
                  </td>
                </tr>
              ) : orders.map(order => {
                const shortId = order.id.substring(0, 8).toUpperCase();
                let statusBadge = `badge-${order.status}`;
                let paymentBadge = "badge-pending";
                if (order.payment_status === "approved" || order.payment_status === "not_required") paymentBadge = "badge-delivered";
                if (order.payment_status === "rejected") paymentBadge = "badge-cancelled";

                return (
                  <tr key={order.id} style={{ background: expandedOrder === order.id ? "var(--bg-secondary)" : undefined }}>
                    <td>
                      <button
                        className="btn btn-ghost btn-icon btn-sm"
                        onClick={() => setExpandedOrder(expandedOrder === order.id ? null : order.id)}
                      >
                        <ChevronDown
                          size={14}
                          style={{ transform: expandedOrder === order.id ? "rotate(180deg)" : "none", transition: "transform 0.2s" }}
                        />
                      </button>
                    </td>
                    <td style={{ fontFamily: "monospace", fontSize: 12, fontWeight: 600 }}>
                      #{shortId}
                    </td>
                    <td>
                      <div style={{ fontWeight: 500 }}>{order.user_name || "—"}</div>
                      <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{order.user_email}</div>
                      {order.user_phone && <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 2 }}>{order.user_phone}</div>}
                    </td>
                    <td>
                      <span className="badge badge-secondary" style={{ background: "var(--bg-secondary)", border: "1px solid var(--border)", textTransform: "uppercase" }}>
                        {order.cart_type || "internal"}
                      </span>
                    </td>
                    <td style={{ fontWeight: 600 }}>
                      ﷼ {order.total.toFixed(2)}
                      {order.discount_amount > 0 && (
                        <div style={{ fontSize: 11, color: "var(--success)" }}>-﷼ {order.discount_amount.toFixed(2)}</div>
                      )}
                    </td>
                    <td>
                      <span className={`badge ${statusBadge}`}>{t(order.status as any)}</span>
                    </td>
                    <td>
                      <span className={`badge ${paymentBadge}`}>{t(order.payment_status as any)}</span>
                    </td>
                    <td style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                      <div>{new Date(order.created_at).toLocaleDateString(lang === "ar" ? "ar-EG" : "en-US")}</div>
                      <div style={{ fontSize: 11, color: "var(--text-muted)" }}>{new Date(order.created_at).toLocaleTimeString(lang === "ar" ? "ar-EG" : "en-US")}</div>
                    </td>
                    <td>
                      <select
                        className="input"
                        style={{ width: "auto", minWidth: 120, fontSize: 12, padding: "5px 10px" }}
                        value={order.status}
                        onChange={e => handleStatusChange(order.id, e.target.value)}
                        disabled={updatingStatus === order.id}
                      >
                        {ORDER_STATUSES.map(s => (
                          <option key={s} value={s}>{t(s as any)}</option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <button
                        className="btn btn-ghost btn-sm"
                        onClick={() => {
                          setContactOrder(order);
                          setContactMessage("");
                        }}
                      >
                        <Mail size={13} />
                        <span>{t("contactUser")}</span>
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Expanded Order Items and Payment Details */}
      {expandedOrder && (
        <div style={{
          padding: 20,
          background: "var(--bg-secondary)",
          border: "1px solid var(--border)",
          borderRadius: 14,
          marginTop: 12,
        }}>
          {(() => {
            const order = orders.find(o => o.id === expandedOrder);
            if (!order) return null;
            const proofUrl = order.payment_proof_url
              ? order.payment_proof_url.startsWith("http")
                ? order.payment_proof_url
                : `http://localhost:8000${order.payment_proof_url}`
              : null;

            return (
              <div style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))",
                gap: 24,
              }}>
                <div>
                  <h4 style={{ fontWeight: 700, fontSize: 15, borderBottom: "1px solid var(--border)", paddingBottom: 8, marginBottom: 12 }}>
                    {lang === "ar" ? "منتجات الطلب" : "Order Items"}
                  </h4>
                  <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                    {order.items?.map(item => (
                      <div key={item.id} style={{
                        display: "flex",
                        alignItems: "center",
                        gap: 12,
                        padding: 10,
                        background: "var(--bg-card)",
                        borderRadius: 8,
                        border: "1px solid var(--border)",
                      }}>
                        {item.image_url ? (
                          <img src={item.image_url} alt={item.title} style={{ width: 40, height: 40, borderRadius: 6, objectFit: "cover" }} />
                        ) : (
                          <div style={{ width: 40, height: 40, borderRadius: 6, background: "var(--bg-secondary)", display: "flex", alignItems: "center", justifyContent: "center" }}>📦</div>
                        )}
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 13, fontWeight: 600 }}>{item.title}</div>
                          <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 2 }}>
                            <span>{t("source")}: {item.source.toUpperCase()}</span>
                            {item.external_url && (
                              <a
                                href={item.external_url}
                                target="_blank"
                                rel="noopener noreferrer"
                                style={{
                                  color: "var(--accent-light)",
                                  textDecoration: "none",
                                  marginLeft: 8,
                                  display: "inline-flex",
                                  alignItems: "center",
                                  gap: 2,
                                }}
                              >
                                <span>{t("viewProduct")}</span>
                                <ExternalLink size={10} />
                              </a>
                            )}
                          </div>
                        </div>
                        <div style={{ fontSize: 13, color: "var(--text-secondary)" }}>×{item.quantity}</div>
                        <div style={{ fontSize: 13, fontWeight: 700 }}>{(item.price * item.quantity).toFixed(2)} SAR</div>
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <h4 style={{ fontWeight: 700, fontSize: 15, borderBottom: "1px solid var(--border)", paddingBottom: 8, marginBottom: 12 }}>
                    {lang === "ar" ? "تفاصيل الدفع والتسليم" : "Payment & Delivery Info"}
                  </h4>
                  <div style={{ display: "flex", flexDirection: "column", gap: 10, fontSize: 13, color: "var(--text-secondary)" }}>
                    <div>
                      <strong style={{ color: "var(--text-primary)" }}>{t("paymentMethod")}:</strong>{" "}
                      <span>{order.payment_method_id === "wallet" ? t("walletBalance") : order.payment_method_id}</span>
                    </div>
                    {order.payment_fields && Object.keys(order.payment_fields).length > 0 && (
                      <div style={{ padding: 10, background: "var(--bg-card)", borderRadius: 8, border: "1px solid var(--border)" }}>
                        <strong style={{ fontSize: 11, color: "var(--text-muted)", display: "block", marginBottom: 6 }}>
                          {lang === "ar" ? "بيانات إضافية" : "Additional Fields"}
                        </strong>
                        {Object.entries(order.payment_fields).map(([k, v]: any) => (
                          <div key={k} style={{ fontSize: 12, marginBottom: 4 }}>
                            <span style={{ fontWeight: 600 }}>{k}:</span>{" "}
                            {typeof v === "string" && v.startsWith("/static/") ? (
                              <a href={`http://localhost:8000${v}`} target="_blank" rel="noopener noreferrer" style={{ color: "var(--accent-light)", textDecoration: "none" }}>
                                {lang === "ar" ? "تحميل الملف" : "View File"}
                              </a>
                            ) : (
                              <span>{String(v)}</span>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                    {proofUrl && (
                      <div>
                        <strong style={{ color: "var(--text-primary)" }}>{t("paymentProof")}:</strong>{" "}
                        <a href={proofUrl} target="_blank" rel="noopener noreferrer" style={{ color: "var(--accent-light)", textDecoration: "none", display: "inline-flex", alignItems: "center", gap: 4 }}>
                          <ImageIcon size={14} />
                          <span>{lang === "ar" ? "عرض إثبات الدفع" : "View Proof Image"}</span>
                        </a>
                      </div>
                    )}
                    {order.shipping_address && (
                      <div>
                        <strong style={{ color: "var(--text-primary)" }}>{t("shippingAddress")}:</strong>{" "}
                        <span>
                          {typeof order.shipping_address === "object"
                            ? Object.values(order.shipping_address).filter(Boolean).join(", ")
                            : String(order.shipping_address)}
                        </span>
                      </div>
                    )}
                    {order.shipping_type && (
                      <div>
                        <strong style={{ color: "var(--text-primary)" }}>{lang === "ar" ? "نوع الشحن" : "Shipping Type"}:</strong>{" "}
                        <span>{order.shipping_type === "home" ? t("home_delivery" as any) : t("pickup" as any)}</span>
                      </div>
                    )}
                    {order.allow_team_review && (
                      <div style={{ color: "var(--success)", fontWeight: 600, fontSize: 12 }}>
                        ✓ {lang === "ar" ? "تم طلب مراجعة الفريق قبل الشحن" : "Team review requested before shipping"}
                      </div>
                    )}
                    {order.notes && (
                      <div style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 6, fontStyle: "italic" }}>
                        <strong>{lang === "ar" ? "ملاحظة العميل" : "Customer Note"}:</strong> "{order.notes}"
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })()}
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

      {/* Contact User Modal */}
      {contactOrder && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setContactOrder(null)}>
          <div className="modal">
            <div className="modal-title">{t("contactUserTitle")}</div>
            <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 16 }}>
              {lang === "ar"
                ? `إرسال رسالة بريد للعميل بشأن طلب رقم #${contactOrder.id.substring(0, 8).toUpperCase()} وسيتم فتح تذكرة دعم فني تلقائياً.`
                : `Send a support message to the customer regarding Order #${contactOrder.id.substring(0, 8).toUpperCase()}. A support ticket will be opened.`}
            </p>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <div className="form-group">
                <label className="form-label">{lang === "ar" ? "الرسالة" : "Message"}</label>
                <textarea
                  className="input"
                  rows={5}
                  value={contactMessage}
                  onChange={e => setContactMessage(e.target.value)}
                  placeholder={t("messagePlaceholder")}
                  style={{ resize: "vertical", minHeight: 100 }}
                />
              </div>
            </div>
            <div className="modal-footer">
              <button
                className="btn btn-ghost"
                disabled={submittingContact}
                onClick={() => setContactOrder(null)}
              >
                {t("cancel")}
              </button>
              <button
                className="btn btn-primary"
                disabled={submittingContact}
                onClick={handleContactUserSubmit}
              >
                {submittingContact ? <div className="spinner" /> : t("submit")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
