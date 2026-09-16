"use client";

import { useEffect, useState, useCallback, useMemo } from "react";
import {
  RefreshCw,
  ChevronDown,
  Mail,
  Image as ImageIcon,
  ExternalLink,
  Download,
  X,
  MapPin,
  ArrowUpDown,
  ArrowUp,
  ArrowDown,
} from "lucide-react";
import { adminApi, Order, getMediaUrl } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const ORDER_STATUSES = ["pending", "confirmed", "processing", "shipped", "delivered", "cancelled", "refunded"];
const CART_TYPES = ["", "internal", "amazon", "aliexpress", "shein", "alibaba", "iherb"];

// Helper to format shipping address into a clean, human-readable text
const formatAddress = (addr: any): string => {
  if (!addr) return "—";
  if (typeof addr === "string") {
    // If it's a raw UUID, don't show it
    if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(addr.trim())) {
      return "—";
    }
    return addr;
  }
  if (typeof addr === "object") {
    const parts = [
      addr.city,
      addr.state,
      addr.street,
      addr.country && addr.country !== "Saudi Arabia" ? addr.country : "",
    ].filter(Boolean);
    if (parts.length > 0) return parts.join(", ");
    if (addr.full_name || addr.phone) {
      return [addr.full_name, addr.phone].filter(Boolean).join(" | ");
    }
    const values = Object.entries(addr)
      .filter(([k, v]) => !["id", "address_id", "user_id"].includes(k) && Boolean(v))
      .map(([, v]) => String(v));
    if (values.length > 0) return values.join(", ");
  }
  return "—";
};

// Helper to extract the geographical region/city from address
const getAddressRegion = (addr: any): string => {
  if (!addr) return "";
  if (typeof addr === "string") {
    if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(addr.trim())) {
      return "";
    }
    return addr;
  }
  if (typeof addr === "object") {
    return (addr.city || addr.state || addr.country || "").trim();
  }
  return "";
};

export default function OrdersPage() {
  const { t, lang } = useLang();
  const [orders, setOrders] = useState<Order[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState("");
  const [cartTypeFilter, setCartTypeFilter] = useState("");
  const [regionFilter, setRegionFilter] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [expandedOrder, setExpandedOrder] = useState<string | null>(null);
  const [updatingStatus, setUpdatingStatus] = useState<string | null>(null);
  const [error, setError] = useState("");

  // Sorting state (default: date desc)
  const [sortField, setSortField] = useState<"date" | "shipping_address" | "total">("date");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("desc");

  // Contact User state
  const [contactOrder, setContactOrder] = useState<Order | null>(null);
  const [contactMessage, setContactMessage] = useState("");
  const [submittingContact, setSubmittingContact] = useState(false);

  // Export Excel state
  const [showExport, setShowExport] = useState(false);
  const [exportDateFrom, setExportDateFrom] = useState("");
  const [exportDateTo, setExportDateTo] = useState("");
  const [exportCartType, setExportCartType] = useState("");
  const [exportStatus, setExportStatus] = useState("");
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState("");

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

  const handleExport = async () => {
    setExporting(true);
    setExportError("");
    try {
      await adminApi.exportOrdersExcel({
        date_from: exportDateFrom || undefined,
        date_to: exportDateTo || undefined,
        cart_type: exportCartType || undefined,
        status: exportStatus || undefined,
      });
      setShowExport(false);
    } catch (e: unknown) {
      setExportError(e instanceof Error ? e.message : "Export failed");
    } finally {
      setExporting(false);
    }
  };

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

  const handleSort = (field: "date" | "shipping_address" | "total") => {
    if (sortField === field) {
      setSortDir(d => (d === "asc" ? "desc" : "asc"));
    } else {
      setSortField(field);
      setSortDir(field === "date" ? "desc" : "asc");
    }
  };

  // Collect available regions from current orders
  const availableRegions = useMemo(() => {
    const set = new Set<string>();
    orders.forEach(o => {
      const reg = getAddressRegion(o.shipping_address);
      if (reg && reg !== "—") set.add(reg);
    });
    return Array.from(set).sort((a, b) => a.localeCompare(b, lang === "ar" ? "ar" : "en"));
  }, [orders, lang]);

  // Filter & Sort orders for display
  const displayedOrders = useMemo(() => {
    let list = [...orders];
    if (regionFilter) {
      list = list.filter(o => getAddressRegion(o.shipping_address).toLowerCase() === regionFilter.toLowerCase());
    }
    list.sort((a, b) => {
      if (sortField === "shipping_address") {
        const regA = getAddressRegion(a.shipping_address).toLowerCase();
        const regB = getAddressRegion(b.shipping_address).toLowerCase();
        const cmp = regA.localeCompare(regB, lang === "ar" ? "ar" : "en");
        return sortDir === "asc" ? cmp : -cmp;
      } else if (sortField === "total") {
        return sortDir === "asc" ? a.total - b.total : b.total - a.total;
      } else {
        const timeA = new Date(a.created_at).getTime();
        const timeB = new Date(b.created_at).getTime();
        return sortDir === "asc" ? timeA - timeB : timeB - timeA;
      }
    });
    return list;
  }, [orders, regionFilter, sortField, sortDir, lang]);

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

        {/* Search, Cart Type, and Region Filter */}
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", gap: 8, flex: 1, minWidth: 280, flexWrap: "wrap" }}>
            <input
              type="text"
              className="input"
              style={{ flex: 1, minWidth: 180 }}
              placeholder={lang === "ar" ? "ابحث برقم الطلب أو البريد الإلكتروني..." : "Search by Order ID or email..."}
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
            />
            <select
              className="input"
              style={{ width: "auto", minWidth: 140 }}
              value={cartTypeFilter}
              onChange={e => { setCartTypeFilter(e.target.value); setPage(1); }}
            >
              <option value="">{lang === "ar" ? "كل مصادر السلة" : "All Cart Sources"}</option>
              {CART_TYPES.filter(Boolean).map(ct => (
                <option key={ct} value={ct}>{ct.toUpperCase()}</option>
              ))}
            </select>
            <select
              className="input"
              style={{ width: "auto", minWidth: 150 }}
              value={regionFilter}
              onChange={e => setRegionFilter(e.target.value)}
            >
              <option value="">{lang === "ar" ? "📍 كل المناطق الجغرافية" : "📍 All Regions"}</option>
              {availableRegions.map(reg => (
                <option key={reg} value={reg}>{reg}</option>
              ))}
            </select>
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button
              className="btn btn-secondary btn-sm"
              style={{ display: "flex", alignItems: "center", gap: 6 }}
              onClick={() => {
                setExportCartType(cartTypeFilter);
                setExportStatus(statusFilter);
                setShowExport(v => !v);
                setExportError("");
              }}
              title="Export to Excel"
            >
              <Download size={14} />
              {lang === "ar" ? "تصدير Excel" : "Export Excel"}
            </button>
            <button className="btn btn-ghost btn-icon" onClick={load} title={t("refresh")}>
              <RefreshCw size={16} />
            </button>
          </div>
        </div>

        {/* Customized Export Modal: Date, Cart Type (SHEIN/iHerb/etc.), and Status */}
        {showExport && (
          <div style={{
            background: "var(--bg-card)",
            border: "1px solid var(--border)",
            borderRadius: 12,
            padding: "18px 22px",
            boxShadow: "0 8px 24px rgba(0,0,0,0.12)",
            marginTop: 6,
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 14 }}>
              <div style={{ fontWeight: 700, fontSize: 14, display: "flex", alignItems: "center", gap: 6 }}>
                <Download size={16} style={{ color: "var(--accent-light)" }} />
                <span>{lang === "ar" ? "تخصيص تصدير الطلبات إلى Excel (.xlsx)" : "Export Orders Customization (.xlsx)"}</span>
              </div>
              <button
                className="btn btn-ghost btn-icon btn-sm"
                onClick={() => setShowExport(false)}
                title="Close"
              >
                <X size={15} />
              </button>
            </div>

            <div style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
              gap: 14,
              marginBottom: 16,
            }}>
              <div>
                <label className="form-label" style={{ fontSize: 12, fontWeight: 600 }}>
                  {lang === "ar" ? "1. من تاريخ" : "1. From Date"}
                </label>
                <input
                  type="date"
                  className="input"
                  value={exportDateFrom}
                  onChange={e => setExportDateFrom(e.target.value)}
                />
              </div>

              <div>
                <label className="form-label" style={{ fontSize: 12, fontWeight: 600 }}>
                  {lang === "ar" ? "إلى تاريخ" : "To Date"}
                </label>
                <input
                  type="date"
                  className="input"
                  value={exportDateTo}
                  onChange={e => setExportDateTo(e.target.value)}
                />
              </div>

              <div>
                <label className="form-label" style={{ fontSize: 12, fontWeight: 600 }}>
                  {lang === "ar" ? "2. نوع السلة (Cart Type)" : "2. Cart Type"}
                </label>
                <select
                  className="input"
                  value={exportCartType}
                  onChange={e => setExportCartType(e.target.value)}
                >
                  <option value="">{lang === "ar" ? "الكل (All Types)" : "All Types"}</option>
                  <option value="shein">SHEIN</option>
                  <option value="iherb">iHerb</option>
                  <option value="aliexpress">AliExpress</option>
                  <option value="amazon">Amazon</option>
                  <option value="alibaba">Alibaba</option>
                  <option value="internal">Internal Store</option>
                </select>
              </div>

              <div>
                <label className="form-label" style={{ fontSize: 12, fontWeight: 600 }}>
                  {lang === "ar" ? "3. حالة الطلب (Order Status)" : "3. Order Status"}
                </label>
                <select
                  className="input"
                  value={exportStatus}
                  onChange={e => setExportStatus(e.target.value)}
                >
                  <option value="">{lang === "ar" ? "كل الحالات (All Statuses)" : "All Statuses"}</option>
                  {ORDER_STATUSES.map(s => (
                    <option key={s} value={s}>{t(s as any)}</option>
                  ))}
                </select>
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", justifyContent: "flex-end", gap: 10 }}>
              {exportError && (
                <span style={{ color: "var(--danger)", fontSize: 12, marginRight: "auto" }}>{exportError}</span>
              )}
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => setShowExport(false)}
              >
                {lang === "ar" ? "إلغاء" : "Cancel"}
              </button>
              <button
                className="btn btn-primary btn-sm"
                disabled={exporting}
                onClick={handleExport}
                style={{ display: "flex", alignItems: "center", gap: 6, minWidth: 150, justifyContent: "center" }}
              >
                {exporting ? (
                  <div className="spinner" style={{ width: 14, height: 14 }} />
                ) : (
                  <><Download size={14} /> {lang === "ar" ? "تصدير الآن (.xlsx)" : "Export Now (.xlsx)"}</>
                )}
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
                <th style={{ width: 32 }}></th>
                <th>{t("orderId")}</th>
                <th>{t("customer")}</th>
                <th
                  style={{ cursor: "pointer", userSelect: "none" }}
                  onClick={() => handleSort("shipping_address")}
                  title={lang === "ar" ? "اضغط للفرز حسب المنطقة الجغرافية" : "Click to sort by Geographical Region"}
                >
                  <div style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
                    <MapPin size={13} style={{ color: "var(--accent-light)" }} />
                    <span>{lang === "ar" ? "عنوان الشحن / المنطقة" : "Shipping Address / Region"}</span>
                    {sortField === "shipping_address" ? (
                      sortDir === "asc" ? <ArrowUp size={13} /> : <ArrowDown size={13} />
                    ) : (
                      <ArrowUpDown size={13} style={{ opacity: 0.35 }} />
                    )}
                  </div>
                </th>
                <th>{t("cartType")}</th>
                <th
                  style={{ cursor: "pointer", userSelect: "none" }}
                  onClick={() => handleSort("total")}
                >
                  <div style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
                    <span>{t("total")}</span>
                    {sortField === "total" ? (
                      sortDir === "asc" ? <ArrowUp size={13} /> : <ArrowDown size={13} />
                    ) : (
                      <ArrowUpDown size={13} style={{ opacity: 0.35 }} />
                    )}
                  </div>
                </th>
                <th>{t("status")}</th>
                <th>{t("paymentStatus")}</th>
                <th
                  style={{ cursor: "pointer", userSelect: "none" }}
                  onClick={() => handleSort("date")}
                >
                  <div style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
                    <span>{t("date")}</span>
                    {sortField === "date" ? (
                      sortDir === "asc" ? <ArrowUp size={13} /> : <ArrowDown size={13} />
                    ) : (
                      <ArrowUpDown size={13} style={{ opacity: 0.35 }} />
                    )}
                  </div>
                </th>
                <th>{t("updateStatus")}</th>
                <th>{t("actions")}</th>
              </tr>
            </thead>
            <tbody>
              {displayedOrders.length === 0 ? (
                <tr>
                  <td colSpan={11} style={{ textAlign: "center", padding: 40, color: "var(--text-muted)" }}>
                    {lang === "ar" ? "لا توجد طلبات مطابقة" : "No orders found."}
                  </td>
                </tr>
              ) : displayedOrders.map(order => {
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
                    <td style={{ minWidth: 160 }}>
                      <div style={{ fontWeight: 600, color: "var(--text-primary)", fontSize: 13, display: "flex", alignItems: "center", gap: 4 }}>
                        <MapPin size={12} style={{ color: "var(--text-muted)", flexShrink: 0 }} />
                        <span>{getAddressRegion(order.shipping_address) || (lang === "ar" ? "غير محدد" : "Not specified")}</span>
                      </div>
                      <div
                        style={{ fontSize: 11, color: "var(--text-muted)", maxWidth: 190, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", marginTop: 2 }}
                        title={formatAddress(order.shipping_address)}
                      >
                        {formatAddress(order.shipping_address)}
                      </div>
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
            const proofUrl = getMediaUrl(order.payment_proof_url);

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
                              <a href={getMediaUrl(v)} target="_blank" rel="noopener noreferrer" style={{ color: "var(--accent-light)", textDecoration: "none" }}>
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
                      <div style={{ padding: 12, background: "var(--bg-card)", borderRadius: 8, border: "1px solid var(--border)" }}>
                        <strong style={{ color: "var(--text-primary)", display: "flex", alignItems: "center", gap: 6, marginBottom: 6 }}>
                          <MapPin size={14} style={{ color: "var(--accent-light)" }} />
                          <span>{t("shippingAddress")}:</span>
                        </strong>
                        {order.shipping_address.full_name && (
                          <div style={{ fontWeight: 600, fontSize: 13, marginBottom: 2 }}>
                            {order.shipping_address.full_name}
                            {order.shipping_address.phone && (
                              <span style={{ color: "var(--text-muted)", fontWeight: 400 }}> ({order.shipping_address.phone})</span>
                            )}
                          </div>
                        )}
                        <div style={{ fontSize: 13, color: "var(--text-secondary)" }}>
                          {formatAddress(order.shipping_address)}
                        </div>
                        {order.shipping_address.lat && order.shipping_address.lng && (
                          <div style={{ fontSize: 11, color: "var(--accent-light)", marginTop: 4 }}>
                            📍 GPS: {order.shipping_address.lat}, {order.shipping_address.lng}
                          </div>
                        )}
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
