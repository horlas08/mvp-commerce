"""
Email notification service for Koon Commerce.

Configure via environment variables (or a .env file loaded by the app):
    SMTP_HOST      — e.g. smtp.gmail.com
    SMTP_PORT      — e.g. 587
    SMTP_USER      — your sending email address
    SMTP_PASSWORD  — your SMTP password / app-password
    ADMIN_EMAIL    — destination for admin order notifications
    APP_NAME       — shown in email subjects (default: Koon Commerce)
"""

import os
import smtplib
import asyncio
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

# ── SMTP configuration (read from env) ────────────────────────────────────────
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD") or os.getenv("SMTP_PASS", "")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@widdistore.com")
APP_NAME = os.getenv("APP_NAME", "Widdi Commerce")


def _send_email_sync(to: str, subject: str, html_body: str) -> None:
    """Blocking SMTP send — called from a thread pool."""
    if not SMTP_USER or not SMTP_PASSWORD:
        print(f"[Email] SMTP not configured — skipping send to {to!r}")
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"{APP_NAME} <{SMTP_USER}>"
    msg["To"] = to
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        # Port 465 usually requires SSL connection from the start
        if SMTP_PORT == 465:
            server = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT)
        else:
            server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
            server.ehlo()
            server.starttls()

        with server:
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_USER, to, msg.as_string())
        print(f"[Email] ✅ Sent '{subject}' → {to}")
    except Exception as exc:
        print(f"[Email] ❌ Failed to send '{subject}' → {to}: {exc}")


async def send_email(to: str, subject: str, html_body: str) -> None:
    """Non-blocking email send (runs in a thread pool)."""
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _send_email_sync, to, subject, html_body)


# ── HTML templates ─────────────────────────────────────────────────────────────

def _items_table_html(items: list) -> str:
    rows = ""
    for it in items:
        rows += f"""
        <tr>
          <td style="padding:8px 12px;border-bottom:1px solid #eee;">{it.get('title','')}</td>
          <td style="padding:8px 12px;border-bottom:1px solid #eee;text-align:center;">{it.get('quantity',1)}</td>
          <td style="padding:8px 12px;border-bottom:1px solid #eee;text-align:right;font-weight:600;">
            {float(it.get('price', 0) or 0):.2f} SAR
          </td>
        </tr>"""
    return rows


def _base_template(title: str, body_html: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <style>
    body {{ font-family: 'Segoe UI', Arial, sans-serif; background:#f5f5f5; margin:0; padding:0; }}
    .container {{ max-width:600px; margin:32px auto; background:#ffffff;
                  border-radius:16px; overflow:hidden; box-shadow:0 4px 24px rgba(0,0,0,.08); }}
    .header {{ background:linear-gradient(135deg,#FF6B00,#FF8A3D);
               padding:32px 24px; text-align:center; }}
    .header h1 {{ color:#fff; margin:0; font-size:24px; font-weight:800; }}
    .header p {{ color:rgba(255,255,255,.85); margin:6px 0 0; font-size:14px; }}
    .body {{ padding:28px 24px; }}
    .body h2 {{ color:#1a1a2e; font-size:18px; margin:0 0 16px; }}
    .body p {{ color:#555; font-size:14px; line-height:1.6; }}
    table {{ width:100%; border-collapse:collapse; margin:16px 0; }}
    th {{ background:#f8f8f8; color:#888; font-size:12px; text-transform:uppercase;
          letter-spacing:.5px; padding:10px 12px; text-align:left; }}
    .total-row td {{ padding:12px; font-weight:700; font-size:16px;
                     border-top:2px solid #FF6B00; color:#FF6B00; }}
    .footer {{ background:#f8f8f8; padding:20px 24px; text-align:center;
               color:#aaa; font-size:12px; }}
    .badge {{ display:inline-block; background:#FF6B00; color:#fff;
              border-radius:20px; padding:4px 14px; font-size:12px; font-weight:700; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>{APP_NAME}</h1>
      <p>{title}</p>
    </div>
    <div class="body">
      {body_html}
    </div>
    <div class="footer">
      © {APP_NAME} · All rights reserved
    </div>
  </div>
</body>
</html>"""


async def send_order_confirmation(
    user_email: str,
    user_name: str,
    order: dict,
    is_wallet: bool = False,
) -> None:
    """Send order confirmation email to the customer."""
    order_id = str(order.get("id", ""))[:8].upper()
    total = float(order.get("total", 0))
    items = order.get("items", [])
    rows = _items_table_html(items)

    if is_wallet:
        status_msg = "<p style='color:#27ae60;font-weight:600;'>✅ Payment confirmed via Wallet. Your order is being processed.</p>"
    else:
        status_msg = "<p style='color:#e67e22;font-weight:600;'>⏳ Your order is pending payment approval by our team. You will be notified once approved.</p>"

    body = f"""
    <h2>Hi {user_name}, your order has been placed! 🎉</h2>
    <p>Thank you for shopping with {APP_NAME}. Here's a summary of your order:</p>

    <p><strong>Order ID:</strong> <span class="badge">#{order_id}</span></p>
    {status_msg}

    <table>
      <thead>
        <tr>
          <th>Item</th>
          <th style="text-align:center;">Qty</th>
          <th style="text-align:right;">Price</th>
        </tr>
      </thead>
      <tbody>
        {rows}
      </tbody>
      <tfoot>
        <tr class="total-row">
          <td colspan="2">Total</td>
          <td style="text-align:right;">{total:.2f} SAR</td>
        </tr>
      </tfoot>
    </table>

    <p style="color:#888;font-size:13px;">
      We will process your order shortly and notify you of any updates.<br/>
      If you have questions, reply to this email or contact our support team.
    </p>
    """

    html = _base_template("Order Confirmation", body)
    subject = f"[{APP_NAME}] Order #{order_id} Confirmed ✅" if is_wallet else f"[{APP_NAME}] Order #{order_id} Pending Approval ⏳"
    await send_email(
        to=user_email,
        subject=subject,
        html_body=html,
    )


async def send_admin_order_notification(
    order: dict,
    user_email: str,
    user_name: str,
    payment_method: str,
    payment_proof_url: Optional[str] = None,
    additional_note: Optional[str] = None,
) -> None:
    """Send new-order notification email to the admin."""
    order_id = str(order.get("id", ""))[:8].upper()
    total = float(order.get("total", 0))
    items = order.get("items", [])
    rows = _items_table_html(items)

    proof_section = ""
    if payment_proof_url:
        proof_section = f"""
        <p><strong>Payment Proof:</strong><br/>
        <a href="{payment_proof_url}" target="_blank"
           style="color:#FF6B00;font-weight:600;">View uploaded proof image →</a></p>"""

    note_section = ""
    if additional_note:
        note_section = f"""
        <p><strong>Customer Note:</strong><br/>
        <em style="color:#666;">"{additional_note}"</em></p>"""

    body = f"""
    <h2>🛒 New Order Received — #{order_id}</h2>

    <p><strong>Customer:</strong> {user_name} ({user_email})</p>
    <p><strong>Payment Method:</strong> {payment_method}</p>
    {proof_section}
    {note_section}

    <table>
      <thead>
        <tr>
          <th>Item</th>
          <th style="text-align:center;">Qty</th>
          <th style="text-align:right;">Price</th>
        </tr>
      </thead>
      <tbody>
        {rows}
      </tbody>
      <tfoot>
        <tr class="total-row">
          <td colspan="2">Order Total</td>
          <td style="text-align:right;">{total:.2f} SAR</td>
        </tr>
      </tfoot>
    </table>

    <p style="color:#888;font-size:13px;">
      Please log in to the admin dashboard to review and process this order.
    </p>
    """

    html = _base_template("New Order Notification", body)
    await send_email(
        to=ADMIN_EMAIL,
        subject=f"[{APP_NAME}] New Order #{order_id} from {user_name}",
        html_body=html,
    )


async def send_verification_email(to_email: str, name: str, code: str) -> None:
    """Send a verification code email to the user."""
    body = f"""
    <h2>Welcome to {APP_NAME}, {name}!</h2>
    <p>Thank you for registering. Please use the following 6-digit code to verify your email address:</p>
    <div style="text-align:center; margin:24px 0;">
        <span style="font-size:32px; font-weight:800; letter-spacing:6px; color:#FF6B00; background:#FFF0E6; padding:12px 24px; border-radius:8px; display:inline-block;">{code}</span>
    </div>
    <p>This code will expire shortly. If you did not request this code, please ignore this email.</p>
    """
    html = _base_template("Verify Your Email Address", body)
    await send_email(
        to=to_email,
        subject=f"[{APP_NAME}] Email Verification Code: {code}",
        html_body=html,
    )


async def send_password_reset_email(to_email: str, name: str, code: str) -> None:
    """Send a password reset code email to the user."""
    body = f"""
    <h2>Password Reset Request</h2>
    <p>Hello {name},</p>
    <p>We received a request to reset your password. Please use the following 6-digit verification code to proceed:</p>
    <div style="text-align:center; margin:24px 0;">
        <span style="font-size:32px; font-weight:800; letter-spacing:6px; color:#FF6B00; background:#FFF0E6; padding:12px 24px; border-radius:8px; display:inline-block;">{code}</span>
    </div>
    <p>This code is valid for a limited time. If you did not request a password reset, please ignore this email.</p>
    """
    html = _base_template("Reset Your Password", body)
    await send_email(
        to=to_email,
        subject=f"[{APP_NAME}] Password Reset Code: {code}",
        html_body=html,
    )


async def send_payment_approved_email(user_email: str, user_name: str, order_id: str, total: float) -> None:
    """Notify user that their manual payment has been approved."""
    short_id = order_id[:8].upper()
    body = f"""
    <h2>✅ Payment Approved — Order #{short_id}</h2>
    <p>Hi {user_name},</p>
    <p>Great news! Your payment for order <strong>#{short_id}</strong> (Total: {total:.2f} SAR) has been <strong>approved</strong> by our team.</p>
    <p>Your order is now being processed. You will receive updates as it progresses.</p>
    """
    html = _base_template("Payment Approved", body)
    await send_email(
        to=user_email,
        subject=f"[{APP_NAME}] Payment Approved for Order #{short_id} ✅",
        html_body=html,
    )


async def send_payment_rejected_email(user_email: str, user_name: str, order_id: str, total: float, reason: Optional[str] = None) -> None:
    """Notify user that their manual payment has been rejected."""
    short_id = order_id[:8].upper()
    reason_section = f"<p><strong>Reason:</strong> {reason}</p>" if reason else ""
    body = f"""
    <h2>❌ Payment Rejected — Order #{short_id}</h2>
    <p>Hi {user_name},</p>
    <p>We're sorry, but your payment for order <strong>#{short_id}</strong> (Total: {total:.2f} SAR) could not be verified and has been <strong>rejected</strong>.</p>
    {reason_section}
    <p>Your order has been cancelled. If you believe this is an error, please contact our support team.</p>
    """
    html = _base_template("Payment Rejected", body)
    await send_email(
        to=user_email,
        subject=f"[{APP_NAME}] Payment Rejected for Order #{short_id} ❌",
        html_body=html,
    )


async def send_refund_status_email(user_email: str, user_name: str, order_id: str, amount: float, approved: bool, admin_note: Optional[str] = None) -> None:
    """Notify user of refund approval or rejection."""
    short_id = order_id[:8].upper()
    if approved:
        title = f"✅ Refund Approved — Order #{short_id}"
        msg = f"Your refund of <strong>{amount:.2f} SAR</strong> for order #{short_id} has been <strong>approved</strong> and credited to your wallet."
    else:
        title = f"❌ Refund Rejected — Order #{short_id}"
        msg = f"Your refund request for order #{short_id} has been <strong>rejected</strong>."
    note_section = f"<p><strong>Admin Note:</strong> {admin_note}</p>" if admin_note else ""
    body = f"""
    <h2>{title}</h2>
    <p>Hi {user_name},</p>
    <p>{msg}</p>
    {note_section}
    <p>If you have questions, please contact our support team.</p>
    """
    html = _base_template(title, body)
    await send_email(
        to=user_email,
        subject=f"[{APP_NAME}] {title}",
        html_body=html,
    )


async def send_admin_contact_to_user_email(user_email: str, user_name: str, order_id: str, admin_message: str) -> None:
    """Admin-initiated email to user regarding a specific order. Creates a support thread."""
    short_id = order_id[:8].upper()
    body = f"""
    <h2>Message from {APP_NAME} Support — Order #{short_id}</h2>
    <p>Hi {user_name},</p>
    <p>Our team has reached out regarding your order <strong>#{short_id}</strong>:</p>
    <blockquote style="border-left:4px solid #FF6B00; padding:12px 24px; color:#555; background:#f9f9f9; margin:16px 0;">
      {admin_message}
    </blockquote>
    <p>Please log in to the app to reply to this message in the support chat.</p>
    """
    html = _base_template(f"Message Regarding Order #{short_id}", body)
    await send_email(
        to=user_email,
        subject=f"[{APP_NAME}] Support Message for Order #{short_id}",
        html_body=html,
    )


async def send_admin_support_alert(ticket_title: str, ticket_description: str, username: str, user_email: str, is_new: bool = True) -> None:
    """Notify the admin of a new support ticket or customer reply."""
    action_text = "New Support Ticket Created" if is_new else "New Reply on Support Ticket"
    subject = f"[{APP_NAME}] {action_text}: {ticket_title}"
    body = f"""
    <h2>{action_text}</h2>
    <p><strong>User:</strong> {username} ({user_email})</p>
    <p><strong>Title:</strong> {ticket_title}</p>
    <p><strong>Message / Description:</strong></p>
    <blockquote style="border-left:4px solid #FF6B00; padding:12px 24px; color:#555; background:#f9f9f9; margin:16px 0;">
      {ticket_description}
    </blockquote>
    <p>Please log in to the admin dashboard to review and reply to this ticket.</p>
    """
    html = _base_template(action_text, body)
    await send_email(
        to=ADMIN_EMAIL,
        subject=subject,
        html_body=html,
    )

