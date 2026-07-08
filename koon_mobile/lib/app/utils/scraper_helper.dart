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
        function hideElements() {
          for (const sel of SELECTORS) {
            try {
              const nodes = document.querySelectorAll(sel);
              nodes.forEach(node => {
                if (node.tagName && (node.tagName.toLowerCase() === 'body' || node.tagName.toLowerCase() === 'html')) {
                  return;
                }
                node.setAttribute('style',
                  'display:none!important;visibility:hidden!important;' +
                  'pointer-events:none!important;opacity:0!important;' +
                  'width:0!important;height:0!important;max-height:0!important;' +
                  'overflow:hidden!important;');
              });
            } catch(e) {}
          }
          try {
            document.body.style.setProperty('overflow', 'auto', 'important');
            document.documentElement.style.setProperty('overflow', 'auto', 'important');
          } catch(e) {}
        }
        function parsePriceString(text) {
          if (!text) return "";
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
                    rawPrice = offers.price || offers.lowPrice ||
                      (offers.priceSpecification && offers.priceSpecification.price) || '';
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
            const colorName = colorHeader ? colorHeader.textContent.trim().replace(/[:：]\s*$/, '') : 'Style Type';
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
            const sizeHeader = document.querySelector('.goods-size__title-txt, .goods-size__title-wrap');
            const sizeName = sizeHeader ? sizeHeader.textContent.trim().replace(/[:：]\s*$/, '') : 'Size';
            const sizeItems = document.querySelectorAll('.goods-size__sizes-item, [class*="sizes-item"]');
            if (sizeItems.length > 0) {
              hasVariants = true;
              const options = [];
              let value = '';
              sizeItems.forEach(el => {
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
            document.querySelectorAll('[class*="sku--container"] [class*="sku-ui--property"]').forEach(floor => {
              const titleEl = floor.querySelector('[class*="sku-ui--title"]');
              let name = '';
              if (titleEl) {
                let text = titleEl.textContent || '';
                const valEl = titleEl.querySelector('[class*="sku-ui--skuValue"]');
                if (valEl) {
                  const valText = valEl.textContent || '';
                  text = text.replace(valText, '');
                }
                name = text.replace(/[:：]/g, '').trim();
              }
              if (!name) name = 'الخيار';

              const options = [];
              let value = '';

              floor.querySelectorAll('[class*="sku-ui--image"], [class*="sku-ui--text"]').forEach(el => {
                const img = el.querySelector('img');
                let label = '';
                if (img) {
                  label = (img.alt || img.getAttribute('title') || '').trim();
                } else {
                  label = el.textContent.trim();
                }
                if (!label) return;

                if (options.indexOf(label) === -1) options.push(label);

                const isSelected = el.className.includes('selected') || el.className.includes('dcss-sku-selected') || el.getAttribute('aria-selected') === 'true';
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
            const titleElem = document.querySelector("__TITLE_SELECTOR__");
            if (titleElem) title = titleElem.textContent.trim();
            if (!title && ld && ld.name) title = ld.name;
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
              // Helper: given a text string that may contain an Arabic/Latin price,
              // extract the numeric part. Handles RTL marks, NBSP, Arabic "ريال" etc.
              function pickAmazonNum(text) {
                if (!text) return '';
                const t = text.trim();
                // Match first digit sequence that looks like a price (e.g. 639.00, 1,234.56)
                const m = t.match(/\d[\d,]*\.?\d*/);
                if (!m) return '';
                const raw = m[0].replace(/,/g, ''); // strip thousands separator
                return raw;
              }

              let extracted = '';

              // Source A: apex-pricetopay-accessibility-label — clean readable text
              // e.g. "‏639.00 ريال مع توفير بنسبة 5" — we only take the number part
              const accLabel = document.querySelector('.apex-pricetopay-accessibility-label, [class*="pricetopay-accessibility"]');
              if (accLabel) {
                // Extract first number from the text, ignore anything after "مع" or "with"
                const raw = (accLabel.textContent || '').split(/مع|with/i)[0];
                extracted = pickAmazonNum(raw);
              }

              // Source B: .priceToPay span — the large price displayed on page
              if (!extracted) {
                const paySpan = document.querySelector('.priceToPay, .apex-pricetopay-value');
                if (paySpan) {
                  // Try offscreen first
                  const off = paySpan.querySelector('.a-offscreen');
                  if (off) extracted = pickAmazonNum(off.textContent);
                  // Fallback: manually combine whole + fraction digits
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
              }

              // Source C: #tp_price_block_total_price_ww — static bottom-sheet price
              if (!extracted) {
                const tpBlock = document.querySelector('#tp_price_block_total_price_ww, #tp-bottom-sheet-subtotal-price-value');
                if (tpBlock) {
                  const off = tpBlock.querySelector('.a-offscreen');
                  if (off) extracted = pickAmazonNum(off.textContent);
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

              // Source D: corePriceDisplay_mobile or _desktop
              if (!extracted) {
                const coreBlock = document.querySelector(
                  '#corePriceDisplay_mobile_feature_div, #corePriceDisplay_desktop_feature_div, #corePrice_feature_div'
                );
                if (coreBlock) {
                  // Prefer non-strike-through price
                  const priceEl = coreBlock.querySelector('.a-price:not([data-a-strike="true"])');
                  if (priceEl) {
                    const off = priceEl.querySelector('.a-offscreen');
                    if (off) extracted = pickAmazonNum(off.textContent);
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
                }
              }

              // Source E: failsafe — scan all .a-offscreen spans in the main content area
              // This catches live Amazon SA pages with different/dynamic price block IDs
              if (!extracted) {
                const contentArea = document.querySelector('#dp-container, #centerCol, #ppd, body');
                if (contentArea) {
                  const offscreens = contentArea.querySelectorAll('.a-offscreen');
                  for (const off of offscreens) {
                    const txt = (off.textContent || '').trim();
                    // Must contain SAR or Arabic ريال and have decimal digits
                    const hasCurrency = txt.includes('SAR') || txt.includes('ريال') || txt.includes('ر.س');
                    const num = txt.match(/\d[\d,]*\.\d+/);
                    if (hasCurrency && num) {
                      const candidate = num[0].replace(/,/g, '');
                      // Sanity check: ignore tiny numbers like 4, 5 (discount %)
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

            // ── Priority 1: OpenGraph product meta tags (reliable on m.shein.com) ──
            if (!isAliExpress && !isAlibaba) {
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

            // ── Priority 2: Shein JS globals ─────────────────────────────────
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

            // ── Priority 2.5: iHerb-specific price extraction ────────────────
            const isIherbHost = window.location.hostname.includes('iherb.') || window.location.href.includes('iherb');
            if (isIherbHost && !priceNum) {
              // iHerb uses emotion-css dynamic class names. We target by class-fragment.
              // StrikeThroughPrice = the sale / current price (red text)
              const iherbPriceEl = document.querySelector(
                '[class*="StrikeThroughPrice"], #price, [itemprop="price"]'
              );
              if (iherbPriceEl) {
                const raw = iherbPriceEl.getAttribute('content') || iherbPriceEl.textContent || '';
                const pVal = parsePriceString(raw);
                if (pVal) { priceNum = pVal; currency = 'SAR'; }
              }
              // Fallback: any element showing "X ر.س" format
              if (!priceNum) {
                const allText = document.querySelectorAll('span, bdi, p');
                for (const el of allText) {
                  const t = el.textContent.trim();
                  if (t.includes('ر.س') || t.includes('SAR')) {
                    const pVal = parsePriceString(t);
                    if (pVal && parseFloat(pVal) > 0) { priceNum = pVal; currency = 'SAR'; break; }
                  }
                }
              }
            }

            // ── Priority 3: DOM selectors ─────────────────────────────────────
            // Skip for Amazon — Priority 0.5 combiner already handled it
            if (!priceNum && !isAmazonHost) {
              for (const selector of priceSelectors) {
                const elem = document.querySelector(selector);
                if (elem) {
                  let text = "";
                  // aria-label on element itself first (Shein mobile uses this)
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
                  // Extract currency prefix or suffix (any letters or symbols like SAR, NGN, AED, etc.)
                  const currMatch = text.match(/(\b(SAR|AED|USD|NGN|EUR|GBP|EGP|QAR|BHD|OMR|KWD)\b|ر\.س|ريال سعودي|ريال|درهم)/);
                  if (currMatch) {
                    currency = currMatch[1].trim();
                  }

                  const pVal = parsePriceString(text);
                  if (pVal) { priceNum = pVal; break; }
                }
              }
            }

            // ── Priority 4: JSON-LD ───────────────────────────────────────────
            // Skip for Amazon — Priority 0.5 combiner already handled it
            if (!priceNum && !isAliExpress && !isAlibaba && !isAmazonHost && ld && ld.price) {
              const m = ('' + ld.price).match(/\d+(?:\.\d+)?/);
              if (m) priceNum = m[0];
            }

            // ── Priority 5: Last resort – any price-like element ──────────────
            // Skip for Amazon — Priority 0.5 combiner already handled it
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
            return Object.assign({
              title: title,
              price: price,
              image_url: imageUrl,
              url: window.location.href,
              site: "__SITE_NAME__",
            }, sku);
          } catch (e) { return null; }
        }
        window.__koonExtractProduct = extractProduct;
        window.__koonOpenSkuPicker = function() {
          const action = document.querySelector('[data-testid="sku-action"]');
          if (action) { action.click(); return true; }
          const layout = document.querySelector('[data-module-name="module_sku"] [data-testid="sku-layout"], [data-testid="sku-summary"]');
          if (layout) { layout.click(); return true; }
          const panel = document.querySelector('[data-testid="sku-panel-sku"]');
          if (panel) { panel.scrollIntoView({ behavior: 'smooth', block: 'center' }); return true; }
          return false;
        };
        window.__koonSelectOption = function(name, value) {
          try {
            function simulateClick(el) {
              if (!el) return;
              const events = ['mousedown', 'mouseup', 'click'];
              for (const evName of events) {
                const e = new MouseEvent(evName, {
                  bubbles: true,
                  cancelable: true,
                  view: window
                });
                el.dispatchEvent(e);
              }
            }

            const floors = document.querySelectorAll('[class*="sku--container"] [class*="sku-ui--property"]');
            for (const floor of floors) {
              const titleEl = floor.querySelector('[class*="sku-ui--title"]');
              let floorName = '';
              if (titleEl) {
                let text = titleEl.textContent || '';
                const valEl = titleEl.querySelector('[class*="sku-ui--skuValue"]');
                if (valEl) {
                  const valText = valEl.textContent || '';
                  text = text.replace(valText, '');
                }
                floorName = text.replace(/[:：]/g, '').trim();
              }
              if (!floorName) floorName = 'الخيار';

              if (floorName.toLowerCase() === name.toLowerCase()) {
                const items = floor.querySelectorAll('[class*="sku-ui--skus"] > div, [data-sku-col], [class*="sku-ui--image"], [class*="sku-ui--text"]');
                for (const item of items) {
                  const img = item.querySelector('img');
                  let label = '';
                  if (img) {
                    label = (img.alt || img.getAttribute('title') || '').trim();
                  } else {
                    label = item.textContent.trim();
                  }
                  if (label === value) {
                    const isSelected = item.className.includes('selected') || item.className.includes('dcss-sku-selected') || item.getAttribute('aria-selected') === 'true';
                    if (!isSelected) {
                      simulateClick(item);
                      const inner = item.querySelector('img, span, p');
                      if (inner) simulateClick(inner);
                      return true;
                    }
                  }
                }
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
              if (floorName.toLowerCase() === name.toLowerCase()) {
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
                  if (label && label.toLowerCase() === value.toLowerCase()) {
                    const isSelected = swatch.querySelector('.a-button-selected, .a-button-active');
                    if (!isSelected) {
                      const btn = swatch.querySelector('.a-button, input');
                      simulateClick(btn || swatch);
                      return true;
                    }
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
        if (!window._scraperIntervalId) {
          window._scraperIntervalId = setInterval(() => {
            const product = extractProduct();
            window.flutter_inappwebview.callHandler('onProductDetected', product);
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
