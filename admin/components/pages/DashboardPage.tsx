"use client";

import { useEffect, useState } from "react";
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  PieChart, Pie, Cell,
} from "recharts";
import {
  Users, Package, ShoppingBag, DollarSign, Clock, CheckCircle,
  TrendingUp, ArrowRight,
} from "lucide-react";
import { adminApi, Stats, Order } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

const MOCK_REVENUE = [
  { month: "Jan", revenue: 12000 },
  { month: "Feb", revenue: 19000 },
  { month: "Mar", revenue: 15500 },
  { month: "Apr", revenue: 22000 },
  { month: "May", revenue: 28000 },
  { month: "Jun", revenue: 24500 },
  { month: "Jul", revenue: 31000 },
];

const MONTH_NAMES_AR: Record<string, string> = {
  Jan: "يناير",
  Feb: "فبراير",
  Mar: "مارس",
  Apr: "أبريل",
  May: "مايو",
  Jun: "يونيو",
  Jul: "يوليو",
};

const STATUS_COLORS: Record<string, string> = {
  pending: "#f59e0b",
  confirmed: "#3b82f6",
  processing: "#a855f7",
  shipped: "#06b6d4",
  delivered: "#22c55e",
  cancelled: "#ef4444",
};

function StatCard({
  icon: Icon,
  label,
  value,
  color,
  suffix = "",
}: {
  icon: React.ElementType;
  label: string;
  value: number | string;
  color: string;
  suffix?: string;
}) {
  return (
    <div className={`stat-card ${color}`}>
      <div className={`stat-icon ${color}`}>
        <Icon size={20} />
      </div>
      <div>
        <div className="stat-value">
          {suffix}{typeof value === "number" ? value.toLocaleString() : value}
        </div>
        <div className="stat-label">{label}</div>
      </div>
    </div>
  );
}

interface DashboardPageProps {
  onNavigate: (page: "dashboard" | "users" | "products" | "orders" | "categories") => void;
}

export default function DashboardPage({ onNavigate }: DashboardPageProps) {
  const { t, lang } = useLang();
  const [stats, setStats] = useState<Stats | null>(null);
  const [recentOrders, setRecentOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [orderStatusData, setOrderStatusData] = useState<{ name: string; value: number; color: string }[]>([]);

  useEffect(() => {
    const load = async () => {
      try {
        const [s, o] = await Promise.all([
          adminApi.getStats(),
          adminApi.listOrders({ limit: 5 }),
        ]);
        setStats(s);
        setRecentOrders(o.orders);

        // Build pie data from orders
        const statusCounts: Record<string, number> = {};
        o.orders.forEach(order => {
          statusCounts[order.status] = (statusCounts[order.status] || 0) + 1;
        });
        setOrderStatusData(
          Object.entries(statusCounts).map(([name, value]) => ({
            name,
            value,
            color: STATUS_COLORS[name] || "#7c5af0",
          }))
        );
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  if (loading) {
    return (
      <div style={{ display: "flex", justifyContent: "center", padding: 80 }}>
        <div className="spinner" style={{ width: 40, height: 40, borderWidth: 3 }} />
      </div>
    );
  }

  return (
    <div>
      {/* Stats grid */}
      <div className="stats-grid">
        <StatCard icon={Users} label={t("totalUsers")} value={stats?.total_users ?? 0} color="purple" />
        <StatCard icon={Package} label={t("totalProducts")} value={stats?.total_products ?? 0} color="blue" />
        <StatCard icon={ShoppingBag} label={t("totalOrders")} value={stats?.total_orders ?? 0} color="green" />
        <StatCard icon={DollarSign} label={t("totalRevenue")} value={(stats?.total_revenue ?? 0).toFixed(0)} color="amber" suffix="﷼ " />
        <StatCard icon={Clock} label={t("pendingOrders")} value={stats?.pending_orders ?? 0} color="rose" />
        <StatCard icon={CheckCircle} label={t("activeProducts")} value={stats?.active_products ?? 0} color="cyan" />
      </div>

      {/* Charts */}
      <div className="charts-grid">
        {/* Revenue chart */}
        <div className="card">
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 20 }}>
            <TrendingUp size={18} color="var(--accent-light)" />
            <span style={{ fontWeight: 700, fontSize: 15 }}>{t("revenueOverview")}</span>
            <span style={{
              marginLeft: lang === "ar" ? "0" : "auto",
              marginRight: lang === "ar" ? "auto" : "0",
              fontSize: 12,
              color: "var(--text-muted)"
            }}>{t("last7months")}</span>
          </div>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={MOCK_REVENUE}>
              <defs>
                <linearGradient id="revenueGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#7c5af0" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#7c5af0" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
              <XAxis dataKey="month" tick={{ fill: "var(--text-muted)", fontSize: 12 }} axisLine={false} tickLine={false} tickFormatter={m => lang === "ar" ? MONTH_NAMES_AR[m] || m : m} />
              <YAxis tick={{ fill: "var(--text-muted)", fontSize: 12 }} axisLine={false} tickLine={false} tickFormatter={v => `${(v/1000).toFixed(0)}k`} />
              <Tooltip
                contentStyle={{ background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 8, fontSize: 13 }}
                labelStyle={{ color: "var(--text-primary)" }}
                itemStyle={{ color: "#a78bfa" }}
                formatter={(v: any) => [`﷼ ${Number(v || 0).toLocaleString()}`, t("revenue")]}
              />
              <Area type="monotone" dataKey="revenue" stroke="#7c5af0" strokeWidth={2} fill="url(#revenueGrad)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Order status pie */}
        <div className="card">
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 20 }}>
            <ShoppingBag size={18} color="var(--accent-light)" />
            <span style={{ fontWeight: 700, fontSize: 15 }}>{t("orderStatus")}</span>
          </div>
          {orderStatusData.length > 0 ? (
            <>
              <ResponsiveContainer width="100%" height={160}>
                <PieChart>
                  <Pie data={orderStatusData} cx="50%" cy="50%" innerRadius={45} outerRadius={70} dataKey="value" stroke="none">
                    {orderStatusData.map((entry, i) => (
                      <Cell key={i} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{ background: "var(--bg-card)", border: "1px solid var(--border)", borderRadius: 8, fontSize: 13 }}
                  />
                </PieChart>
              </ResponsiveContainer>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 8, justifyContent: "center" }}>
                {orderStatusData.map(d => (
                  <div key={d.name} style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12 }}>
                    <div style={{ width: 8, height: 8, borderRadius: "50%", background: d.color }} />
                    <span style={{ color: "var(--text-secondary)" }}>{t(d.name as any)} ({d.value})</span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div style={{ display: "flex", alignItems: "center", justifyContent: "center", height: 160, color: "var(--text-muted)", fontSize: 14 }}>
              {t("noOrdersYet")}
            </div>
          )}
        </div>
      </div>

      {/* Recent Orders */}
      <div className="card">
        <div className="section-header" style={{ marginBottom: 16 }}>
          <div style={{ fontWeight: 700, fontSize: 15, display: "flex", alignItems: "center", gap: 8 }}>
            <ShoppingBag size={16} color="var(--accent-light)" />
            {t("recentOrders")}
          </div>
          <button className="btn btn-ghost btn-sm" style={{
            marginLeft: lang === "ar" ? "0" : "auto",
            marginRight: lang === "ar" ? "auto" : "0",
          }} onClick={() => onNavigate("orders")}>
            {t("viewAll")} <ArrowRight size={14} style={{ transform: lang === "ar" ? "rotate(180deg)" : "none" }} />
          </button>
        </div>
        {recentOrders.length === 0 ? (
          <div style={{ textAlign: "center", padding: "32px", color: "var(--text-muted)" }}>{t("noOrdersYet")}</div>
        ) : (
          <div className="table-container" style={{ borderRadius: 10 }}>
            <table>
              <thead>
                <tr>
                  <th>{t("orderId")}</th>
                  <th>{t("customer")}</th>
                  <th>{t("total")}</th>
                  <th>{t("status")}</th>
                  <th>{t("date")}</th>
                </tr>
              </thead>
              <tbody>
                {recentOrders.map(order => (
                  <tr key={order.id}>
                    <td style={{ fontFamily: "monospace", fontSize: 12, color: "var(--text-muted)" }}>
                      #{order.id.slice(0, 8)}
                    </td>
                    <td>
                      <div style={{ fontWeight: 500 }}>{order.user_name || "—"}</div>
                      <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{order.user_email}</div>
                    </td>
                    <td style={{ fontWeight: 600 }}>﷼ {order.total.toFixed(2)}</td>
                    <td>
                      <span className={`badge badge-${order.status}`}>
                        {t(order.status as any)}
                      </span>
                    </td>
                    <td style={{ color: "var(--text-secondary)", fontSize: 13 }}>
                      {new Date(order.created_at).toLocaleDateString(lang === "ar" ? "ar-EG" : "en-US")}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
