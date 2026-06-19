"use client";

import { AuthProvider, useAuth } from "@/lib/auth-context";
import LoginPage from "@/components/LoginPage";
import AdminShell from "@/components/AdminShell";

function AppContent() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "var(--bg-primary)",
      }}>
        <div className="spinner" style={{ width: 40, height: 40, borderWidth: 3 }} />
      </div>
    );
  }

  if (!user) {
    return <LoginPage />;
  }

  return <AdminShell />;
}

export default function Home() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}
