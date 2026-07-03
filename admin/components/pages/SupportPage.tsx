"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { Send, CheckCircle2, MessageSquare, Clock, RefreshCw } from "lucide-react";
import { adminApi, SupportTicket, SupportMessage } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

export default function SupportPage() {
  const { t, lang } = useLang();
  const [tickets, setTickets] = useState<SupportTicket[]>([]);
  const [selectedTicket, setSelectedTicket] = useState<SupportTicket | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [replyText, setReplyText] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [loadingList, setLoadingList] = useState(true);
  const [loadingChat, setLoadingChat] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");

  const chatEndRef = useRef<HTMLDivElement>(null);

  const loadTickets = useCallback(async () => {
    setLoadingList(true);
    try {
      const res = await adminApi.listSupportTickets(statusFilter || undefined);
      setTickets(res);
      
      // If a ticket is selected, update it in the list
      if (selectedTicket) {
        const updated = res.find(t => t.id === selectedTicket.id);
        if (updated) setSelectedTicket(updated);
      }
    } catch (e: any) {
      setError(e.message || t("failedToLoad"));
    } finally {
      setLoadingList(false);
    }
  }, [statusFilter, selectedTicket, t]);

  useEffect(() => {
    loadTickets();
  }, [statusFilter]);

  const loadMessages = async (ticket: SupportTicket) => {
    setLoadingChat(true);
    try {
      const msgs = await adminApi.getSupportMessages(ticket.id);
      setMessages(msgs);
      setSelectedTicket(ticket);
      // Mark read locally
      setTickets(prev => prev.map(t => t.id === ticket.id ? { ...t, admin_unread: false } : t));
    } catch (e: any) {
      setError(e.message || t("failedToLoad"));
    } finally {
      setLoadingChat(false);
    }
  };

  useEffect(() => {
    if (chatEndRef.current) {
      chatEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages]);

  const handleSendReply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!replyText.trim() || !selectedTicket || sending) return;

    setSending(true);
    try {
      const newMsg = await adminApi.sendSupportReply(selectedTicket.id, replyText);
      setMessages(prev => [...prev, newMsg]);
      setReplyText("");
      // Update ticket status to pending since admin replied
      setSelectedTicket(prev => prev ? { ...prev, status: "pending" } : null);
      loadTickets();
    } catch (e: any) {
      alert(e.message || "Failed to send message");
    } finally {
      setSending(false);
    }
  };

  const handleCloseTicket = async () => {
    if (!selectedTicket) return;
    if (!confirm(t("closeTicketConfirm"))) return;

    try {
      const updated = await adminApi.closeSupportTicket(selectedTicket.id);
      setSelectedTicket(updated);
      loadTickets();
      // Reload messages to update view
      const msgs = await adminApi.getSupportMessages(selectedTicket.id);
      setMessages(msgs);
    } catch (e: any) {
      alert(e.message || "Failed to close ticket");
    }
  };

  return (
    <div style={{ display: "flex", height: "calc(100vh - 120px)", gap: 20 }}>
      {/* Left panel: tickets list */}
      <div style={{
        width: 320,
        background: "var(--bg-card)",
        border: "1px solid var(--border)",
        borderRadius: 14,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden"
      }}>
        {/* Header and filters */}
        <div style={{ padding: 16, borderBottom: "1px solid var(--border)" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700, margin: 0, color: "var(--text-primary)" }}>{t("supportTickets")}</h3>
            <button className="btn btn-ghost btn-icon btn-sm" onClick={loadTickets} disabled={loadingList}>
              <RefreshCw size={14} className={loadingList ? "spinner" : ""} />
            </button>
          </div>
          <div style={{ display: "flex", gap: 6, overflowX: "auto", paddingBottom: 4 }}>
            {(["", "open", "pending", "closed"] as const).map(s => {
              const isActive = statusFilter === s;
              let label = t("all");
              if (s === "open") label = t("open");
              if (s === "pending") label = t("pending");
              if (s === "closed") label = t("closed");

              return (
                <button
                  key={s}
                  onClick={() => setStatusFilter(s)}
                  style={{
                    padding: "4px 12px",
                    fontSize: 11,
                    borderRadius: 20,
                    border: "none",
                    cursor: "pointer",
                    background: isActive ? "var(--accent)" : "var(--bg-secondary)",
                    color: isActive ? "#fff" : "var(--text-secondary)",
                    fontWeight: 600,
                    transition: "all 0.15s"
                  }}
                >
                  {label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Tickets feed */}
        <div style={{ flex: 1, overflowY: "auto", padding: 8 }}>
          {loadingList ? (
            <div style={{ textAlign: "center", padding: 24, color: "var(--text-muted)", fontSize: 13 }}>
              {t("loadingTickets")}
            </div>
          ) : tickets.length === 0 ? (
            <div style={{ textAlign: "center", padding: 24, color: "var(--text-muted)", fontSize: 13 }}>
              {t("noTicketsFound")}
            </div>
          ) : (
            tickets.map(tItem => {
              const isSelected = selectedTicket?.id === tItem.id;
              let statusBadge = "badge-pending";
              if (tItem.status === "open") statusBadge = "badge-active";
              if (tItem.status === "closed") statusBadge = "badge-inactive";

              return (
                <div
                  key={tItem.id}
                  onClick={() => loadMessages(tItem)}
                  style={{
                    padding: 12,
                    borderRadius: 8,
                    marginBottom: 6,
                    cursor: "pointer",
                    border: isSelected ? "1px solid var(--accent)" : "1px solid transparent",
                    background: isSelected ? "rgba(124, 90, 240, 0.15)" : "transparent",
                    transition: "all 0.2s"
                  }}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 4 }}>
                    <span style={{
                      fontSize: 13,
                      fontWeight: tItem.admin_unread ? 700 : 600,
                      color: isSelected ? "var(--accent-light)" : (tItem.admin_unread ? "var(--text-primary)" : "var(--text-secondary)"),
                      textOverflow: "ellipsis",
                      overflow: "hidden",
                      whiteSpace: "nowrap",
                      width: 170
                    }}>
                      {tItem.title}
                    </span>
                    <span className={`badge ${statusBadge}`} style={{ fontSize: 9, padding: "2px 6px" }}>
                      {t(tItem.status as any).toUpperCase()}
                    </span>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 11, color: "var(--text-muted)" }}>
                    <span>{tItem.user?.name || "Customer"}</span>
                    <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
                      {tItem.admin_unread && (
                        <span style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--accent)" }} />
                      )}
                      <span>#{tItem.id}</span>
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Right panel: Chat area */}
      <div style={{
        flex: 1,
        background: "var(--bg-card)",
        border: "1px solid var(--border)",
        borderRadius: 14,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden"
      }}>
        {selectedTicket ? (
          <>
            {/* Chat header */}
            <div style={{
              padding: 16,
              borderBottom: "1px solid var(--border)",
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center"
            }}>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <h4 style={{ fontSize: 16, fontWeight: 700, margin: 0, color: "var(--text-primary)" }}>{selectedTicket.title}</h4>
                  <span style={{ fontSize: 11, color: "var(--text-muted)" }}>#{selectedTicket.id}</span>
                </div>
                <div style={{ fontSize: 12, color: "var(--text-secondary)", marginTop: 4 }}>
                  {lang === "ar" ? "العميل:" : "Customer:"} <strong>{selectedTicket.user?.name}</strong> ({selectedTicket.user?.email})
                </div>
              </div>

              {selectedTicket.status !== "closed" && (
                <button
                  onClick={handleCloseTicket}
                  className="btn btn-danger btn-sm"
                >
                  <CheckCircle2 size={14} />
                  <span>{t("closeTicket")}</span>
                </button>
              )}
            </div>

            {/* Chat message feed (No hardcoded white bg - fits dark theme & potential light mode) */}
            <div style={{
              flex: 1,
              padding: 16,
              overflowY: "auto",
              background: "var(--bg-secondary)",
            }}>
              {/* Initial description block */}
              <div style={{
                background: "var(--bg-card)",
                border: "1px solid var(--border)",
                borderRadius: 10,
                padding: 14,
                marginBottom: 20,
                fontSize: 13,
                color: "var(--text-secondary)",
                lineHeight: 1.5,
              }}>
                <div style={{ fontWeight: 700, marginBottom: 6, display: "flex", alignItems: "center", gap: 6, color: "var(--text-primary)" }}>
                  <MessageSquare size={14} style={{ color: "var(--accent-light)" }} />
                  {t("initialDescription")}
                </div>
                <div style={{ whiteSpace: "pre-wrap" }}>{selectedTicket.description}</div>
              </div>

              {loadingChat ? (
                <div style={{ textAlign: "center", padding: 32, color: "var(--text-muted)" }}>
                  {t("loadingConversation")}
                </div>
              ) : (
                messages.map(m => {
                  const isAdmin = m.sender === "admin";
                  return (
                    <div
                      key={m.id}
                      style={{
                        display: "flex",
                        justifyContent: isAdmin ? "flex-end" : "flex-start",
                        marginBottom: 12
                      }}
                    >
                      <div style={{
                        maxWidth: "70%",
                        padding: "12px 16px",
                        borderRadius: 16,
                        borderTopLeftRadius: !isAdmin ? 2 : 16,
                        borderTopRightRadius: isAdmin ? 2 : 16,
                        background: isAdmin
                          ? "linear-gradient(135deg, var(--accent), #a855f7)"
                          : "var(--bg-card)",
                        color: isAdmin ? "#ffffff" : "var(--text-primary)",
                        border: isAdmin ? "none" : "1px solid var(--border)",
                        boxShadow: "0 2px 8px rgba(0,0,0,0.15)",
                        fontSize: 13,
                        lineHeight: 1.5
                      }}>
                        <div style={{ whiteSpace: "pre-wrap" }}>{m.message}</div>
                        <div style={{
                          fontSize: 9,
                          textAlign: "right",
                          marginTop: 6,
                          color: isAdmin ? "rgba(255,255,255,0.7)" : "var(--text-muted)"
                        }}>
                          {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </div>
                      </div>
                    </div>
                  );
                })
              )}
              <div ref={chatEndRef} />
            </div>

            {/* Chat footer input */}
            <div style={{ padding: 16, borderTop: "1px solid var(--border)", background: "var(--bg-card)" }}>
              {selectedTicket.status === "closed" ? (
                <div style={{
                  background: "rgba(239,68,68,0.15)",
                  color: "#f87171",
                  border: "1px solid rgba(239,68,68,0.25)",
                  padding: "10px 14px",
                  borderRadius: 8,
                  fontSize: 13,
                  textAlign: "center",
                  fontWeight: 600
                }}>
                  {t("ticketClosedWarning")}
                </div>
              ) : (
                <form onSubmit={handleSendReply} style={{ display: "flex", gap: 10 }}>
                  <input
                    type="text"
                    placeholder={t("replyPlaceholder")}
                    value={replyText}
                    onChange={(e) => setReplyText(e.target.value)}
                    disabled={sending}
                    className="input"
                    style={{ flex: 1 }}
                  />
                  <button
                    type="submit"
                    disabled={!replyText.trim() || sending}
                    className="btn btn-primary"
                    style={{
                      opacity: replyText.trim() && !sending ? 1 : 0.6
                    }}
                  >
                    <Send size={14} />
                    <span>{t("submit")}</span>
                  </button>
                </form>
              )}
            </div>
          </>
        ) : (
          <div style={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            color: "var(--text-muted)"
          }}>
            <MessageSquare size={48} style={{ strokeWidth: 1.2, marginBottom: 12, opacity: 0.5 }} />
            <h4 style={{ fontSize: 16, fontWeight: 600, margin: 0, color: "var(--text-primary)" }}>{t("noTicketSelected")}</h4>
            <p style={{ fontSize: 13, marginTop: 6 }}>{t("selectTicketDesc")}</p>
          </div>
        )}
      </div>
    </div>
  );
}
