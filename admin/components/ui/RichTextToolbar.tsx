"use client";

import React from "react";

interface RichTextToolbarProps {
  textareaId: string;
  onInsert: (text: string) => void;
}

export default function RichTextToolbar({ textareaId, onInsert }: RichTextToolbarProps) {
  const wrapSelection = (prefix: string, suffix: string, defaultText: string = "text") => {
    const el = document.getElementById(textareaId) as HTMLTextAreaElement | null;
    if (!el) {
      onInsert(`${prefix}${defaultText}${suffix}`);
      return;
    }
    const start = el.selectionStart;
    const end = el.selectionEnd;
    const selected = el.value.substring(start, end) || defaultText;
    const replacement = `${prefix}${selected}${suffix}`;
    const before = el.value.substring(0, start);
    const after = el.value.substring(end);
    el.value = `${before}${replacement}${after}`;
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.focus();
    el.setSelectionRange(start + prefix.length, start + prefix.length + selected.length);
  };

  const insertTable = () => {
    const tableHtml = `
<table style="width:100%; border-collapse:collapse; margin:12px 0;">
  <thead>
    <tr style="background:#f8f9fa;">
      <th style="border:1px solid #ddd; padding:8px;">الحجم / Size</th>
      <th style="border:1px solid #ddd; padding:8px;">الصدر / Chest</th>
      <th style="border:1px solid #ddd; padding:8px;">الطول / Length</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">S (38-40)</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">100 cm</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">138 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">M (42-44)</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">108 cm</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">138 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">L (46-48)</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">120 cm</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">138 cm</td>
    </tr>
    <tr>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">XL (50-52)</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">128 cm</td>
      <td style="border:1px solid #ddd; padding:8px; text-align:center;">138 cm</td>
    </tr>
  </tbody>
</table>
`;
    wrapSelection("", tableHtml, "");
  };

  const insertHighlightBadge = (color: string) => {
    wrapSelection(
      `<span style="color:${color}; font-weight:bold; font-size:15px;">`,
      `</span>`,
      "ميزة المنتج"
    );
  };

  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 4, marginBottom: 6, alignItems: "center" }}>
      <button
        type="button"
        className="btn btn-ghost"
        style={{ padding: "2px 8px", fontSize: 12, height: "auto" }}
        onClick={() => wrapSelection("<b>", "</b>", "نص عريض")}
        title="Bold"
      >
        <b>B</b>
      </button>
      <button
        type="button"
        className="btn btn-ghost"
        style={{ padding: "2px 8px", fontSize: 12, height: "auto" }}
        onClick={() => wrapSelection("<i>", "</i>", "نص مائل")}
        title="Italic"
      >
        <i>I</i>
      </button>
      <button
        type="button"
        className="btn btn-ghost"
        style={{ padding: "2px 8px", fontSize: 12, height: "auto" }}
        onClick={() => wrapSelection("<h3>", "</h3>", "عنوان")}
        title="Heading"
      >
        H3
      </button>
      <button
        type="button"
        className="btn btn-ghost"
        style={{ padding: "2px 8px", fontSize: 12, height: "auto" }}
        onClick={() => wrapSelection("<ul>\n  <li>", "</li>\n</ul>", "نقطة")}
        title="Bullet List"
      >
        • List
      </button>

      {/* Color tags */}
      <button
        type="button"
        className="btn btn-ghost"
        style={{ padding: "2px 6px", fontSize: 11, height: "auto", color: "#e91e63", borderColor: "#e91e63" }}
        onClick={() => insertHighlightBadge("#e91e63")}
        title="Pink Highlight Badge"
      >
        🏷️ Pink Tag
      </button>
      <button
        type="button"
        className="btn btn-ghost"
        style={{ padding: "2px 6px", fontSize: 11, height: "auto", color: "#ff6b00", borderColor: "#ff6b00" }}
        onClick={() => insertHighlightBadge("#ff6b00")}
        title="Orange Highlight Badge"
      >
        🏷️ Orange Tag
      </button>

      {/* Table insert */}
      <button
        type="button"
        className="btn btn-ghost"
        style={{ padding: "2px 8px", fontSize: 11, height: "auto", background: "#f0f4f8" }}
        onClick={insertTable}
        title="Insert Size/Measurement Table"
      >
        📊 جدول المقاسات (Table)
      </button>
    </div>
  );
}
