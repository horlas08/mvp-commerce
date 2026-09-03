# General Notice: WebView Performance Improvements

## Overview
This document tracks external store WebView loading performance findings and applied optimizations for the Koon mobile app.

---

## ✅ Fixes Applied (Commit `1895915`)

### 1. WebView Progress Hanging at 85–89%
**Problem:**
On iOS simulator, WebKit (`WKWebView`) would stop updating progress at ~87–89% and never call `onLoadStop` (`didFinishNavigation`). The loading bar spinner stayed on screen permanently even though the page was fully visible to the user. Root cause: background analytics and ad tracking network connections (Google Analytics, GTM, DoubleClick, Clarity) kept open connections which prevented WebKit from considering the page "done".

**Fix:**
- Added a **750ms graceful auto-completion fallback** — once progress ≥ 85%, a timer starts. If WebKit doesn't advance to 100% within 750ms, the app treats the page as done, hides the loading bar, and runs all post-load logic.
- Added **content blockers** for the main culprits: `google-analytics.com`, `googletagmanager.com`, `doubleclick.net`, `clarity.ms`.

**Result:**
```
PROGRESS 87%  -> +8848ms
PROGRESS 100% -> +9254ms   ✅ WebKit reached 100% (ad blockers helped)
PAGE READY    -> 9.26s total
```

---

### 2. Added `onPageCommitVisible` Hook
**Problem:** `_applyHidingAndScraping()` only ran on `onLoadStop`, which was delayed. Product hiding was late.

**Fix:** Connected `onPageCommitVisible` — WebKit's first-paint notification — to immediately trigger hiding/scraping as soon as the first pixels are drawn.

---

### 3. Extracted `_handlePageFinished()` Helper
Consolidated duplicate `onLoadStop` / `progress 100%` / fallback timer logic into a single `_handlePageFinished(url, reason)` method with idempotency guard.

---

### 4. Timer Lifecycle Safety
Fallback timer is cancelled on `onLoadStart`, on `dispose()`, and inside `_handlePageFinished()` — no memory leaks or double-firing.

---

## 📊 Performance Benchmark Log (iPhone 16 Plus Simulator)

| Phase | Duration |
|---|---|
| Card Tap → Route Mount | 17ms |
| Route Mount → WebKit Ready | 620ms |
| WebKit Ready → First Network Request | 2,662ms ⚠️ |
| First Progress Bar Visible | 702ms from tap |
| First Pixels on Screen | 4,836ms from tap |
| Full Page Load | 9,254ms (9.26s) |

> ⚠️ The 2,662ms "WebKit Ready → First Network Request" on SHEIN is caused by a server-side redirect from `ar.shein.com` (desktop) → `m.shein.com/ar-en/` (mobile). Wastes ~2.5s on every load.

---

## 📌 Known Improvement Opportunities (TODO)

| Store | Issue | Fix |
|---|---|---|
| **SHEIN** | Redirect `ar.shein.com` → `m.shein.com` wastes ~2.5s | Update URL to `https://m.shein.com/ar-en/` directly |
| **All stores** | WebKit cold-start costs ~620ms every time | Consider warm/pre-warmed hidden WebView |
| **All stores** | `loadUrl` called 2.6s after WebKit ready | Investigate content blocker compilation time at load |

---

## 🔬 How to Read the Perf Logs

Run the app with `flutter run` and tap any external store card. You will see:

```
================ [PERF TIMELINE START] ================
[PERF] 1. CARD CLICKED
[PERF] 2. WEBVIEW_SCREEN initState
[PERF] 3. ON_WEBVIEW_CREATED (Controller ready)
[PERF] 4. CALLING controller.loadUrl(...)
>>> [PERF] 6. FIRST PROGRESS BAR APPEARED
[PERF] 5. ON_LOAD_START
[PERF] 🚀 ON_PAGE_COMMIT_VISIBLE (First pixels rendered)
[PERF] 7. PROGRESS xx%
...
================ [PERF TIMELINE FINISHED] ================
📊 SUMMARY BREAKDOWN:
   • [Card Tap -> Route Mount]:         Xms
   • [Route Mount -> WebKit Ready]:     Xms
   • [WebKit Ready -> Load Started]:    Xms
   • [Load Started -> First Progress]:  Xms
   • [First Progress -> Finished]:      Xms
   👉 TOTAL TIME (Tap to Finish):       X.XXs
```

---

## 📅 Store Results Log

| Date | Store | Total Load Time | Notes |
|---|---|---|---|
| 2026-09-03 | **SHEIN** | 9.26s | ✅ Fixed stuck at 89%. Redirect penalty: 2.6s |
| 2026-09-03 | **iHerb** | ~14.7s+ (was stuck) | ✅ Stuck-at-89% now fixed via fallback |
| 2026-09-03 | Amazon | — | To be tested |
| 2026-09-03 | AliExpress | — | To be tested |
| 2026-09-03 | Alibaba | — | To be tested |

---

## 📅 Updated Store Results Log

| Date | Store | Total Load (Cold) | Total Load (Warm) | How Finished | Notes |
|---|---|---|---|---|---|
| 2026-09-03 | **SHEIN** | 9.26s | — | `progress 100%` ✅ | Redirect `ar.shein.com`→`m.shein.com` costs 2.6s |
| 2026-09-03 | **iHerb** | ~14.7s (stuck prev.) | — | Auto-fallback ✅ | Fixed: was infinite before |
| 2026-09-03 | **AliExpress** | 6.87s | 4.55s | Auto-fallback (86-89%) ✅ | WebKit real 100% only at ~12s; fallback saves ~5-7s |
| 2026-09-03 | Amazon | — | — | — | To be tested |
| 2026-09-03 | Alibaba | — | — | — | To be tested |

### AliExpress Notes
- AliExpress has very heavy background analytics that push WebKit's "true 100%" to ~10-12s.
- The **auto-fallback at 85%+ fires at 4.5–7s**, giving the user a snappy experience.
- `onProgressChanged` fires before `onLoadStart` on iOS (WKWebView internal ordering), causing negative delta in "Load Started → First Progress" — this is expected and harmless.
- **No further action needed** for AliExpress — the fallback handles it cleanly.
