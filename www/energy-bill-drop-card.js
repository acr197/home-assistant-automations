// energy-bill-drop-card.js — Version 1.0.0
// Custom Home Assistant Lovelace card: drag-and-drop zone for energy bill files

// pdf.js CDN — loaded lazily the first time a PDF is dropped
const PDFJS_SRC = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
const PDFJS_WORKER = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

// MIME types accepted by the drop zone
const ACCEPTED = new Set(['image/jpeg', 'image/png', 'image/webp', 'application/pdf']);

// ── Card element ──────────────────────────────────────────────────────────────
class EnergyBillDropCard extends HTMLElement {

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });

    // State machine: idle | file-hover | loading | preview | error
    this._state = 'idle';
    this._errorMessage = '';
    this._previewHTML = '';
    this._fileName = '';
    this._fileSize = 0;
    this._pdfJsReady = false;

    // Public property — set once a file is loaded; external callers read this
    this.fileData = null;
  }

  // ── HA lifecycle hooks ────────────────────────────────────────────────────

  setConfig(config) {
    this._config = config || {};
    this._render();
  }

  // Hint to HA about how many dashboard rows this card occupies
  getCardSize() { return 4; }

  // ── Rendering ─────────────────────────────────────────────────────────────

  _render() {
    const title = this._config.title || 'Energy Bill';
    this.shadowRoot.innerHTML = `<style>${this._css()}</style>${this._html(title)}`;
    this._bind();
  }

  // All card styles — dark HA aesthetic, no external framework
  _css() {
    return `
      :host { display: block; }

      .card {
        background: var(--ha-card-background, #1c1c1e);
        border-radius: var(--ha-card-border-radius, 12px);
        border: 1px solid var(--divider-color, rgba(255,255,255,0.12));
        box-shadow: var(--ha-card-box-shadow, 0 2px 8px rgba(0,0,0,0.45));
        padding: 16px;
        font-family: var(--primary-font-family, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif);
        color: var(--primary-text-color, #e1e1e1);
        box-sizing: border-box;
      }

      .card-title {
        font-size: 1rem;
        font-weight: 500;
        margin-bottom: 14px;
        display: flex;
        align-items: center;
        gap: 8px;
        color: var(--primary-text-color, #e1e1e1);
      }

      .title-icon { color: var(--accent-color, #03a9f4); }

      .drop-zone {
        border: 2px dashed var(--divider-color, rgba(255,255,255,0.18));
        border-radius: 8px;
        background: var(--secondary-background-color, rgba(255,255,255,0.03));
        padding: 36px 20px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 10px;
        text-align: center;
        cursor: pointer;
        transition: border-color 0.2s ease, background 0.2s ease;
        min-height: 150px;
      }

      .drop-zone.file-hover {
        border-color: var(--accent-color, #03a9f4);
        background: rgba(3, 169, 244, 0.09);
      }

      .drop-zone.preview {
        border-style: solid;
        border-color: var(--divider-color, rgba(255,255,255,0.12));
        padding: 14px;
        min-height: unset;
        cursor: default;
      }

      .drop-zone.loading {
        cursor: wait;
      }

      .drop-zone.error {
        border-color: var(--error-color, #f44336);
        background: rgba(244, 67, 54, 0.06);
      }

      .icon-xl { font-size: 2.6rem; line-height: 1; user-select: none; }

      .text-primary { font-size: 0.95rem; font-weight: 500; color: var(--primary-text-color, #e1e1e1); }
      .text-muted   { font-size: 0.78rem; color: var(--secondary-text-color, #9e9e9e); }
      .text-error   { font-size: 0.88rem; font-weight: 500; color: var(--error-color, #f44336); }

      .preview-img {
        max-width: 100%;
        max-height: 260px;
        border-radius: 6px;
        object-fit: contain;
        display: block;
      }

      .file-meta {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 3px;
        margin-top: 6px;
      }

      .file-name {
        font-size: 0.84rem;
        font-weight: 500;
        word-break: break-all;
        color: var(--primary-text-color, #e1e1e1);
      }

      .file-size { font-size: 0.75rem; color: var(--secondary-text-color, #9e9e9e); }

      .btn-clear {
        margin-top: 10px;
        padding: 5px 18px;
        background: transparent;
        border: 1px solid var(--divider-color, rgba(255,255,255,0.2));
        border-radius: 6px;
        color: var(--secondary-text-color, #9e9e9e);
        font-size: 0.8rem;
        font-family: inherit;
        cursor: pointer;
        transition: border-color 0.15s, color 0.15s;
      }
      .btn-clear:hover { border-color: var(--error-color, #f44336); color: var(--error-color, #f44336); }

      .loading-label {
        font-size: 0.88rem;
        color: var(--secondary-text-color, #9e9e9e);
        animation: blink 1.4s ease-in-out infinite;
      }
      @keyframes blink { 0%,100%{opacity:1} 50%{opacity:0.3} }

      .sr-only { display: none; }
    `;
  }

  // Full card HTML shell — drop zone inner content varies by state
  _html(title) {
    return `
      <div class="card" role="region" aria-label="${this._esc(title)}">
        <div class="card-title">
          <span class="title-icon" aria-hidden="true">⚡</span>
          <span>${this._esc(title)}</span>
        </div>
        <div class="drop-zone ${this._state}" id="zone"
             role="button" tabindex="0"
             aria-label="Drop zone for energy bill files">
          ${this._zoneInner()}
        </div>
        <input type="file" id="file-input" class="sr-only"
               accept="image/jpeg,image/png,image/webp,application/pdf"
               aria-hidden="true" />
      </div>
    `;
  }

  // State-specific markup rendered inside the drop zone
  _zoneInner() {
    switch (this._state) {

      case 'idle':
        return `
          <div class="icon-xl" aria-hidden="true">📄</div>
          <div class="text-primary">Drop your energy bill here</div>
          <div class="text-muted">or click to browse</div>
          <div class="text-muted">JPG &middot; PNG &middot; WEBP &middot; PDF</div>
        `;

      case 'file-hover':
        return `
          <div class="icon-xl" aria-hidden="true">📥</div>
          <div class="text-primary">Release to load file</div>
        `;

      case 'loading':
        return `<div class="loading-label" role="status">Rendering preview…</div>`;

      case 'preview':
        return `
          ${this._previewHTML}
          <div class="file-meta">
            <div class="file-name">${this._esc(this._fileName)}</div>
            <div class="file-size">${this._fmtSize(this._fileSize)}</div>
          </div>
          <button class="btn-clear" id="btn-clear">Remove file</button>
        `;

      case 'error':
        return `
          <div class="icon-xl" aria-hidden="true">⚠️</div>
          <div class="text-error" role="alert">${this._esc(this._errorMessage)}</div>
          <div class="text-muted">Click to try again</div>
        `;

      default:
        return '';
    }
  }

  // ── Event binding ─────────────────────────────────────────────────────────

  _bind() {
    const zone = this.shadowRoot.getElementById('zone');
    const input = this.shadowRoot.getElementById('file-input');
    const clearBtn = this.shadowRoot.getElementById('btn-clear');

    // Show hover highlight when something is dragged into the zone
    zone.addEventListener('dragenter', (e) => {
      e.preventDefault();
      if (this._state !== 'preview' && this._state !== 'loading') {
        this._setState('file-hover');
      }
    });

    // Prevent default so the browser permits the drop event to fire
    zone.addEventListener('dragover', (e) => e.preventDefault());

    // Return to idle when the drag leaves the zone without dropping
    zone.addEventListener('dragleave', (e) => {
      if (!zone.contains(e.relatedTarget) && this._state === 'file-hover') {
        this._setState('idle');
      }
    });

    // User dropped a file onto the zone
    zone.addEventListener('drop', (e) => {
      e.preventDefault();
      const file = e.dataTransfer?.files?.[0];
      if (file) this._handleFile(file);
    });

    // Click anywhere in the zone opens the file picker (blocked during preview/loading)
    zone.addEventListener('click', (e) => {
      if (e.target.id === 'btn-clear') return;
      if (this._state === 'preview' || this._state === 'loading') return;
      input.click();
    });

    // Keyboard accessibility — treat Enter/Space as a click on the zone
    zone.addEventListener('keydown', (e) => {
      if ((e.key === 'Enter' || e.key === ' ') && this._state !== 'preview' && this._state !== 'loading') {
        e.preventDefault();
        input.click();
      }
    });

    // File chosen from the native picker dialog
    if (input) {
      input.addEventListener('change', (e) => {
        const file = e.target.files?.[0];
        if (file) this._handleFile(file);
        // Reset so the same file can be picked again after a clear
        input.value = '';
      });
    }

    // Clear button — remove the current file and return to idle
    if (clearBtn) {
      clearBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this._reset();
      });
    }
  }

  // ── File processing ───────────────────────────────────────────────────────

  async _handleFile(file) {
    // Reject anything that isn't in the accepted set
    if (!ACCEPTED.has(file.type)) {
      this._errorMessage = `Unsupported file type: "${file.type || 'unknown'}". Use JPG, PNG, WEBP, or PDF.`;
      this._setState('error');
      return;
    }

    this._fileName = file.name;
    this._fileSize = file.size;

    // Encode the raw bytes as base64 for later API calls
    let b64;
    try {
      b64 = await this._toBase64(file);
    } catch {
      this._errorMessage = 'Could not read the selected file.';
      this._setState('error');
      return;
    }

    // Expose the data on the element so external scripts can consume it
    this.fileData = { name: file.name, size: file.size, type: file.type, base64: b64 };

    if (file.type === 'application/pdf') {
      // Switch to loading while pdf.js renders the first page
      this._setState('loading');
      try {
        this._previewHTML = await this._pdfThumb(b64);
      } catch (err) {
        this._errorMessage = `PDF render failed: ${err.message}`;
        this._setState('error');
        return;
      }
    } else {
      // Images: compose a data URL directly — no extra processing needed
      this._previewHTML = `<img class="preview-img" src="data:${file.type};base64,${b64}" alt="Bill preview" />`;
    }

    this._setState('preview');
  }

  // ── PDF thumbnail via pdf.js ──────────────────────────────────────────────

  async _pdfThumb(b64) {
    // Ensure pdf.js is loaded before we try to use it
    await this._ensurePdfJs();

    // Decode base64 to binary for pdf.js — it requires a Uint8Array
    const raw = atob(b64);
    const bytes = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);

    // Parse the PDF and grab page 1
    const pdf = await window.pdfjsLib.getDocument({ data: bytes }).promise;
    const page = await pdf.getPage(1);
    const viewport = page.getViewport({ scale: 1.4 });

    // Render page 1 onto an off-screen canvas, then export as a PNG data URL
    const canvas = document.createElement('canvas');
    canvas.width = viewport.width;
    canvas.height = viewport.height;
    await page.render({ canvasContext: canvas.getContext('2d'), viewport }).promise;

    // Return an <img> so it's handled the same way as an image preview
    const dataUrl = canvas.toDataURL('image/png');
    return `<img class="preview-img" src="${dataUrl}" alt="PDF page 1 preview" />`;
  }

  // Load pdf.js from CDN once and configure its worker URL
  _ensurePdfJs() {
    if (this._pdfJsReady) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = PDFJS_SRC;
      script.onload = () => {
        window.pdfjsLib.GlobalWorkerOptions.workerSrc = PDFJS_WORKER;
        this._pdfJsReady = true;
        resolve();
      };
      script.onerror = () => reject(new Error('Could not load pdf.js from CDN'));
      document.head.appendChild(script);
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // Wrap FileReader in a Promise; resolves with the base64 payload (no data-URL prefix)
  _toBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result.split(',')[1]);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  _setState(state) {
    this._state = state;
    this._render();
  }

  // Clear all file state and return to idle
  _reset() {
    this.fileData = null;
    this._previewHTML = '';
    this._errorMessage = '';
    this._fileName = '';
    this._fileSize = 0;
    this._setState('idle');
  }

  // Convert raw byte count to a human-readable string
  _fmtSize(bytes) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  }

  // Escape HTML special characters before inserting user-controlled text into markup
  _esc(str) {
    return String(str ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
}

// Register the element so Lovelace can use type: energy-bill-drop-card
customElements.define('energy-bill-drop-card', EnergyBillDropCard);

// Announce this card to HA's custom card registry so it shows in the card picker
window.customCards = window.customCards || [];
window.customCards.push({
  type: 'energy-bill-drop-card',
  name: 'Energy Bill Drop Card',
  description: 'Drag-and-drop zone for uploading energy bill images and PDFs',
});
