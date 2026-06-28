"use client";

import { useState } from "react";
import {
  LayoutDashboard,
  ShoppingBag,
  Users,
  Package,
  Tag,
  LogOut,
  Menu,
  MapPin,
  CreditCard,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { useLang } from "@/lib/lang-context";
import LangSwitcher from "./LangSwitcher";
import DashboardPage from "./pages/DashboardPage";
import UsersPage from "./pages/UsersPage";
import ProductsPage from "./pages/ProductsPage";
import OrdersPage from "./pages/OrdersPage";
import CategoriesPage from "./pages/CategoriesPage";
import StatesCitiesPage from "./pages/StatesCitiesPage";
import PaymentMethodsPage from "./pages/PaymentMethodsPage";

type Page = "dashboard" | "users" | "products" | "orders" | "categories" | "statesAndCities" | "paymentMethods";

const NAV_ITEMS = [
  {
    sectionKey: "overview" as const,
    items: [
      { id: "dashboard" as Page, labelKey: "dashboard" as const, icon: LayoutDashboard },
    ],
  },
  {
    sectionKey: "management" as const,
    items: [
      { id: "orders" as Page, labelKey: "orders" as const, icon: ShoppingBag },
      { id: "products" as Page, labelKey: "products" as const, icon: Package },
      { id: "categories" as Page, labelKey: "categories" as const, icon: Tag },
      { id: "statesAndCities" as Page, labelKey: "statesAndCities" as const, icon: MapPin },
      { id: "paymentMethods" as Page, labelKey: "paymentMethods" as const, icon: CreditCard },
      { id: "users" as Page, labelKey: "users" as const, icon: Users },
    ],
  },
];

export default function AdminShell() {
  const { user, logout } = useAuth();
  const { t, lang } = useLang();
  const [currentPage, setCurrentPage] = useState<Page>("dashboard");
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const initials = user?.name
    ?.split(" ")
    .map(n => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2) || "A";

  const renderPage = () => {
    switch (currentPage) {
      case "dashboard": return <DashboardPage onNavigate={setCurrentPage} />;
      case "users": return <UsersPage />;
      case "products": return <ProductsPage />;
      case "orders": return <OrdersPage />;
      case "categories": return <CategoriesPage />;
      case "statesAndCities": return <StatesCitiesPage />;
      case "paymentMethods": return <PaymentMethodsPage />;
    }
  };

  return (
    <div className="admin-layout">
      {/* Sidebar backdrop (mobile) */}
      {sidebarOpen && (
        <div
          style={{
            position: "fixed", inset: 0, background: "rgba(0,0,0,0.6)",
            zIndex: 99, backdropFilter: "blur(2px)",
          }}
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={`sidebar${sidebarOpen ? " open" : ""}`}>
        {/* Logo */}
        <div className="sidebar-logo">
          <div className="logo-icon">K</div>
          <div>
            <div className="logo-text">{t("koonAdmin")}</div>
            <div className="logo-sub">{t("commercePlatform")}</div>
          </div>
        </div>

        {/* Navigation */}
        <nav className="sidebar-nav">
          {NAV_ITEMS.map(section => (
            <div key={section.sectionKey} style={{ marginBottom: 8 }}>
              <div className="nav-section-title">{t(section.sectionKey)}</div>
              {section.items.map(item => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.id}
                    id={`nav-${item.id}`}
                    className={`nav-item${currentPage === item.id ? " active" : ""}`}
                    onClick={() => { setCurrentPage(item.id); setSidebarOpen(false); }}
                  >
                    <Icon size={17} />
                    {t(item.labelKey)}
                  </button>
                );
              })}
            </div>
          ))}
        </nav>

        {/* User profile at bottom */}
        <div style={{
          borderTop: "1px solid var(--border)",
          padding: "16px 12px",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 10 }}>
            <div className="avatar" style={{ width: 36, height: 36, fontSize: 13 }}>{initials}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: "var(--text-primary)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {user?.name}
              </div>
              <div style={{ fontSize: 11, color: "var(--text-muted)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                {user?.email}
              </div>
            </div>
          </div>
          <button
            id="logout-btn"
            className="nav-item"
            onClick={logout}
            style={{ color: "var(--danger)", width: "100%" }}
          >
            <LogOut size={16} />
            {t("signOut")}
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="main-content">
        {/* Topbar */}
        <header className="topbar">
          <button
            className="btn btn-ghost btn-icon"
            onClick={() => setSidebarOpen(true)}
            style={{ display: "none" }}
            id="sidebar-toggle"
          >
            <Menu size={18} />
          </button>
          <div className="topbar-title">{t(currentPage as any)}</div>
          <div className="topbar-actions" style={{ gap: 14 }}>
            <LangSwitcher />
            <div style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              padding: "6px 12px",
              background: "var(--bg-card)",
              border: "1px solid var(--border)",
              borderRadius: 8,
            }}>
              <div className="avatar" style={{ width: 28, height: 28, fontSize: 11 }}>{initials}</div>
              <span style={{ fontSize: 13, fontWeight: 500 }}>{user?.name}</span>
              <span className="badge badge-admin" style={{ fontSize: 10, padding: "1px 7px" }}>{t("adminBadge")}</span>
            </div>
          </div>
        </header>

        {/* Page content */}
        <main className="page-content">
          {renderPage()}
        </main>
      </div>
    </div>
  );
}
