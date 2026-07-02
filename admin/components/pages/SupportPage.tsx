"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { Send, CheckCircle2, MessageSquare, Clock, RefreshCw, Eye } from "lucide-react";
import { adminApi, SupportTicket, SupportMessage } from "@/lib/api";
import { useLang } from "@/lib/lang-context";

export default function SupportPage() {
  const { t } = useLang();
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
      setError(e.message || "Failed to load support tickets");
    } finally {
      setLoadingList(false);
    }
  }, [statusFilter, selectedTicket]);

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
      setError(e.message || "Failed to load messages");
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
    if (!confirm("Are you sure you want to close this ticket? No more replies can be sent once closed.")) return;

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
        borderRadius: 12,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden"
      }}>
        {/* Header and filters */}
        <div style={{ padding: 16, borderBottom: "1px solid var(--border)" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
            <h3 style={{ fontSize: 16, fontWeight: 700, margin: 0 }}>Support Tickets</h3>
            <button className="btn btn-ghost btn-icon" onClick={loadTickets} disabled={loadingList}>
              <RefreshCw size={14} className={loadingList ? "animate-spin" : ""} />
            </button>
          </div>
          <div style={{ display: "flex", gap: 6, overflowX: "auto", paddingBottom: 4 }}>
            <button
              onClick={() => setStatusFilter("")}
              style={{
                padding: "4px 10px", fontSize: 11, borderRadius: 20, border: "none", cursor: "pointer",
                background: statusFilter === "" ? "var(--primary)" : "var(--bg-surface)",
                color: statusFilter === "" ? "#fff" : "var(--text-secondary)"
              }}
            >
              All
            </button>
            <button
              onClick={() => setStatusFilter("open")}
              style={{
                padding: "4px 10px", fontSize: 11, borderRadius: 20, border: "none", cursor: "pointer",
                background: statusFilter === "open" ? "var(--primary)" : "var(--bg-surface)",
                color: statusFilter === "open" ? "#fff" : "var(--text-secondary)"
              }}
            >
              Open
            </button>
            <button
              onClick={() => setStatusFilter("pending")}
              style={{
                padding: "4px 10px", fontSize: 11, borderRadius: 20, border: "none", cursor: "pointer",
                background: statusFilter === "pending" ? "var(--primary)" : "var(--bg-surface)",
                color: statusFilter === "pending" ? "#fff" : "var(--text-secondary)"
              }}
            >
              Pending
            </button>
            <button
              onClick={() => setStatusFilter("closed")}
              style={{
                padding: "4px 10px", fontSize: 11, borderRadius: 20, border: "none", cursor: "pointer",
                background: statusFilter === "closed" ? "var(--primary)" : "var(--bg-surface)",
                color: statusFilter === "closed" ? "#fff" : "var(--text-secondary)"
              }}
            >
              Closed
            </button>
          </div>
        </div>

        {/* Tickets feed */}
        <div style={{ flex: 1, overflowY: "auto", padding: 8 }}>
          {loadingList ? (
            <div style={{ textAlign: "center", padding: 24, color: "var(--text-muted)", fontSize: 13 }}>
              Loading tickets...
            </div>
          ) : tickets.length === 0 ? (
            <div style={{ textAlign: "center", padding: 24, color: "var(--text-muted)", fontSize: 13 }}>
              No tickets found
            </div>
          ) : (
            tickets.map(t => (
              <div
                key={t.id}
                onClick={() => loadMessages(t)}
                style={{
                  padding: 12,
                  borderRadius: 8,
                  marginBottom: 6,
                  cursor: "pointer",
                  border: selectedTicket?.id === t.id ? "1px solid var(--primary)" : "1px solid transparent",
                  background: selectedTicket?.id === t.id ? "var(--primary-light)" : "transparent",
                  transition: "all 0.2s"
                }}
                className="ticket-item-hover"
              >
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 4 }}>
                  <span style={{
                    fontSize: 13, fontWeight: t.admin_unread ? 700 : 600,
                    color: t.admin_unread ? "var(--text-primary)" : "var(--text-secondary)",
                    textOverflow: "ellipsis", overflow: "hidden", whiteSpace: "nowrap", width: 180
                  }}>
                    {t.title}
                  </span>
                  <span style={{
                    fontSize: 10, padding: "2px 6px", borderRadius: 4, fontWeight: 600,
                    background: t.status === "open" ? "#E3F2FD" : t.status === "pending" ? "#FFF3E0" : "#E8F5E9",
                    color: t.status === "open" ? "#1E88E5" : t.status === "pending" ? "#FB8C00" : "#43A047"
                  }}>
                    {t.status.toUpperCase()}
                  </span>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", fontSize: 11, color: "var(--text-muted)" }}>
                  <span>{t.user?.name || "Customer"}</span>
                  <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
                    {t.admin_unread && (
                      <span style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--primary)" }} />
                    )}
                    <span>#{t.id}</span>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Right panel: Chat area */}
      <div style={{
        flex: 1,
        background: "var(--bg-card)",
        border: "1px solid var(--border)",
        borderRadius: 12,
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
                  <h4 style={{ fontSize: 16, fontWeight: 700, margin: 0 }}>{selectedTicket.title}</h4>
                  <span style={{ fontSize: 11, color: "var(--text-muted)" }}>#{selectedTicket.id}</span>
                </div>
                <div style={{ fontSize: 12, color: "var(--text-secondary)", marginTop: 2 }}>
                  Customer: <strong>{selectedTicket.user?.name}</strong> ({selectedTicket.user?.email})
                </div>
              </div>

              {selectedTicket.status !== "closed" && (
                <button
                  onClick={handleCloseTicket}
                  style={{
                    display: "flex", alignItems: "center", gap: 6, padding: "6px 12px",
                    borderRadius: 8, border: "1px solid var(--danger)", background: "transparent",
                    color: "var(--danger)", fontSize: 12, fontWeight: 600, cursor: "pointer"
                  }}
                >
                  <CheckCircle2 size={14} />
                  Close Ticket
                </button>
              )}
            </div>

            {/* Chat message feed */}
            <div style={{ flex: 1, padding: 16, overflowY: "auto", background: "#f8f9fa" }}>
              <div style={{
                background: "#fff", border: "1px solid #e9ecef", borderRadius: 8,
                padding: 12, marginBottom: 20, fontSize: 13, color: "var(--text-secondary)"
              }}>
                <div style={{ fontWeight: 600, marginBottom: 4, display: "flex", alignItems: "center", gap: 6 }}>
                  <MessageSquare size={14} color="var(--primary)" />
                  Initial Description:
                </div>
                {selectedTicket.description}
              </div>

              {loadingChat ? (
                <div style={{ textAlign: "center", padding: 32, color: "var(--text-muted)" }}>
                  Loading conversation...
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
                        maxWidth: "60%",
                        padding: "10px 14px",
                        borderRadius: 16,
                        borderTopLeftRadius: !isAdmin ? 2 : 16,
                        borderTopRightRadius: isAdmin ? 2 : 16,
                        background: isAdmin ? "var(--primary)" : "#fff",
                        color: isAdmin ? "#fff" : "var(--text-primary)",
                        boxShadow: "0 1px 2px rgba(0,0,0,0.05)",
                        fontSize: 13,
                        lineHeight: 1.5
                      }}>
                        <div style={{ whiteSpace: "pre-wrap" }}>{m.message}</div>
                        <div style={{
                          fontSize: 9,
                          textAlign: "right",
                          marginTop: 4,
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
            <div style={{ padding: 16, borderTop: "1px solid var(--border)" }}>
              {selectedTicket.status === "closed" ? (
                <div style={{
                  background: "#e8f5e9", color: "#2e7d32", padding: "10px 14px",
                  borderRadius: 8, fontSize: 13, textAlign: "center", fontWeight: 600
                }}>
                  This ticket has been marked as closed. No further replies can be sent.
                </div>
              ) : (
                <form onSubmit={handleSendReply} style={{ display: "flex", gap: 10 }}>
                  <input
                    type="text"
                    placeholder="Type a reply to the customer..."
                    value={replyText}
                    onChange={(e) => setReplyText(e.target.value)}
                    disabled={sending}
                    style={{
                      flex: 1,
                      padding: "10px 14px",
                      borderRadius: 8,
                      border: "1px solid var(--border)",
                      background: "var(--bg-input)",
                      color: "var(--text-primary)",
                      fontSize: 13,
                      outline: "none"
                    }}
                  />
                  <button
                    type="submit"
                    disabled={!replyText.trim() || sending}
                    style={{
                      background: "var(--primary)",
                      color: "#fff",
                      border: "none",
                      borderRadius: 8,
                      padding: "0 16px",
                      display: "flex",
                      alignItems: "center",
                      gap: 6,
                      fontSize: 13,
                      fontWeight: 600,
                      cursor: replyText.trim() ? "pointer" : "default",
                      opacity: replyText.trim() && !sending ? 1 : 0.6
                    }}
                  >
                    <Send size={14} />
                    Send
                  </button>
                </form>
              )}
            </div>
          </>
        ) : (
          <div style={{
            flex: 1, display: "flex", flexDirection: "column",
            alignItems: "center", justifyContent: "center", color: "var(--text-muted)"
          }}>
            <MessageSquare size={48} style={{ strokeWidth: 1, marginBottom: 12 }} />
            <h4 style={{ fontSize: 16, fontWeight: 600, margin: 0 }}>No Ticket Selected</h4>
            <p style={{ fontSize: 13, marginTop: 4 }}>Select a support ticket from the list to manage and reply.</p>
          </div>
        )}
      </div>
    </div>
  );
}
