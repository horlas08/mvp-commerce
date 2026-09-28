import 'dart:convert';

class ScraperHelper {
  static String buildScraperScript(Map<String, dynamic> config) {
    final hideSelectors = List<String>.from(config['hide_selectors'] ?? []);
    final titleSelector = config['title_selector'] ?? '';
    final priceSelectorsJson = jsonEncode(config['price_selectors'] ?? []);
    final imageSelectorsJson = jsonEncode(config['image_selectors'] ?? []);
    final siteName = config['name'] ?? '';

    // Add footer fallbacks for AliExpress/Alibaba etc
    final nameLower = siteName.toLowerCase();
    if (nameLower.contains('aliexpress') || nameLower.contains('alibaba') || nameLower.contains('shein')) {
      final fallbacks = [
        '.bottom-bar',
        "[class*='bottom-bar']",
        "[class*='bottomBar']",
        "[id*='bottom-bar']",
        "[id*='bottomBar']",
        '.footer-bar',
        "[class*='footer-bar']",
        "[class*='footerBar']",
        "[id*='footer-bar']",
        "[id*='footerBar']",
        '#action-bar',
        '.action-bar',
        "[class*='action-bar']",
        "[class*='actionBar']",
      ];
      for (final f in fallbacks) {
        if (!hideSelectors.contains(f)) {
          hideSelectors.add(f);
        }
      }
    }
    final hideSelectorsJson = jsonEncode(hideSelectors);

    String js = r"""
      (function() {
        'use strict';
        const SELECTORS = __HIDE_SELECTORS_JSON__;

        function isSentinelOrLoader(node) {
          if (!node) return false;
          try {
            const cls = typeof node.className === 'string' ? node.className.toLowerCase() : '';
            const id = (node.id || '').toLowerCase();
            const role = (node.getAttribute && node.getAttribute('role') || '').toLowerCase();
            const testStr = cls + ' ' + id + ' ' + role;
            if (/loading|loadmore|load-more|infinite|sentinel|spinner|pagination|paging|feed-end|feed-bottom|feed_bottom|load_more/i.test(testStr)) {
              return true;
            }
            if (node.querySelector && node.querySelector('[class*="loading"], [class*="spinner"], [class*="infinite"], [class*="sentinel"]')) {
              return true;
            }
          } catch(e) {}
          return false;
        }

        function isBottomBarSelector(sel) {
          return /bottom-bar|bottombar|footer-bar|footerbar|action-bar|actionbar|buy-box|buybox|product-action|product-bottom|goods-detail-bottom/i.test(sel);
        }

        function hideElements() {
          const onPdp = isProductPage();
          for (const sel of SELECTORS) {
            // Bottom-bar and action-bar selectors should ONLY be hidden on Product Detail Pages (PDP)
            // so we do not squash infinite scroll feeds and category page footers.
            if (isBottomBarSelector(sel) && !onPdp) {
              continue;
            }
            try {
              const nodes = document.querySelectorAll(sel);
              nodes.forEach(node => {
                if (!node || !node.tagName) return;
                const tag = node.tagName.toLowerCase();
                if (tag === 'body' || tag === 'html') return;
                if (isSentinelOrLoader(node)) return;
                node.setAttribute('style',
                  'display:none!important;visibility:hidden!important;' +
                  'pointer-events:none!important;opacity:0!important;' +
                  'width:0!important;height:0!important;max-height:0!important;' +
                  'overflow:hidden!important;');
              });
            } catch(e) {}
          }
          // Only unlock modal-locked body/html overflow without forcing 'auto !important'
          // which breaks viewport-level scrolling and IntersectionObserver on WebKit/Chromium.
          try {
            if (document.body && document.body.style && document.body.style.overflow === 'hidden') {
              document.body.style.overflow = '';
            }
            if (document.documentElement && document.documentElement.style && document.documentElement.style.overflow === 'hidden') {
              document.documentElement.style.overflow = '';
            }
          } catch(e) {}
        }
        function simulateClick(el) {
          if (!el) return;
          try {
            if (typeof el.click === 'function') el.click();
          } catch(e) {}
          const events = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'];
          for (const evName of events) {
            try {
              const e = new MouseEvent(evName, {
                bubbles: true,
                cancelable: true,
                view: window
              });
              el.dispatchEvent(e);
            } catch(e) {}
          }
          try {
            if (window.PointerEvent) {
              el.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, cancelable: true, pointerType: 'touch' }));
              el.dispatchEvent(new PointerEvent('pointerup', { bubbles: true, cancelable: true, pointerType: 'touch' }));
            }
          } catch(e) {}
        }
        function imgUrlsMatch(u1, u2) {
          if (!u1 || !u2) return false;
          const clean = u => ('' + u).split('?')[0].replace(/_\d+x\d+.*$/, '').replace(/\.webp$/, '');
          const c1 = clean(u1);
          const c2 = clean(u2);
          if (c1 === c2) return true;
          const f1 = c1.split('/').pop();
          const f2 = c2.split('/').pop();
          if (f1 && f2 && (f1 === f2 || f1.includes(f2) || f2.includes(f1))) return true;
          return false;
        }
        function parsePriceString(text) {
          if (!text) return "";
          if (text.includes('%') || text.includes('٪')) return "";
          const match = text.match(/[\d.,]+/);
          if (!match) return "";
          let numStr = match[0];
          numStr = numStr.replace(/^[.,]+|[.,]+$/g, "");
          if (numStr.includes(',') && numStr.includes('.')) {
            if (numStr.lastIndexOf(',') > numStr.lastIndexOf('.')) {
              numStr = numStr.replace(/\./g, '').replace(',', '.');
            } else {
              numStr = numStr.replace(/,/g, '');
            }
          } else if (numStr.includes(',')) {
            const parts = numStr.split(',');
            if (parts.length > 2 || (parts.length === 2 && parts[1].length === 3)) {
              numStr = numStr.replace(/,/g, '');
            } else {
              numStr = numStr.replace(',', '.');
            }
          } else if (numStr.includes('.')) {
            const parts = numStr.split('.');
            if (parts.length > 2) {
              numStr = numStr.replace(/\./g, '');
            }
          }
          return numStr;
        }
        // Throttle the observer: Alibaba is a heavy SPA that mutates the DOM
        // constantly, so running hideElements() on every mutation pegs the CPU
        // and makes scrolling/loading janky. Coalesce bursts into one run.
        if (!window._hideObserver) {
          window._hidePending = false;
          window._hideObserver = new MutationObserver(() => {
            if (window._hidePending) return;
            window._hidePending = true;
            setTimeout(() => { window._hidePending = false; hideElements(); }, 350);
          });
          window._hideObserver.observe(document.body || document.documentElement, { childList: true, subtree: true, attributes: false });
        }
        if (!window._hideIntervalId) {
          hideElements();
          window._hideIntervalId = setInterval(hideElements, 1200);
        } else {
          hideElements();
        }
        // Parse schema.org Product JSON-LD (most reliable source for title,
        // price & image — works even when the visible DOM uses minified /
        // localized classes like Alibaba's "id-text-[...]" tailwind classes).
        function getJsonLdProduct() {
          try {
            const scripts = document.querySelectorAll('script[type="application/ld+json"]');
            for (const s of scripts) {
              let data;
              try { data = JSON.parse(s.textContent); } catch(e) { continue; }
              const items = Array.isArray(data) ? data : (data['@graph'] ? data['@graph'] : [data]);
              for (const item of items) {
                if (!item || !item['@type']) continue;
                const types = Array.isArray(item['@type']) ? item['@type'] : [item['@type']];
                if (types.indexOf('Product') === -1) continue;
                let offers = item.offers;
                if (Array.isArray(offers)) offers = offers[0];
                let rawPrice = '';
                let currency = '';
                if (offers) {
                  currency = offers.priceCurrency || '';
                  if (offers.lowPrice && offers.highPrice && offers.lowPrice !== offers.highPrice) {
                    rawPrice = offers.lowPrice + ' - ' + offers.highPrice;
                  } else {
                    rawPrice = offers.price || offers.lowPrice || '';
                    if (!rawPrice && offers.priceSpecification) {
                      const specs = Array.isArray(offers.priceSpecification) ? offers.priceSpecification : [offers.priceSpecification];
                      for (const sp of specs) {
                        if (sp && sp.price && (!sp.priceType || !sp.priceType.includes('StrikethroughPrice'))) {
                          rawPrice = sp.price;
                          if (sp.priceCurrency) currency = sp.priceCurrency;
                          break;
                        }
                      }
                      if (!rawPrice && specs[0] && specs[0].price) {
                        rawPrice = specs[0].price;
                        if (specs[0].priceCurrency) currency = specs[0].priceCurrency;
                      }
                    }
                  }
                }
                let priceStr = '';
                if (rawPrice) {
                  const symbols = { USD: '$', EUR: '€', GBP: '£', CNY: '¥', JPY: '¥', SAR: 'SAR ', AED: 'AED ', NGN: '₦' };
                  const sym = symbols[currency];
                  priceStr = sym ? (sym + rawPrice) : (currency ? (currency + ' ' + rawPrice) : ('' + rawPrice));
                }
                let image = '';
                if (item.image) { image = Array.isArray(item.image) ? item.image[0] : item.image; }
                let name = item.name || '';
                if (name && typeof name === 'object') { name = name['@value'] || ''; }
                return { name: ('' + name).trim(), price: priceStr, image: ('' + image).trim() };
              }
            }
          } catch(e) {}
          return null;
        }
        function isPlaceholderValue(v) {
          if (!v) return true;
          return /^(select|choose|please select|pick|请选择|请选择|اختر|حدد)/i.test(('' + v).trim());
        }
        function readBorderBoxOption(box) {
          const img = box.querySelector('img[alt]');
          if (img && img.alt && img.alt.trim()) return img.alt.trim();
          const span = box.querySelector('span');
          return span ? span.textContent.trim() : '';
        }
        function isBorderBoxSelected(box) {
          const cls = box.className || '';
          return /\bselected\b/.test(cls) && !/\bunselected\b/.test(cls);
        }
        function normalizeAttrName(name) {
          return ('' + name).trim().replace(/\(\d+\)$/, '').replace(/[:：]\s*$/, '').trim();
        }
        function isVisibleEl(el) {
          if (!el || !el.getBoundingClientRect) return false;
          const rect = el.getBoundingClientRect();
          if (rect.width <= 0 || rect.height <= 0) return false;
          const style = window.getComputedStyle(el);
          return style.display !== 'none' && style.visibility !== 'hidden' && parseFloat(style.opacity || '1') > 0;
        }
        function upsertSelection(selections, entry) {
          const key = normalizeAttrName(entry.name);
          if (!key) return null;
          let sel = selections.find(s => normalizeAttrName(s.name) === key);
          if (!sel) {
            sel = { name: key, value: entry.value || '', options: [] };
            selections.push(sel);
          }
          (entry.options || []).forEach(o => {
            o = ('' + o).trim();
            if (o && sel.options.indexOf(o) === -1) sel.options.push(o);
          });
          if (entry.value && !isPlaceholderValue(entry.value)) sel.value = entry.value;
          else if (!sel.value && sel.options.length === 1) sel.value = sel.options[0];
          return sel;
        }
        function finalizeSelections(selections) {
          const merged = [];
          selections.forEach(entry => {
            upsertSelection(merged, entry);
          });
          return merged.filter(s => {
            if (s.options.length > 0) return true;
            return s.value && !isPlaceholderValue(s.value);
          }).map(s => {
            if (!s.value && s.options.length === 1) s.value = s.options[0];
            return s;
          });
        }
        function parseSkuListBlock(list, selections) {
          const titleEl = list.querySelector('[data-testid="sku-list-title"] span, [data-testid="sku-list-title"]');
          let name = titleEl ? normalizeAttrName(titleEl.textContent) : '';
          if (!name) return;
          const options = [];
          let value = '';
          list.querySelectorAll('[data-testid="double-bordered-box"]').forEach(box => {
            const opt = readBorderBoxOption(box);
            if (opt && options.indexOf(opt) === -1) options.push(opt);
            if (isBorderBoxSelected(box) && opt) value = opt;
          });
          upsertSelection(selections, { name: name, value: value, options: options });
        }
        function extractSkuMeta() {
          const selections = [];
          let hasVariants = false;
          let requiresSelection = false;
          let minQuantity = 1;
          let selectedQuantity = 0;
          // variant_images: { optionLabel -> imageUrl } gathered from all sources
          const variantImages = {};

          // ── Source 1: Alibaba embedded JSON (skuSummaryAttrs.hotIconUrl) ──────
          try {
            const scripts = document.querySelectorAll('script');
            for (const s of scripts) {
              const txt = s.textContent || '';
              // Look for skuSummaryAttrs JSON which has per-value hotIconUrl fields
              const m = txt.match(/["']skuSummaryAttrs["']\s*:\s*(\[.*?\])(?=\s*[,}])/s);
              if (m) {
                try {
                  const attrs = JSON.parse(m[1]);
                  if (Array.isArray(attrs)) {
                    attrs.forEach(attr => {
                      if (!Array.isArray(attr.values)) return;
                      attr.values.forEach(v => {
                        const label = (v.name || '').trim();
                        const imgUrl = (v.hotIconUrl || v.imageUrl || v.imgUrl || '').trim();
                        if (label && imgUrl) variantImages[label] = imgUrl;
                      });
                    });
                  }
                } catch(e2) {}
              }
              if (Object.keys(variantImages).length > 0) break;
            }
          } catch(e) {}

          // ── Source 2: img elements inside variant selector boxes ─────────────
          // Works for AliExpress and other sites that render swatches as <img>.
          try {
            document.querySelectorAll(
              '[data-testid="double-bordered-box"] img, '
              + '[data-testid="sku-summary-value"] img, '
              + '.sku-item img, .product-sku img, '
              + '[class*="sku"] [class*="swatch"] img, '
              + '[class*="color"] img'
            ).forEach(img => {
              const label = (img.alt || img.getAttribute('title') || '').trim();
              const src = img.src || '';
              if (label && src && src.startsWith('http') && !variantImages[label]) {
                variantImages[label] = src;
              }
            });
          } catch(e) {}

          const skuRoots = [
            document.querySelector('[data-testid="sku-summary"]'),
            document.querySelector('[data-module-name="module_sku"]'),
          ].filter(Boolean);
          skuRoots.forEach(root => {
            hasVariants = true;
            root.querySelectorAll('[data-testid="sku-summary-attr-floor"]').forEach(floor => {
              let name = floor.getAttribute('data-attr-name') || '';
              if (!name) {
                const h = floor.querySelector('h2,h3');
                name = h ? h.textContent.trim().replace(/\(\d+\)$/, '').trim() : '';
              }
              const options = [];
              floor.querySelectorAll('[data-testid="sku-summary-value-name"]').forEach(el => {
                const v = el.textContent.trim();
                if (v && options.indexOf(v) === -1) options.push(v);
              });
              let value = '';
              floor.querySelectorAll('[data-testid="sku-summary-value"]').forEach(el => {
                const cls = (el.className || '') + ' ' + (el.getAttribute('aria-selected') || '');
                const selected = /selected|active|border|ring/i.test(cls);
                const v = el.querySelector('[data-testid="sku-summary-value-name"]');
                if (selected && v) value = v.textContent.trim();
              });
              if (!value && options.length === 1) value = options[0];
              const items = floor.querySelectorAll('[data-testid="sku-summary-value"]');
              if (!value && items.length === 1) {
                const v = items[0].querySelector('[data-testid="sku-summary-value-name"]');
                if (v) value = v.textContent.trim();
              }
              if (!value && options.length > 1) requiresSelection = true;
              if (isPlaceholderValue(value)) requiresSelection = true;
              if (name) upsertSelection(selections, { name: name, value: value, options: options });
            });
            if (!root.querySelector('[data-testid="sku-summary"]')) {
              root.querySelectorAll('[data-testid="sku-list"]').forEach(list => parseSkuListBlock(list, selections));
            }
          });
          document.querySelectorAll('[data-testid="sku-panel-sku-group"]').forEach(group => {
            if (!isVisibleEl(group)) return;
            hasVariants = true;
            let name = group.getAttribute('data-sku-group-name') || '';
            let value = '';
            const h4 = group.querySelector('h4 span, h4');
            if (h4) {
              const text = h4.textContent.trim();
              if (!name && text.indexOf(':') !== -1) {
                const parts = text.split(':');
                name = parts[0].trim();
                value = parts.slice(1).join(':').trim();
              } else if (!name) {
                name = text;
              }
            }
            const options = [];
            group.querySelectorAll('[data-testid="double-bordered-box"]').forEach(box => {
              const opt = readBorderBoxOption(box);
              if (opt && options.indexOf(opt) === -1) options.push(opt);
              if (isBorderBoxSelected(box) && opt) value = opt;
              // Also capture the box image if present
              const boxImg = box.querySelector('img');
              if (boxImg && boxImg.src && boxImg.src.startsWith('http') && opt) {
                variantImages[opt] = variantImages[opt] || boxImg.src;
              }
            });
            if (name) upsertSelection(selections, { name: name, value: value, options: options });
          });
          document.querySelectorAll('[data-testid="sku-panel-sku"]').forEach(panel => {
            if (!isVisibleEl(panel)) return;
            hasVariants = true;
            panel.querySelectorAll('[data-testid="sku-summary-attr-floor"], [data-testid*="attr-floor"]').forEach(floor => {
              let name = floor.getAttribute('data-attr-name') || '';
              if (!name) {
                const h = floor.querySelector('h2,h3');
                name = h ? normalizeAttrName(h.textContent) : '';
              } else {
                name = normalizeAttrName(name);
              }
              if (!name) return;
              const options = [];
              let value = '';
              floor.querySelectorAll('[data-testid="sku-summary-value-name"], [data-testid*="value-name"]').forEach(el => {
                const v = el.textContent.trim();
                if (v && options.indexOf(v) === -1) options.push(v);
              });
              floor.querySelectorAll('[data-testid="sku-summary-value"]').forEach(el => {
                const cls = (el.className || '') + ' ' + (el.getAttribute('aria-selected') || '');
                const selected = /selected|active|border|ring/i.test(cls);
                const v = el.querySelector('[data-testid="sku-summary-value-name"]');
                if (selected && v) value = v.textContent.trim();
                // Capture swatch image
                const swatchImg = el.querySelector('img');
                const label = v ? v.textContent.trim() : '';
                if (swatchImg && swatchImg.src && swatchImg.src.startsWith('http') && label) {
                  variantImages[label] = variantImages[label] || swatchImg.src;
                }
              });
              if (!value && options.length === 1) value = options[0];
              upsertSelection(selections, { name: name, value: value, options: options });
            });
            panel.querySelectorAll('[data-testid="sku-list"]').forEach(list => parseSkuListBlock(list, selections));
          });
          document.querySelectorAll('input[aria-label="Quantity"]').forEach(inp => {
            const q = parseInt(('' + (inp.value || '0')).replace(/[^\d]/g, ''), 10) || 0;
            selectedQuantity += q;
          });
          // Amazon & generic quantity extraction (handles One-Time Purchase & Subscribe & Save)
          try {
            const activeRow = document.querySelector('#buyBoxAccordion .a-accordion-active, .accordion-row.a-accordion-active, .a-accordion-active');
            const qScope = activeRow || document;
            const qSelect = qScope.querySelector('select#rcxsubsQuan, select#quantity, select[name="quantity"], select[name="rcxsubsQuan"]');
            if (qSelect && qSelect.value) {
              const qVal = parseInt(qSelect.value, 10);
              if (qVal > 0) selectedQuantity = qVal;
            } else {
              const qInput = qScope.querySelector('input#quantity, input[name="quantity"], input[name="items[0.base][quantity]"]');
              if (qInput && qInput.value) {
                const qVal = parseInt(qInput.value, 10);
                if (qVal > 0) selectedQuantity = qVal;
              }
            }
          } catch(e) {}
          const ladder = document.querySelector('[data-testid="ladder-prices"]');
          if (ladder) {
            const tier = ladder.querySelector('[class*="text-nowrap"]');
            const tierText = tier ? tier.textContent.trim() : '';
            const m = tierText.match(/(\d+)/);
            if (m) minQuantity = Math.max(minQuantity, parseInt(m[1], 10) || 1);
          }
          const ladderPrice = document.querySelector('[data-testid="ladder-price"]');
          if (ladderPrice) {
            const firstTier = ladderPrice.querySelector('.price-item');
            if (firstTier) {
              const m = firstTier.textContent.match(/(\d+)/);
              if (m) minQuantity = Math.max(minQuantity, parseInt(m[1], 10) || 1);
            }
          }
          const skuScope = document.querySelector('[data-module-name="module_sku"], [data-testid="sku-panel-sku"], [data-testid="product-price"]');
          if (skuScope) {
            const moqMatch = skuScope.textContent.match(/MOQ[:\s]+(\d+)/i);
            if (moqMatch) minQuantity = Math.max(minQuantity, parseInt(moqMatch[1], 10) || 1);
          }
          document.querySelectorAll('#twister .a-row, [id^="variation_"]').forEach(row => {
            const label = row.querySelector('label, .a-form-label');
            const selected = row.querySelector('.selection, .a-dropdown-prompt, .twisterTextDiv');
            const name = label ? label.textContent.trim().replace(':', '') : '';
            const value = selected ? selected.textContent.trim() : '';
            if (name) {
              hasVariants = true;
              if (!value || isPlaceholderValue(value)) requiresSelection = true;
              selections.push({ name: name, value: value, options: value ? [value] : [] });
            }
          });

          // ── Source 4: Shein Specific Variant Selector ───────────────────────
          try {
            // Color Swatches (Style Type)
            const colorHeader = document.querySelector('.bs-main-sales-attr__header-title, #color-heading');
            let colorName = 'اللون';
            if (colorHeader) {
              const raw = colorHeader.textContent.trim().split(/[:：]/)[0].trim();
              colorName = raw || 'اللون';
            }
            const colorItems = document.querySelectorAll('.bs-color__item, [class*="color__item"], .bs-color-circle-image__item');
            if (colorItems.length > 0) {
              hasVariants = true;
              const options = [];
              let value = '';
              colorItems.forEach(el => {
                const opt = (el.getAttribute('aria-label') || el.getAttribute('data-attr_value') || el.textContent.trim()).trim();
                if (opt && options.indexOf(opt) === -1) options.push(opt);
                
                const cls = (el.className || '') + ' ' + (el.getAttribute('aria-selected') || '') + ' ' + (el.getAttribute('aria-checked') || '');
                const selected = /selected|active|true/i.test(cls);
                if (selected && opt) value = opt;

                // Extract image swatch if available
                const img = el.querySelector('img');
                if (img && img.src && img.src.startsWith('http') && opt && !img.alt.includes('hot')) {
                  variantImages[opt] = img.src;
                }
              });
              if (!value && options.length === 1) value = options[0];
              if (!value && options.length > 1) requiresSelection = true;
              if (isPlaceholderValue(value)) requiresSelection = true;
              
              if (colorName) upsertSelection(selections, { name: colorName, value: value, options: options });
            }

            // Size Swatches
            const sizeWrap = document.querySelector('.goods-size__title-wrap');
            const sizeHeader = document.querySelector('.goods-size__title-txt, .goods-size__title-wrap');
            let sizeName = 'المقاس';
            if (sizeWrap && sizeWrap.textContent.trim()) {
              sizeName = sizeWrap.textContent.trim();
            } else if (sizeHeader) {
              const raw = sizeHeader.textContent.trim().split(/[:：]/)[0].trim();
              sizeName = raw.startsWith('مقاس') ? 'المقاس' : (raw || 'المقاس');
            }
            const sizeItems = document.querySelectorAll('.goods-size__sizes-item, [class*="sizes-item"]');
            if (sizeItems.length > 0) {
              hasVariants = true;
              const options = [];
              let value = '';
              sizeItems.forEach(el => {
                if (el.classList.contains('pdp-enhanced') || el.classList.contains('goods-size__options-item')) return;
                const opt = (el.getAttribute('data-attr_value') || el.getAttribute('aria-label') || el.textContent.trim()).trim();
                if (opt && options.indexOf(opt) === -1) options.push(opt);
                
                const cls = (el.className || '') + ' ' + (el.getAttribute('aria-selected') || '') + ' ' + (el.getAttribute('aria-checked') || '');
                const selected = /selected|active|true/i.test(cls);
                if (selected && opt) value = opt;
              });
              if (!value && options.length === 1) value = options[0];
              if (!value && options.length > 1) requiresSelection = true;
              if (isPlaceholderValue(value)) requiresSelection = true;
              
              if (sizeName) upsertSelection(selections, { name: sizeName, value: value, options: options });
            }
          } catch(e) {}

          // ── Source 5: iHerb product grouping (pack size / flavor with navigation) ────
          try {
            const isIherb = window.location.hostname.includes('iherb.') || window.location.href.includes('iherb');
            if (isIherb) {
              const groupingHeader = document.querySelector('[data-testid="product-grouping-header"]');
              const groupName = groupingHeader
                ? groupingHeader.textContent.replace(/[::\u202f]/g, '').trim()
                : 'الخيار';
              const groupItems = document.querySelectorAll('[class*="groupingitem-"]');
              if (groupItems.length > 0) {
                hasVariants = true;
                const opts = [];
                const groupingData = []; // [{label, url, image, price, selected}]
                let selectedVal = '';
                const currentHref = window.location.href;
                const currentPath = window.location.pathname;
                groupItems.forEach(item => {
                  const link = item.querySelector('a');
                  const labelEl = item.querySelector('p');
                  const label = labelEl ? labelEl.textContent.trim() : '';
                  if (!label) return;
                  if (opts.indexOf(label) === -1) opts.push(label);
                  // href for navigation
                  const href = link ? (link.getAttribute('href') || '') : '';
                  const fullUrl = href.startsWith('http') ? href
                    : (href ? (window.location.origin + href.split('#')[0]) : '');
                  // Thumbnail image inside the grouping item (for flavor/form products)
                  const thumbImg = item.querySelector('img');
                  const thumbSrc = thumbImg ? (thumbImg.src || thumbImg.getAttribute('data-src') || '') : '';
                  // Price (secondary LineThroughPrice or any price span)
                  const priceSpan = item.querySelector('[class*="LineThroughPrice"], [class*="StrikeThroughPrice"]');
                  const priceText = priceSpan ? priceSpan.textContent.trim() : '';
                  // Is this the currently viewed product?
                  const idMatch = item.className.match(/groupingitem-(\d+)/);
                  const isCurrent = idMatch && (currentHref.includes('/' + idMatch[1]) || currentPath.includes('/' + idMatch[1]));
                  if (isCurrent) selectedVal = label;
                  groupingData.push({ label, url: fullUrl, image: thumbSrc, price: priceText, selected: !!isCurrent });
                  if (thumbSrc && label) variantImages[label] = thumbSrc;
                });
                // Fallback: use data-testid selected text
                if (!selectedVal) {
                  const selectedText = document.querySelector('[data-testid="product-attribute-selected-text"]');
                  if (selectedText) {
                    const stxt = selectedText.textContent.trim();
                    if (opts.includes(stxt)) {
                      selectedVal = stxt;
                      const gd = groupingData.find(g => g.label === stxt);
                      if (gd) gd.selected = true;
                    }
                  }
                }
                if (!selectedVal && opts.length === 1) { selectedVal = opts[0]; }
                if (!selectedVal && opts.length > 1) requiresSelection = true;
                if (groupName) upsertSelection(selections, { name: groupName, value: selectedVal, options: opts });
                // Attach full grouping data so Dart can navigate on selection
                if (typeof window.__koonIherbGrouping === 'undefined') window.__koonIherbGrouping = {};
                window.__koonIherbGrouping = { name: groupName, items: groupingData, selected: selectedVal };
              }
            }
          } catch(e) {}

          // ── Source 6: AliExpress Mobile SKU parsing ──
          try {
            document.querySelectorAll('[class*="property--"], [class*="property"], [class*="sku--container"] [class*="sku-ui--property"]').forEach(floor => {
              const titleEl = floor.querySelector('[class*="title--"], [class*="title"], [class*="sku-ui--title"]');
              let name = '';
              let value = '';
              if (titleEl) {
                let text = titleEl.textContent || '';
                const valEl = titleEl.querySelector('[class*="skuValue--"], [class*="skuValue"], [class*="sku-ui--skuValue"]');
                if (valEl) {
                  const valText = valEl.textContent || '';
                  value = valText.replace(/^[:：\s]+/, '').trim();
                  text = text.replace(valText, '');
                }
                name = text.replace(/[:：]/g, '').trim();
              }
              if (!name) name = 'الخيار';

              if (!window.__koonAliSkuMap) window.__koonAliSkuMap = {};

              // If a swatch is currently selected and we have a valid human name, cache it immediately!
              const currentSelectedEl = floor.querySelector('[class*="selected"], [class*="dcss-sku-selected"], [aria-selected="true"]');
              if (currentSelectedEl && value) {
                const curCol = currentSelectedEl.getAttribute('data-sku-col');
                if (curCol) window.__koonAliSkuMap[curCol] = value;
                const curImg = currentSelectedEl.querySelector('img');
                if (curImg && curImg.src) window.__koonAliSkuMap[curImg.src.split('?')[0]] = value;
              }

              // One-time synchronous probe on AliExpress to discover swatch names if they have no text/alt
              if (!window.__koonAliSkuProbed) {
                const swatchesToProbe = Array.from(floor.querySelectorAll('[class*="skus--"] > div, [data-sku-col]')).filter(el => {
                  const col = el.getAttribute('data-sku-col');
                  const im = el.querySelector('img');
                  const hasDirectText = (im && (im.alt || im.getAttribute('title'))) || el.textContent.trim();
                  return !hasDirectText && (!col || !window.__koonAliSkuMap[col]);
                });
                if (swatchesToProbe.length > 0) {
                  window.__koonAliSkuProbed = true;
                  const originalSelected = floor.querySelector('[class*="selected"], [class*="dcss-sku-selected"], [aria-selected="true"]');
                  const valElProbe = floor.querySelector('[class*="skuValue--"], [class*="skuValue"], [class*="sku-ui--skuValue"]');
                  try {
                    for (const sw of swatchesToProbe) {
                      simulateClick(sw);
                      const swInner = sw.querySelector('img, span, p');
                      if (swInner) simulateClick(swInner);

                      const swCol = sw.getAttribute('data-sku-col');
                      const readName = valElProbe ? (valElProbe.textContent || '').replace(/^[:：\s]+/, '').trim() : '';
                      if (readName) {
                        if (swCol) window.__koonAliSkuMap[swCol] = readName;
                        const swImg = sw.querySelector('img');
                        if (swImg && swImg.src) window.__koonAliSkuMap[swImg.src.split('?')[0]] = readName;
                      }
                    }
                  } catch(e) {}
                  finally {
                    if (originalSelected) {
                      simulateClick(originalSelected);
                      const origInner = originalSelected.querySelector('img, span, p');
                      if (origInner) simulateClick(origInner);
                    }
                  }
                }
              }

              const options = [];

              floor.querySelectorAll('[class*="skus--"] > div, [data-sku-col], [class*="image--"], [class*="text--"], [class*="sku-ui--image"], [class*="sku-ui--text"]').forEach(el => {
                const img = el.querySelector('img');
                let label = '';
                if (img) {
                  label = (img.alt || img.getAttribute('title') || '').trim();
                } else {
                  label = el.textContent.trim();
                }
                const isSelected = el.className.includes('selected') || el.className.includes('dcss-sku-selected') || el.getAttribute('aria-selected') === 'true';
                if (!label && isSelected && value) {
                  label = value;
                }
                const skuCol = el.getAttribute('data-sku-col');
                if (!label && skuCol && window.__koonAliSkuMap && window.__koonAliSkuMap[skuCol]) {
                  label = window.__koonAliSkuMap[skuCol];
                }
                if (!label && img && img.src && window.__koonAliSkuMap && window.__koonAliSkuMap[img.src.split('?')[0]]) {
                  label = window.__koonAliSkuMap[img.src.split('?')[0]];
                }
                if (!label && skuCol) {
                  label = skuCol;
                }
                if (!label) return;

                if (options.indexOf(label) === -1) options.push(label);

                if (isSelected) {
                  value = label;
                }

                if (img && img.src && img.src.startsWith('http')) {
                  variantImages[label] = img.src;
                }
              });

              if (!value && options.length === 1) value = options[0];
              if (!value && options.length > 1) requiresSelection = true;
              if (isPlaceholderValue(value)) requiresSelection = true;

              if (name) {
                hasVariants = true;
                upsertSelection(selections, { name: name, value: value, options: options });
              }
            });
          } catch(e) {}

          // ── Source 7: Amazon Mobile Inline Twister SKU parsing ──
          try {
            document.querySelectorAll('.inline-twister-row, [id^="inline-twister-row-"]').forEach(floor => {
              let name = '';
              const headerEl = floor.querySelector('.dimension-heading, [id^="inline-twister-dim-title-"]');
              if (headerEl) {
                name = headerEl.textContent.trim().split(':')[0].trim();
              }
              if (!name) return;

              let value = '';
              const selectedValueEl = floor.querySelector('[id^="inline-twister-expanded-dimension-text-"], [id^="inline-twister-collapsed-dimension-text-"]');
              if (selectedValueEl) {
                value = selectedValueEl.textContent.trim();
              }

              const options = [];
              floor.querySelectorAll('.inline-twister-swatch').forEach(swatch => {
                const input = swatch.querySelector('input');
                let label = '';
                if (input && input.getAttribute('aria-label')) {
                  label = input.getAttribute('aria-label').split(',')[0].trim();
                }
                if (!label) {
                  const textDisplay = swatch.querySelector('.swatch-title-text-display');
                  if (textDisplay) label = textDisplay.textContent.trim();
                }
                if (!label) {
                  const img = swatch.querySelector('img');
                  if (img) label = (img.alt || '').trim();
                }
                if (!label) return;

                if (options.indexOf(label) === -1) options.push(label);

                const isSelected = swatch.querySelector('.a-button-selected, .a-button-active');
                if (isSelected && !value) {
                  value = label;
                }

                const swatchImg = swatch.querySelector('img');
                if (swatchImg && swatchImg.src && swatchImg.src.startsWith('http')) {
                  variantImages[label] = swatchImg.src;
                }
              });

              if (!value && options.length === 1) value = options[0];
              if (!value && options.length > 1) requiresSelection = true;

              if (name) {
                hasVariants = true;
                upsertSelection(selections, { name: name, value: value, options: options });
              }
            });
          } catch(e) {}

          // ── Source 7b: Amazon Mobile BuyBox Accordion (One-Time Purchase vs Subscribe & Save) ──
          try {
            const accordionRows = document.querySelectorAll('#buyBoxAccordion .accordion-row, .celwidget.accordion-row');
            if (accordionRows.length > 1) {
              const buyOptions = [];
              let selectedBuyOption = '';
              accordionRows.forEach(row => {
                const headerEl = row.querySelector('.a-accordion-row-a11y, h5, h4, .accordion-header, [class*="header"]');
                let optName = '';
                if (headerEl) {
                  optName = headerEl.textContent.trim().split(/[-–—\n]/)[0].trim();
                }
                if (!optName) {
                  optName = row.id.includes('sns') ? 'خاصية الاشتراك والتوفير' : 'الشراء لمرة واحدة';
                }
                if (optName && buyOptions.indexOf(optName) === -1) buyOptions.push(optName);
                if (row.classList.contains('a-accordion-active')) {
                  selectedBuyOption = optName;
                }
              });
              if (buyOptions.length > 1) {
                hasVariants = true;
                upsertSelection(selections, {
                  name: 'طريقة الشراء',
                  value: selectedBuyOption || buyOptions[0],
                  options: buyOptions
                });
              }

              // Extract delivery frequency when Subscribe & Save is active
              if (selectedBuyOption && selectedBuyOption.includes('اشتراك')) {
                const freqEl = document.querySelector('.replenishment-frequency-popover, #replenishmentFrequencyInformation_feature_div, [id*="FrequencyInformation"]');
                if (freqEl) {
                  const promptEl = freqEl.querySelector('.a-dropdown-prompt, [class*="prompt"], a');
                  const freqVal = promptEl ? promptEl.textContent.trim() : '';
                  if (freqVal) {
                    upsertSelection(selections, {
                      name: 'تكرار التوصيل',
                      value: freqVal,
                      options: [freqVal]
                    });
                  }
                }
              }
            }
          } catch(e) {}

          const finalSelections = finalizeSelections(selections);
          if (finalSelections.length) hasVariants = true;
          finalSelections.forEach(s => {
            if (!s.value && s.options.length > 1) requiresSelection = true;
            if (isPlaceholderValue(s.value)) requiresSelection = true;
          });
          const selectionSummary = finalSelections.filter(s => s.value).map(s => s.name + ': ' + s.value).join(' | ');
          return {
            has_variants: hasVariants,
            requires_selection: requiresSelection,
            selections: finalSelections,
            selection_summary: selectionSummary,
            min_quantity: minQuantity,
            selected_quantity: selectedQuantity,
            variant_images: variantImages,
          };
        }
        function isProductPage() {
          try {
            const url = window.location.href.toLowerCase();
            const host = window.location.hostname.toLowerCase();
            // Aliexpress local dumps that are NOT product pages
            if (url.includes('aliexpress_home') || url.includes('aliexpress_page') ||
                url.includes('page_1') || url.includes('bunde') || url.includes('bundle')) {
              return false;
            }
            // Legacy dump filename guards
            if (url.includes('aliexpress.html') && !url.includes('aliexpress_source')) {
              return false;
            }
            // Any aliexpress local dump named *source* or *detail* is a product page
            if (url.includes('aliexpress_source.html') || url.includes('aliexpress/aliexpress_detail')) {
              return getJsonLdProduct() !== null;
            }
            // Alibaba home dump guard
            if ((url.includes('alibaba_home') || url.includes('alibaba.html')) &&
                !url.includes('alibaba_source') && !url.includes('alibaba_detail')) {
              return false;
            }
            if (url.includes('amazon_home') || url.includes('amazon_main')) {
              return false;
            }
            const isLocal = url.startsWith('file://') || host.includes('localhost') || host.includes('127.0.0.1');
            if (isLocal) {
              if (url.includes('source') || url.includes('detail') || url.includes('product') || url.includes('item')) {
                return true;
              }
              return false;
            }
            if (host.includes('amazon.')) {
              return url.includes('/dp/') || url.includes('/gp/product/');
            }
            if (host.includes('aliexpress.')) {
              return /\/item\/\d+/.test(url);
            }
            if (host.includes('alibaba.')) {
              return url.includes('/product-detail/') || url.includes('/detail/');
            }
            if (host.includes('shein.')) {
              return url.includes('-p-') || url.includes('/goods-') || url.includes('/pd-');
            }
            if (host.includes('iherb.')) {
              return url.includes('/pr/');
            }
          } catch(e) {}
          return true;
        }
        function extractProduct() {
          try {
            if (!isProductPage()) return null;
            const ld = getJsonLdProduct();
            const sku = extractSkuMeta();
            let title = '';
            const titleElem = document.querySelector("__TITLE_SELECTOR__") || document.querySelector('[class*="titleText--"], [class*="titleWrapper"], h1');
            if (titleElem) title = titleElem.textContent.trim();
            if (!title && ld && ld.name) title = ld.name;
            if (!title && document.title) {
              title = document.title.replace(/[-|].*aliexpress.*$/i, '').trim();
            }
            if (!title) return null;

            // Handle site-specific currency detection
            let currency = "";
            if (window.location.hostname.includes("shein.com") || window.location.href.includes("shein")) {
              // Check product:price:currency meta (present on mobile m.shein.com)
              const currencyMeta = document.querySelector(
                'meta[property="product:price:currency"], meta[name="product:price:currency"],' +
                'meta[property="og:price:currency"], meta[name="twitter:price:currency"]'
              );
              if (currencyMeta) {
                currency = currencyMeta.getAttribute('content') || '';
              } else if (window.gbCommonInfo && window.gbCommonInfo.currency) {
                currency = window.gbCommonInfo.currency;
              } else if (window.globalSetting && window.globalSetting.currency && window.globalSetting.currency.cookieValueDefault) {
                currency = window.globalSetting.currency.cookieValueDefault;
              }
              if (currency) currency = currency.toUpperCase().trim();
            }

            const priceSelectors = __PRICE_SELECTORS_JSON__;
            let priceNum = "";
            const isAliExpress = window.location.hostname.includes("aliexpress.") || window.location.href.includes("aliexpress");
            const isAlibaba = window.location.hostname.includes("alibaba.com") || window.location.href.includes("alibaba");

            // ── Priority 0.5: Amazon SA Price – robust multi-source extraction ──
            const isAmazonHost = window.location.hostname.includes("amazon.") || window.location.href.includes("amazon");
            if (isAmazonHost) {
              function pickAmazonNum(text) {
                if (!text) return '';
                const t = text.trim();
                const m = t.match(/\d[\d,]*\.?\d*/);
                if (!m) return '';
                return m[0].replace(/,/g, '');
              }

              let extracted = '';

              // Priority 1: LIVE Core Price Display feature div (updated live by Amazon Twister AJAX)
              if (!extracted) {
                const coreBlock = document.querySelector(
                  '#corePriceDisplay_mobile_feature_div, #corePriceDisplay_desktop_feature_div, #corePrice_feature_div'
                );
                if (coreBlock) {
                  const priceEl = coreBlock.querySelector('.priceToPay, .apex-pricetopay-value, .a-price:not([data-a-strike="true"])');
                  if (priceEl) {
                    const off = priceEl.querySelector('.a-offscreen');
                    if (off && off.textContent && off.textContent.trim()) {
                      extracted = pickAmazonNum(off.textContent);
                    }
                    if (!extracted) {
                      const w = priceEl.querySelector('.a-price-whole');
                      const f = priceEl.querySelector('.a-price-fraction');
                      if (w) {
                        const wd = (w.textContent || '').replace(/[^\d]/g, '');
                        const fd = f ? (f.textContent || '').replace(/[^\d]/g, '') : '';
                        if (wd) extracted = fd ? (wd + '.' + fd) : wd;
                      }
                    }
                  }
                  if (!extracted) {
                    const acc = coreBlock.querySelector('.apex-pricetopay-accessibility-label, [class*="pricetopay-accessibility"]');
                    if (acc) {
                      const raw = (acc.textContent || '').split(/مع|with/i)[0];
                      extracted = pickAmazonNum(raw);
                    }
                  }
                }
              }

              // Priority 2: LIVE Twister Apex price block
              if (!extracted) {
                const apexBlock = document.querySelector(
                  '#apex_price, .apex_on_twister_price, .apex-core-price-identifier'
                );
                if (apexBlock) {
                  const priceEl = apexBlock.querySelector('.priceToPay, .apex-pricetopay-value, .a-price:not([data-a-strike="true"])');
                  if (priceEl) {
                    const off = priceEl.querySelector('.a-offscreen');
                    if (off && off.textContent && off.textContent.trim()) {
                      extracted = pickAmazonNum(off.textContent);
                    }
                    if (!extracted) {
                      const w = priceEl.querySelector('.a-price-whole');
                      const f = priceEl.querySelector('.a-price-fraction');
                      if (w) {
                        const wd = (w.textContent || '').replace(/[^\d]/g, '');
                        const fd = f ? (f.textContent || '').replace(/[^\d]/g, '') : '';
                        if (wd) extracted = fd ? (wd + '.' + fd) : wd;
                      }
                    }
                  }
                  if (!extracted) {
                    const acc = apexBlock.querySelector('.apex-pricetopay-accessibility-label, [class*="pricetopay-accessibility"]');
                    if (acc) {
                      const raw = (acc.textContent || '').split(/مع|with/i)[0];
                      extracted = pickAmazonNum(raw);
                    }
                  }
                }
              }

              // Priority 3: Scoped inside currently ACTIVE accordion row (e.g. One-time purchase vs Subscribe & save)
              if (!extracted) {
                const activeRow = document.querySelector(
                  '#buyBoxAccordion .a-accordion-active, .accordion-row.a-accordion-active, .a-accordion-active, #newAccordionRow_0.a-accordion-active'
                );
                if (activeRow) {
                  const paySpan = activeRow.querySelector('.priceToPay, .apex-pricetopay-value');
                  if (paySpan) {
                    const off = paySpan.querySelector('.a-offscreen');
                    if (off && off.textContent && off.textContent.trim()) {
                      extracted = pickAmazonNum(off.textContent);
                    }
                    if (!extracted) {
                      const w = paySpan.querySelector('.a-price-whole');
                      const f = paySpan.querySelector('.a-price-fraction');
                      if (w) {
                        const wd = (w.textContent || '').replace(/[^\d]/g, '');
                        const fd = f ? (f.textContent || '').replace(/[^\d]/g, '') : '';
                        if (wd) extracted = fd ? (wd + '.' + fd) : wd;
                      }
                    }
                  }
                  if (!extracted) {
                    const acc = activeRow.querySelector('.apex-pricetopay-accessibility-label, [class*="pricetopay-accessibility"]');
                    if (acc) {
                      const raw = (acc.textContent || '').split(/مع|with/i)[0];
                      extracted = pickAmazonNum(raw);
                    }
                  }
                  if (!extracted) {
                    const tp = activeRow.querySelector('#tp_price_block_total_price_ww, #tp-bottom-sheet-subtotal-price-value');
                    if (tp) {
                      const off = tp.querySelector('.a-offscreen');
                      if (off) extracted = pickAmazonNum(off.textContent);
                    }
                  }
                }
              }

              // Priority 4: Total price block
              if (!extracted) {
                const tpBlock = document.querySelector('#tp_price_block_total_price_ww, #tp-bottom-sheet-subtotal-price-value');
                if (tpBlock) {
                  const off = tpBlock.querySelector('.a-offscreen');
                  if (off && off.textContent && off.textContent.trim()) extracted = pickAmazonNum(off.textContent);
                  if (!extracted) {
                    const w = tpBlock.querySelector('.a-price-whole');
                    const f = tpBlock.querySelector('.a-price-fraction');
                    if (w) {
                      const wd = (w.textContent || '').replace(/[^\d]/g, '');
                      const fd = f ? (f.textContent || '').replace(/[^\d]/g, '') : '';
                      if (wd) extracted = fd ? (wd + '.' + fd) : wd;
                    }
                  }
                }
              }

              // Priority 5: Fallback to inputs only if no live visible price was found
              if (!extracted) {
                const custInput = document.querySelector('input[name*="customerVisiblePrice"][name*="amount"], input[id*="customerVisiblePrice"][id*="amount"]');
                if (custInput && custInput.value) {
                  extracted = pickAmazonNum(custInput.value);
                }
              }
              if (!extracted) {
                const tw = document.querySelector('input#twister-plus-price-data-price, #twister-plus-price-data-price');
                if (tw && tw.value) extracted = pickAmazonNum(tw.value);
              }


              // Priority E: Accessibility label ONLY if NOT inside an inactive accordion row
              if (!extracted) {
                const accLabel = document.querySelector('.apex-pricetopay-accessibility-label, [class*="pricetopay-accessibility"]');
                if (accLabel) {
                  const parentRow = accLabel.closest ? accLabel.closest('.accordion-row') : null;
                  if (!parentRow || parentRow.classList.contains('a-accordion-active')) {
                    const raw = (accLabel.textContent || '').split(/مع|with/i)[0];
                    extracted = pickAmazonNum(raw);
                  }
                }
              }

              // Priority F: failsafe .a-offscreen in main container
              if (!extracted) {
                const contentArea = document.querySelector('#dp-container, #centerCol, #ppd, body');
                if (contentArea) {
                  const offscreens = contentArea.querySelectorAll('.a-offscreen');
                  for (const off of offscreens) {
                    const txt = (off.textContent || '').trim();
                    const hasCurrency = txt.includes('SAR') || txt.includes('ريال') || txt.includes('ر.س');
                    const num = txt.match(/\d[\d,]*\.\d+/);
                    if (hasCurrency && num) {
                      const candidate = num[0].replace(/,/g, '');
                      if (parseFloat(candidate) > 10) {
                        extracted = candidate;
                        break;
                      }
                    }
                  }
                }
              }

              if (extracted && parseFloat(extracted) > 0) {
                priceNum = extracted;
                currency = 'SAR';
              }
            }

            // ── Priority 0.8: AliExpress Mobile & Desktop Dedicated Price Extractor ──
            if (isAliExpress && !priceNum) {
              const aliPriceSelectors = [
                '[class*="super"] [class*="price"]',
                '[class*="superDeal"] [class*="price"]',
                '[class*="welcome"] [class*="price"]',
                '[class*="banner"] [class*="price"]',
                '[class*="promo"] [class*="price"]',
                '[class*="activity"] [class*="price"]',
                '[class*="priceWrap"] [class*="current"]',
                '[class*="priceWrap--"] [class*="current--"]',
                '[class*="current--"]',
                '[class*="price-default--current"]',
                '[class*="price-default"]',
                '[class*="product-price-current"]',
                '.product-price-current',
                '[class*="price-sale"]',
                '[class*="price--"]',
                '[class*="priceWrap"]',
                '.uniform-banner-box-price',
                '.es--wrap--erdmPRe .notranslate'
              ];
              for (const sel of aliPriceSelectors) {
                const el = document.querySelector(sel);
                if (el) {
                  const txt = (el.getAttribute('aria-label') || el.textContent || '').trim();
                  const currMatch = txt.match(/(\b(SAR|AED|USD|NGN|EUR|GBP|EGP|QAR|BHD|OMR|KWD)\b|ر\.س|ريال سعودي|ريال|درهم)/);
                  if (currMatch) {
                    currency = currMatch[1].trim();
                  }
                  let pVal = parsePriceString(txt);
                  if (!pVal) {
                    const m = txt.match(/(\d[\d,]*\.?\d*)\s*(?:ر\.س|SAR)/) || txt.match(/(?:ر\.س|SAR)\s*(\d[\d,]*\.?\d*)/) || txt.match(/\d[\d,]*\.\d{2}/);
                    if (m) {
                      pVal = (m[1] || m[0]).replace(/,/g, '');
                    }
                  }
                  if (pVal && parseFloat(pVal) > 0) {
                    priceNum = pVal;
                    if (!currency) currency = 'SAR';
                    break;
                  }
                }
              }
            }

            // ── Priority 1: Live Interactive DOM selectors (for AliExpress, Shein, Alibaba, etc.) ──
            // Checked FIRST so dynamic variant/size/color clicks update immediately rather than being stuck on static meta tags
            if (!priceNum && !isAmazonHost) {
              for (const selector of priceSelectors) {
                const elem = document.querySelector(selector);
                if (elem) {
                  let text = "";
                  if (elem.getAttribute('aria-label')) {
                    text = elem.getAttribute('aria-label');
                  } else {
                    const bffSale = elem.querySelector(
                      '.detail-product-bff-price__sale, [class*="price__sale"],' +
                      '[class*="prices-info__current"], .productPrice__main'
                    );
                    if (bffSale && bffSale.getAttribute('aria-label')) {
                      text = bffSale.getAttribute('aria-label');
                    } else if (bffSale) {
                      text = bffSale.textContent.trim();
                    } else {
                      text = elem.textContent.trim();
                    }
                  }
                  const currMatch = text.match(/(\b(SAR|AED|USD|NGN|EUR|GBP|EGP|QAR|BHD|OMR|KWD)\b|ر\.س|ريال سعودي|ريال|درهم)/);
                  if (currMatch) {
                    currency = currMatch[1].trim();
                  }

                  const pVal = parsePriceString(text);
                  if (pVal) { priceNum = pVal; break; }
                }
              }
            }

            // ── Priority 2: Shein Dynamic State (Pinia store / goodsDetail) ──
            const isShein = window.location.hostname.includes("shein.com") || window.location.href.includes("shein");
            if (isShein && !priceNum) {
              try {
                if (window.goodsDetail && window.goodsDetail.salePrice) {
                  const sp = window.goodsDetail.salePrice;
                  const raw = sp.amount || sp.price || '';
                  const m = ('' + raw).match(/\d+(?:\.\d+)?/);
                  if (m) priceNum = m[0];
                }
              } catch(e) {}
              try {
                if (!priceNum && window.__pinia) {
                  const stores = Object.values(window.__pinia.state.value || {});
                  for (const store of stores) {
                    const sp = store.salePrice || store.goods_sn_price || (store.productInfo && store.productInfo.salePrice);
                    if (sp) {
                      const raw = (typeof sp === 'object') ? (sp.amount || sp.price || '') : sp;
                      const m = ('' + raw).match(/\d+(?:\.\d+)?/);
                      if (m) { priceNum = m[0]; break; }
                    }
                  }
                }
              } catch(e) {}
              try {
                if (!priceNum && window.SaPageInfo && window.SaPageInfo.page_param) {
                  const p = window.SaPageInfo.page_param;
                  const gp = p.goods_price || p.sale_price || '';
                  const m = ('' + gp).match(/\d+(?:\.\d+)?/);
                  if (m) priceNum = m[0];
                }
              } catch(e) {}
            }

            // ── Priority 2.5: iHerb-specific price extraction ──
            const isIherbHost = window.location.hostname.includes('iherb.') || window.location.href.includes('iherb');
            if (isIherbHost && !priceNum) {
              const catApp = document.querySelector('#catalog-application, main, #main-content, body');
              if (catApp) {
                // Check 1: Specific sale or base attribute price element
                const specificPriceEl = catApp.querySelector(
                  '[class*="StrikeThroughPrice"], [class*="BaseAttributePrice"]'
                );
                if (specificPriceEl) {
                  const raw = specificPriceEl.getAttribute('content') || specificPriceEl.textContent || '';
                  const pVal = parsePriceString(raw);
                  if (pVal && parseFloat(pVal) > 0) { priceNum = pVal; currency = 'SAR'; }
                }

                // Check 2: Scoped search inside main product area (before purchasing options/grouping)
                if (!priceNum) {
                  const ppo = catApp.querySelector('#product-purchase-options, #product-grouping');
                  const allElements = catApp.querySelectorAll('span, div, bdi, strong');
                  for (const el of allElements) {
                    // Skip if after purchasing options
                    if (ppo && (el.compareDocumentPosition(ppo) & 2)) {
                      // Node.DOCUMENT_POSITION_PRECEDING = 2, meaning ppo precedes el
                      continue;
                    }
                    // Skip recommendation carousels / other product cards
                    if (el.closest && el.closest('[class*="ProductCardInfo"], [class*="ProductItemView"], [class*="recommendation"], [class*="swiper"]')) {
                      continue;
                    }
                    // Only leaf text nodes (or span containing only bdi)
                    if (el.children.length > 0) {
                      const bdi = el.querySelector('bdi');
                      if (!bdi || el.textContent.trim() !== bdi.textContent.trim()) {
                        continue;
                      }
                    }
                    const t = el.textContent.trim();
                    if (!t || t.length > 35) continue;
                    if (t.includes('%') || t.includes('٪') || t.includes('خصم') || t.includes('وفر') || t.includes('وفّر') ||
                        t.includes('جرعة') || t.includes('حصة') || t.includes('شحن') || t.includes('الطلبات') ||
                        t.includes('مجاني') || t.includes('تقييم') || t.includes('طلب') || t.includes('متاح')) {
                      continue;
                    }
                    if (t.includes('ر.س') || t.includes('SAR')) {
                      const pVal = parsePriceString(t);
                      if (pVal && parseFloat(pVal) > 0) {
                        priceNum = pVal;
                        currency = 'SAR';
                        break;
                      }
                    }
                  }
                }
              }
            }

            // ── Priority 3: Fallback OpenGraph / product meta tags ──
            if (!priceNum && !isAliExpress && !isAlibaba && !isAmazonHost) {
              const priceMeta = document.querySelector(
                'meta[property="product:price:amount"], meta[name="product:price:amount"],' +
                'meta[property="og:price:amount"]'
              );
              if (priceMeta) {
                const raw = priceMeta.getAttribute('content') || '';
                const m = raw.match(/\d+(?:\.\d+)?/);
                if (m) priceNum = m[0];
              }
            }

            // ── Priority 4: JSON-LD ──
            if (!priceNum && !isAliExpress && !isAlibaba && !isAmazonHost && ld && ld.price) {
              const m = ('' + ld.price).match(/\d+(?:\.\d+)?/);
              if (m) priceNum = m[0];
            }

            // ── Priority 5: Last resort – any price-like element ──
            if (!priceNum && !isAmazonHost) {
              const anyPrice = document.querySelector(
                '[class*="sale-price"], [class*="salePrice"], [class*="price-num"],' +
                '[class*="price__sale"], [data-price], [class*="current-price"],' +
                '[class*="productPrice"]'
              );
              if (anyPrice) {
                const lbl = anyPrice.getAttribute('aria-label') || anyPrice.getAttribute('data-price') || anyPrice.textContent || '';
                const currMatch = lbl.match(/(\b(SAR|AED|USD|NGN|EUR|GBP|EGP|QAR|BHD|OMR|KWD)\b|ر\.س|ريال سعودي|ريال|درهم)/);
                if (currMatch) {
                  currency = currMatch[1].trim();
                }
                const pVal = parsePriceString(lbl);
                if (pVal) priceNum = pVal;
              }
            }
            
            let price = "Unknown Price";
            if (priceNum) {
              if (currency) {
                price = currency + " " + priceNum;
              } else {
                price = priceNum;
              }
            }

            const imageSelectors = __IMAGE_SELECTORS_JSON__;
            let imageUrl = "";
            for (const selector of imageSelectors) {
              const elements = document.querySelectorAll(selector);
              for (const elem of elements) {
                let src = elem.getAttribute("data-before-crop-src") || 
                          elem.getAttribute("data-src") || 
                          elem.getAttribute("data-original") || 
                          elem.src || "";
                if (src.startsWith('//')) src = window.location.protocol + src;
                
                // Filter out logo and layout placeholders
                if (src && src.startsWith('http') && 
                    !src.includes('logo') && 
                    !src.includes('loading') && 
                    !src.includes('placeholder')) {
                  imageUrl = src;
                  break;
                }
                
                if (elem.getAttribute("data-a-dynamic-image")) {
                  try {
                    const dyn = JSON.parse(elem.getAttribute("data-a-dynamic-image"));
                    const dynUrl = Object.keys(dyn)[0];
                    if (dynUrl && dynUrl.startsWith('http')) {
                      imageUrl = dynUrl;
                      break;
                    }
                  } catch(e2) {}
                }
              }
              if (imageUrl) break;
            }
            if (!imageUrl && ld && ld.image) { imageUrl = ld.image; }
            const result = Object.assign({
              title: title,
              price: price,
              image_url: imageUrl,
              url: window.location.href,
              site: "__SITE_NAME__",
            }, sku);
            window.__koonVariantImages = (sku && sku.variant_images) || {};
            return result;
          } catch (e) {
            console.warn('[koon] extractProduct error:', e);
            return null;
          }
        }
        window.__koonExtractProduct = extractProduct;
        window.__koonOpenSkuPicker = function() {
          const aliSkuBox = document.querySelector('[class*="container--"][data-appeared], [class*="property--"], [class*="arrowBtn--"], [class*="skuValue--"]');
          if (aliSkuBox) {
            try { aliSkuBox.click(); } catch(e) {}
            try { aliSkuBox.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch(e) {}
            return true;
          }
          const action = document.querySelector('[data-testid="sku-action"]');
          if (action) { action.click(); return true; }
          const layout = document.querySelector('[data-module-name="module_sku"] [data-testid="sku-layout"], [data-testid="sku-summary"]');
          if (layout) { layout.click(); return true; }
          const panel = document.querySelector('[data-testid="sku-panel-sku"]');
          if (panel) { panel.scrollIntoView({ behavior: 'smooth', block: 'center' }); return true; }
          const sheinSize = document.querySelector('.goods-size__sizes-item, [class*="sizes-item"], .goods-size__wrapper');
          if (sheinSize) {
            try { sheinSize.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch(e) {}
            return true;
          }
          return false;
        };
        window.__koonSelectOption = function(name, value, optImgUrl) {
          try {
            function cleanAttr(s) {
              if (!s) return '';
              let t = ('' + s).toLowerCase().replace(/[:：]/g, '').trim();
              return t.replace(/^(ال|al-?)/i, '').trim();
            }

            function matchAttr(a, b) {
              const ca = cleanAttr(a);
              const cb = cleanAttr(b);
              if (!ca || !cb) return false;
              if (ca === cb) return true;
              if ((ca.includes('لون') || ca.includes('color')) && (cb.includes('لون') || cb.includes('color'))) return true;
              if ((ca.includes('حجم') || ca.includes('مقاس') || ca.includes('سعة') || ca.includes('size')) &&
                  (cb.includes('حجم') || cb.includes('مقاس') || cb.includes('سعة') || cb.includes('size'))) return true;
              return false;
            }

            const normVal = ('' + (value || '')).toLowerCase().trim();
            const targetImgUrl = (optImgUrl && ('' + optImgUrl).startsWith('http'))
                ? ('' + optImgUrl)
                : ((window.__koonVariantImages && window.__koonVariantImages[value])
                    ? window.__koonVariantImages[value]
                    : '');

            // Helper: is an element visible (not hidden by display:none or zero size)?
            function isVisible(el) {
              if (!el) return false;
              try {
                if (el.offsetParent === null && getComputedStyle(el).position !== 'fixed') return false;
                const rect = el.getBoundingClientRect();
                return rect.width > 0 || rect.height > 0;
              } catch(e) { return true; }
            }

            // 1. AliExpress Mobile Property Floors
            // Prefer visible popup floor (.wrap--) over hidden scrollbar floor (.scroll--).
            const allFloors = Array.from(document.querySelectorAll('[class*="property--"], [class*="property"], [class*="sku--container"] [class*="sku-ui--property"]'));
            const visibleFloors = allFloors.filter(isVisible);
            const floors = visibleFloors.length > 0 ? visibleFloors : allFloors;
            for (const floor of floors) { // synchronous pass first
              const titleEl = floor.querySelector('[class*="title--"], [class*="title"], [class*="sku-ui--title"]');
              let floorName = '';
              if (titleEl) {
                let text = titleEl.textContent || '';
                const valEl = floor.querySelector('[class*="skuValue--"], [class*="skuValue"], [class*="sku-ui--skuValue"]');
                if (valEl) {
                  const valText = valEl.textContent || '';
                  text = text.replace(valText, '');
                }
                floorName = text.replace(/[:：]/g, '').trim();
              }
              if (!floorName) floorName = 'الخيار';

              if (matchAttr(floorName, name) || (!titleEl && floors.length === 1)) {
                const items = Array.from(floor.querySelectorAll('[class*="skus--"] > div, [data-sku-col], [class*="image--"], [class*="text--"], [class*="sku-ui--skus"] > div, [class*="sku-ui--image"], [class*="sku-ui--text"]'));

                // Pass 1: Direct match via text, cached sku map, image URL, or raw data-sku-col
                for (const item of items) {
                  const img = item.querySelector('img');
                  let label = '';
                  if (img) {
                    label = (img.alt || img.getAttribute('title') || '').trim();
                  } else {
                    label = item.textContent.trim();
                  }
                  const skuCol = item.getAttribute('data-sku-col') || '';
                  if (!label && window.__koonAliSkuMap && skuCol && window.__koonAliSkuMap[skuCol]) {
                    label = window.__koonAliSkuMap[skuCol];
                  }
                  // Direct match on raw SKU col ID stored in selections_json (e.g. "14-10")
                  if (!label && skuCol && skuCol === value) {
                    label = value;
                  }
                  const itemImgSrc = (img && img.src) ? img.src : '';
                  const imgMatch = targetImgUrl && itemImgSrc && imgUrlsMatch(targetImgUrl, itemImgSrc);

                  const normL = label.toLowerCase().trim();
                  const isMatch = (normL && (normL === normVal || normL.includes(normVal) || normVal.includes(normL))) ||
                                  imgMatch ||
                                  (skuCol && skuCol === value);

                  if (isMatch) {
                    const isSelected = item.className.includes('selected') || item.className.includes('dcss-sku-selected') || item.getAttribute('aria-selected') === 'true';
                    if (!isSelected) {
                      simulateClick(item);
                      const inner = item.querySelector('img, span, p');
                      if (inner) simulateClick(inner);
                    }
                    return true;
                  }
                }

                // Pass 2: Async interactive probing - click each swatch and wait for React re-render.
                // We schedule the async work via a captured Promise so the outer function stays sync.
                const currentSelected = floor.querySelector('[class*="selected"], [class*="dcss-sku-selected"], [aria-selected="true"]');
                const valElProbe = floor.querySelector('[class*="skuValue--"], [class*="skuValue"], [class*="sku-ui--skuValue"]');
                const beforeText = valElProbe ? (valElProbe.textContent || '').replace(/^[::\s]+/, '').trim() : '';
                // Store async probe result in window so Dart can poll it
                window.__koonProbeResult = null;
                (async function() {
                  for (const item of items) {
                    if (item === currentSelected) continue;
                    const alreadySel = item.className.includes('selected') || item.getAttribute('aria-selected') === 'true';
                    if (alreadySel) continue;
                    simulateClick(item);
                    const inner = item.querySelector('img, span, p');
                    if (inner) simulateClick(inner);
                    // Poll for React re-render (up to 4 ticks × 50ms = 200ms)
                    let readVal = beforeText;
                    for (let t = 0; t < 4; t++) {
                      await new Promise(r => setTimeout(r, 50));
                      const cur = valElProbe ? (valElProbe.textContent || '').replace(/^[::\s]+/, '').trim() : '';
                      if (cur && cur !== beforeText) { readVal = cur; break; }
                    }
                    const col = item.getAttribute('data-sku-col') || '';
                    if (readVal && readVal !== beforeText) {
                      if (!window.__koonAliSkuMap) window.__koonAliSkuMap = {};
                      if (col) window.__koonAliSkuMap[col] = readVal;
                      const swImg = item.querySelector('img');
                      if (swImg && swImg.src) window.__koonAliSkuMap[swImg.src.split('?')[0]] = readVal;
                      const normRead = readVal.toLowerCase();
                      if (normRead === normVal || normRead.includes(normVal) || normVal.includes(normRead)) {
                        window.__koonProbeResult = true;
                        return;
                      }
                    }
                    // Not a match; restore original and try next
                    if (currentSelected) {
                      simulateClick(currentSelected);
                      const origInner = currentSelected.querySelector('img, span, p');
                      if (origInner) simulateClick(origInner);
                      await new Promise(r => setTimeout(r, 50));
                    }
                  }
                  window.__koonProbeResult = false;
                })();
                // Return 'probing' so Dart knows to poll __koonProbeResult
                return 'probing';
              }
            }

            // 2. AliExpress alternative / popup SKU boxes
            const skuBoxes = document.querySelectorAll('[data-testid="double-bordered-box"], [data-testid="sku-summary-value"]');
            for (const box of skuBoxes) {
              const img = box.querySelector('img');
              const textSpan = box.querySelector('[data-testid="sku-summary-value-name"], span, p');
              let label = (img ? (img.alt || img.title) : '') || (textSpan ? textSpan.textContent : '') || box.textContent || '';
              label = label.trim().toLowerCase();
              const boxImgSrc = (img && img.src) ? img.src.split('?')[0] : '';
              const imgMatch = targetImgUrl && boxImgSrc && (targetImgUrl.includes(boxImgSrc) || boxImgSrc.includes(targetImgUrl));

              if ((label && (label === normVal || label.includes(normVal) || normVal.includes(label))) || imgMatch) {
                const cls = (box.className || '') + ' ' + (box.getAttribute('aria-selected') || '');
                const isSelected = /selected|active|border|ring/i.test(cls);
                if (!isSelected) {
                  simulateClick(box);
                  if (img) simulateClick(img);
                  if (textSpan) simulateClick(textSpan);
                }
                return true;
              }
            }

            // Amazon variation click simulation
            const amazonRows = document.querySelectorAll('.inline-twister-row, [id^="inline-twister-row-"]');
            for (const floor of amazonRows) {
              let floorName = '';
              const headerEl = floor.querySelector('.dimension-heading, [id^="inline-twister-dim-title-"]');
              if (headerEl) {
                floorName = headerEl.textContent.trim().split(':')[0].trim();
              }
              const floorId = (floor.id || '').toLowerCase();
              const isMatchFloor = matchAttr(floorName, name) ||
                (floorId.includes('size') && (cleanAttr(name).includes('size') || cleanAttr(name).includes('حجم') || cleanAttr(name).includes('سعة') || cleanAttr(name).includes('مقاس'))) ||
                (floorId.includes('color') && (cleanAttr(name).includes('color') || cleanAttr(name).includes('لون')));

              if (isMatchFloor) {
                const swatches = floor.querySelectorAll('.inline-twister-swatch');
                for (const swatch of swatches) {
                  const input = swatch.querySelector('input');
                  let label = '';
                  if (input && input.getAttribute('aria-label')) {
                    label = input.getAttribute('aria-label').split(',')[0].trim();
                  }
                  if (!label) {
                    const textDisplay = swatch.querySelector('.swatch-title-text-display');
                    if (textDisplay) label = textDisplay.textContent.trim();
                  }
                  if (!label) {
                    const img = swatch.querySelector('img');
                    if (img) label = (img.alt || '').trim();
                  }
                  const normLabel = label.toLowerCase();
                  if (normLabel && (normLabel === normVal || normLabel.includes(normVal) || normVal.includes(normLabel))) {
                    const isSelected = swatch.querySelector('.a-button-selected, .a-button-active');
                    if (!isSelected) {
                      if (input) {
                        try { if (typeof input.click === 'function') input.click(); } catch(e) {}
                        simulateClick(input);
                      }
                      const btn = swatch.querySelector('.a-button, .a-button-inner, .a-button-text');
                      if (btn) {
                        try { if (typeof btn.click === 'function') btn.click(); } catch(e) {}
                        simulateClick(btn);
                      }
                      simulateClick(swatch);
                    }
                    return true;
                  }
                }
              }
            }
            // Amazon BuyBox purchase method (One-time vs Subscribe & Save)
            if (name === 'طريقة الشراء' || name.toLowerCase().includes('purchase') || name.toLowerCase().includes('شراء')) {
              const rows = document.querySelectorAll('#buyBoxAccordion .accordion-row, .celwidget.accordion-row');
              for (const row of rows) {
                const header = row.querySelector('.a-accordion-row-a11y, h5, h4, .accordion-header, a');
                const rowText = (header ? header.textContent : row.textContent) || '';
                if (rowText.includes(value) || (value.includes('اشتراك') && row.id.includes('sns')) || (value.includes('واحدة') && row.id.includes('newAccordion'))) {
                  simulateClick(header || row);
                  return true;
                }
              }
            }

            // ── SHEIN Size & Color Swatch selection ──
            const isSheinSite = window.location.hostname.includes('shein') || window.location.href.includes('shein') || document.querySelector('.goods-size__sizes-item, .bs-color__item');
            if (isSheinSite) {
              const normName = (name || '').toLowerCase().trim();
              const normVal = (value || '').toLowerCase().trim();
              const isSizeIntent = normName.includes('size') || normName.includes('مقاس') || normName.includes('قياس');
              const isColorIntent = normName.includes('color') || normName.includes('colour') || normName.includes('لون') || normName.includes('style');

              function escapeReg(s) {
                return (s || '').split('').map(function(c) { return '.*+?^()[]{}|\\'.indexOf(c) !== -1 ? '\\' + c : c; }).join('');
              }

              function matchesSheinSize(el, targetVal) {
                const dataVal = (el.getAttribute('data-attr_value') || '').toLowerCase().trim();
                const ariaVal = (el.getAttribute('aria-label') || '').toLowerCase().trim();
                const textVal = (el.textContent || '').toLowerCase().trim();
                if (!dataVal && !ariaVal && !textVal) return false;
                if (dataVal === targetVal || ariaVal === targetVal || textVal === targetVal) return true;

                // Word boundary check on aria or text: e.g. target="xl", aria="44 (xl)"
                const escaped = escapeReg(targetVal);
                const wordRegex = new RegExp('(?:^|[^a-z0-9])' + escaped + '(?:[^a-z0-9]|$)', 'i');
                if (wordRegex.test(ariaVal) || wordRegex.test(textVal) || wordRegex.test(dataVal)) return true;

                // Word boundary check if target has composite text e.g. dataVal="xl", targetVal="44 (xl)"
                if (dataVal) {
                  const dataEsc = escapeReg(dataVal);
                  const dataRegex = new RegExp('(?:^|[^a-z0-9])' + dataEsc + '(?:[^a-z0-9]|$)', 'i');
                  if (dataRegex.test(targetVal)) return true;
                }
                return false;
              }

              function matchesSheinColor(el, targetVal) {
                const dataVal = (el.getAttribute('data-attr_value') || '').toLowerCase().trim();
                const ariaVal = (el.getAttribute('aria-label') || '').toLowerCase().trim();
                const textVal = (el.textContent || '').toLowerCase().trim();
                if (!dataVal && !ariaVal && !textVal) return false;
                if (dataVal === targetVal || ariaVal === targetVal || textVal === targetVal) return true;
                if (ariaVal && (ariaVal.includes(targetVal) || targetVal.includes(ariaVal))) return true;
                return false;
              }

              // Try size items first if size intent or not explicitly color
              if (isSizeIntent || !isColorIntent) {
                const sizeItems = document.querySelectorAll('.goods-size__sizes-item, [class*="sizes-item"], [class*="size__item"], [class*="size-item"]');
                let foundSize = false;
                for (const item of sizeItems) {
                  if (item.classList.contains('pdp-enhanced') || item.classList.contains('goods-size__options-item')) continue;
                  if (matchesSheinSize(item, normVal)) {
                    const cls = (item.className || '') + ' ' + (item.getAttribute('aria-selected') || '') + ' ' + (item.getAttribute('aria-checked') || '');
                    const isSelected = /selected|active|true/i.test(cls);
                    if (!isSelected) {
                      try { item.scrollIntoView({ behavior: 'instant', block: 'nearest' }); } catch(e) {}
                      simulateClick(item);
                      const inner = item.querySelector('p, span, a, div');
                      if (inner) simulateClick(inner);
                    }
                    foundSize = true;
                  }
                }
                if (foundSize) return true;
              }

              // Try color items if color intent or not explicitly size
              if (isColorIntent || !isSizeIntent) {
                const colorItems = document.querySelectorAll('.bs-color__item, [class*="color__item"], .bs-color-circle-image__item');
                let foundColor = false;
                for (const item of colorItems) {
                  if (matchesSheinColor(item, normVal)) {
                    const cls = (item.className || '') + ' ' + (item.getAttribute('aria-selected') || '') + ' ' + (item.getAttribute('aria-checked') || '');
                    const isSelected = /selected|active|true/i.test(cls);
                    if (!isSelected) {
                      try { item.scrollIntoView({ behavior: 'instant', block: 'nearest' }); } catch(e) {}
                      simulateClick(item);
                      const inner = item.querySelector('img, span, div, a');
                      if (inner) simulateClick(inner);
                    }
                    foundColor = true;
                  }
                }
                if (foundColor) return true;
              }
            }

            // ── iHerb Product Grouping (Pack size / Flavor) selection ──
            const isIherbSite = window.location.hostname.includes('iherb.') || window.location.href.includes('iherb');
            if (isIherbSite) {
              const groupItems = document.querySelectorAll('[class*="groupingitem-"]');
              for (const item of groupItems) {
                const p = item.querySelector('p');
                const label = p ? p.textContent.trim() : '';
                const normL = label.toLowerCase();
                const normV = (value || '').toLowerCase().trim();
                if (normL && (normL === normV || normL.includes(normV) || normV.includes(normL))) {
                  const link = item.querySelector('a');
                  if (link) {
                    simulateClick(link);
                    try { link.click(); } catch(e) {}
                    const href = link.getAttribute('href') || link.href || '';
                    if (href && !window.location.href.includes(href.split('#')[0])) {
                      const fullUrl = link.href || (window.location.origin + href.split('#')[0]);
                      window.location.href = fullUrl;
                    }
                    return true;
                  }
                }
              }
            }
          } catch(e) {}
          return false;
        };
        window.__koonGetIherbGrouping = function() {
          return window.__koonIherbGrouping || null;
        };

        function scheduleExtraction(delay) {
          if (window._scraperDebounceTimer) clearTimeout(window._scraperDebounceTimer);
          window._scraperDebounceTimer = setTimeout(() => {
            const product = extractProduct();
            if (window.flutter_inappwebview && product) {
              window.flutter_inappwebview.callHandler('onProductDetected', product);
            }
          }, delay !== undefined ? delay : 100);
        }

        if (!window._koonEventsAttached) {
          window._koonEventsAttached = true;
          document.addEventListener('click', (e) => {
            const target = e.target;
            if (target && target.closest && target.closest(
              'button, a, input, select, label, [role="radio"], [role="tab"], [role="button"],' +
              '.inline-twister-swatch, .accordion-row, .a-accordion-row, [class*="sku"], [class*="swatch"],' +
              '[class*="option"], [class*="item"], [class*="choice"]'
            )) {
              scheduleExtraction(80);
              setTimeout(() => scheduleExtraction(0), 350);
              setTimeout(() => scheduleExtraction(0), 1000);
              setTimeout(() => scheduleExtraction(0), 1500);
            }
          }, { passive: true, capture: true });

          document.addEventListener('change', () => {
            scheduleExtraction(50);
            setTimeout(() => scheduleExtraction(0), 300);
          }, { passive: true, capture: true });

          try {
            const obs = new MutationObserver((mutations) => {
              for (const m of mutations) {
                if (m.type === 'childList' || m.type === 'characterData' ||
                    (m.type === 'attributes' && (m.attributeName === 'class' || m.attributeName === 'value' || m.attributeName === 'aria-selected' || m.attributeName === 'checked'))) {
                  scheduleExtraction(150);
                  break;
                }
              }
            });
            obs.observe(document.body, {
              childList: true,
              subtree: true,
              attributes: true,
              attributeFilter: ['class', 'value', 'aria-selected', 'checked'],
              characterData: true
            });
          } catch(e) {}
        }

        if (!window._scraperIntervalId) {
          window._scraperIntervalId = setInterval(() => {
            try {
              const product = extractProduct();
              if (window.flutter_inappwebview) {
                if (product) {
                  window.flutter_inappwebview.callHandler('onProductDetected', product);
                } else if (!isProductPage()) {
                  window.flutter_inappwebview.callHandler('onProductDetected', null);
                }
              }
            } catch(e) {}
          }, 1000);
        }
      })();
    """;

    js = js.replaceAll('__HIDE_SELECTORS_JSON__', hideSelectorsJson);
    js = js.replaceAll('__TITLE_SELECTOR__', titleSelector);
    js = js.replaceAll('__PRICE_SELECTORS_JSON__', priceSelectorsJson);
    js = js.replaceAll('__IMAGE_SELECTORS_JSON__', imageSelectorsJson);
    js = js.replaceAll('__SITE_NAME__', siteName);
    return js;
  }
}
