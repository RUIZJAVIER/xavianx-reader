/* global pdfjsLib */

// https://github.com/mozilla/pdf.js/blob/f04967017f22e46d70d11468dd928b4cdc2f6ea1/web/text_layer_builder.css
const textLayerBuilderCSS = `
/* Copyright 2014 Mozilla Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

:root {
  --highlight-bg-color: rgb(180 0 170);
  --highlight-selected-bg-color: rgb(0 100 0);
}

@media screen and (forced-colors: active) {
  :root {
    --highlight-bg-color: Highlight;
    --highlight-selected-bg-color: ButtonText;
  }
}

.textLayer {
  position: absolute;
  text-align: initial;
  inset: 0;
  overflow: hidden;
  opacity: 0.25;
  line-height: 1;
  text-size-adjust: none;
  forced-color-adjust: none;
  transform-origin: 0 0;
  z-index: 2;
}

.textLayer :is(span, br) {
  color: transparent;
  position: absolute;
  white-space: pre;
  cursor: text;
  transform-origin: 0% 0%;
}

/* Only necessary in Google Chrome, see issue 14205, and most unfortunately
 * the problem doesn't show up in "text" reference tests. */
/*#if !MOZCENTRAL*/
.textLayer span.markedContent {
  top: 0;
  height: 0;
}
/*#endif*/

.textLayer .highlight {
  margin: -1px;
  padding: 1px;
  background-color: var(--highlight-bg-color);
  border-radius: 4px;
}

.textLayer .highlight.appended {
  position: initial;
}

.textLayer .highlight.begin {
  border-radius: 4px 0 0 4px;
}

.textLayer .highlight.end {
  border-radius: 0 4px 4px 0;
}

.textLayer .highlight.middle {
  border-radius: 0;
}

.textLayer .highlight.selected {
  background-color: var(--highlight-selected-bg-color);
}

.textLayer ::selection {
  /*#if !MOZCENTRAL*/
  background: blue;
  /*#endif*/
  background: AccentColor; /* stylelint-disable-line declaration-block-no-duplicate-properties */
}

/* Avoids https://github.com/mozilla/pdf.js/issues/13840 in Chrome */
/*#if !MOZCENTRAL*/
.textLayer br::selection {
  background: transparent;
}
/*#endif*/

.textLayer .endOfContent {
  display: block;
  position: absolute;
  inset: 100% 0 0;
  z-index: -1;
  cursor: default;
  user-select: none;
}

.textLayer .endOfContent.active {
  top: 0;
}
`

//https://github.com/mozilla/pdf.js/blob/d64f223d034ad74fb62571c3acff566d25eca413/web/annotation_layer_builder.css
const annotationLayerBuilderCSS = `
/* Copyright 2014 Mozilla Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

:root {
  --annotation-unfocused-field-background: url("data:image/svg+xml;charset=UTF-8,<svg width='1px' height='1px' xmlns='http://www.w3.org/2000/svg'><rect width='100%' height='100%' style='fill:rgba(0, 54, 255, 0.13);'/></svg>");
  --input-focus-border-color: Highlight;
  --input-focus-outline: 1px solid Canvas;
  --input-unfocused-border-color: transparent;
  --input-disabled-border-color: transparent;
  --input-hover-border-color: black;
  --link-outline: none;
}

@media screen and (forced-colors: active) {
  :root {
    --input-focus-border-color: CanvasText;
    --input-unfocused-border-color: ActiveText;
    --input-disabled-border-color: GrayText;
    --input-hover-border-color: Highlight;
    --link-outline: 1.5px solid LinkText;
    --hcm-highligh-filter: invert(100%);
  }
  .annotationLayer .textWidgetAnnotation :is(input, textarea):required,
  .annotationLayer .choiceWidgetAnnotation select:required,
  .annotationLayer
    .buttonWidgetAnnotation:is(.checkBox, .radioButton)
    input:required {
    outline: 1.5px solid selectedItem;
  }

  .annotationLayer .linkAnnotation:hover {
    backdrop-filter: var(--hcm-highligh-filter);
  }

  .annotationLayer .linkAnnotation > a:hover {
    opacity: 0 !important;
    background: none !important;
    box-shadow: none;
  }

  .annotationLayer .popupAnnotation .popup {
    outline: calc(1.5px * var(--scale-factor)) solid CanvasText !important;
    background-color: ButtonFace !important;
    color: ButtonText !important;
  }

  .annotationLayer .highlightArea:hover::after {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    backdrop-filter: var(--hcm-highligh-filter);
    content: "";
    pointer-events: none;
  }

  .annotationLayer .popupAnnotation.focused .popup {
    outline: calc(3px * var(--scale-factor)) solid Highlight !important;
  }
}

.annotationLayer {
  position: absolute;
  top: 0;
  left: 0;
  pointer-events: none;
  transform-origin: 0 0;
  z-index: 3;
}

.annotationLayer[data-main-rotation="90"] .norotate {
  transform: rotate(270deg) translateX(-100%);
}
.annotationLayer[data-main-rotation="180"] .norotate {
  transform: rotate(180deg) translate(-100%, -100%);
}
.annotationLayer[data-main-rotation="270"] .norotate {
  transform: rotate(90deg) translateY(-100%);
}

.annotationLayer canvas {
  position: absolute;
  width: 100%;
  height: 100%;
  pointer-events: none;
}

.annotationLayer section {
  position: absolute;
  text-align: initial;
  pointer-events: auto;
  box-sizing: border-box;
  transform-origin: 0 0;
}

.annotationLayer .linkAnnotation {
  outline: var(--link-outline);
}

.annotationLayer :is(.linkAnnotation, .buttonWidgetAnnotation.pushButton) > a {
  position: absolute;
  font-size: 1em;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.annotationLayer
  :is(.linkAnnotation, .buttonWidgetAnnotation.pushButton):not(.hasBorder)
  > a:hover {
  opacity: 0.2;
  background-color: rgb(255 255 0);
  box-shadow: 0 2px 10px rgb(255 255 0);
}

.annotationLayer .linkAnnotation.hasBorder:hover {
  background-color: rgb(255 255 0 / 0.2);
}

.annotationLayer .hasBorder {
  background-size: 100% 100%;
}

.annotationLayer .textAnnotation img {
  position: absolute;
  cursor: pointer;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea),
.annotationLayer .choiceWidgetAnnotation select,
.annotationLayer .buttonWidgetAnnotation:is(.checkBox, .radioButton) input {
  background-image: var(--annotation-unfocused-field-background);
  border: 2px solid var(--input-unfocused-border-color);
  box-sizing: border-box;
  font: calc(9px * var(--scale-factor)) sans-serif;
  height: 100%;
  margin: 0;
  vertical-align: top;
  width: 100%;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea):required,
.annotationLayer .choiceWidgetAnnotation select:required,
.annotationLayer
  .buttonWidgetAnnotation:is(.checkBox, .radioButton)
  input:required {
  outline: 1.5px solid red;
}

.annotationLayer .choiceWidgetAnnotation select option {
  padding: 0;
}

.annotationLayer .buttonWidgetAnnotation.radioButton input {
  border-radius: 50%;
}

.annotationLayer .textWidgetAnnotation textarea {
  resize: none;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea)[disabled],
.annotationLayer .choiceWidgetAnnotation select[disabled],
.annotationLayer
  .buttonWidgetAnnotation:is(.checkBox, .radioButton)
  input[disabled] {
  background: none;
  border: 2px solid var(--input-disabled-border-color);
  cursor: not-allowed;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea):hover,
.annotationLayer .choiceWidgetAnnotation select:hover,
.annotationLayer
  .buttonWidgetAnnotation:is(.checkBox, .radioButton)
  input:hover {
  border: 2px solid var(--input-hover-border-color);
}
.annotationLayer .textWidgetAnnotation :is(input, textarea):hover,
.annotationLayer .choiceWidgetAnnotation select:hover,
.annotationLayer .buttonWidgetAnnotation.checkBox input:hover {
  border-radius: 2px;
}

.annotationLayer .textWidgetAnnotation :is(input, textarea):focus,
.annotationLayer .choiceWidgetAnnotation select:focus {
  background: none;
  border: 2px solid var(--input-focus-border-color);
  border-radius: 2px;
  outline: var(--input-focus-outline);
}

.annotationLayer .buttonWidgetAnnotation:is(.checkBox, .radioButton) :focus {
  background-image: none;
  background-color: transparent;
}

.annotationLayer .buttonWidgetAnnotation.checkBox :focus {
  border: 2px solid var(--input-focus-border-color);
  border-radius: 2px;
  outline: var(--input-focus-outline);
}

.annotationLayer .buttonWidgetAnnotation.radioButton :focus {
  border: 2px solid var(--input-focus-border-color);
  outline: var(--input-focus-outline);
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::before,
.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::after,
.annotationLayer .buttonWidgetAnnotation.radioButton input:checked::before {
  background-color: CanvasText;
  content: "";
  display: block;
  position: absolute;
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::before,
.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::after {
  height: 80%;
  left: 45%;
  width: 1px;
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::before {
  transform: rotate(45deg);
}

.annotationLayer .buttonWidgetAnnotation.checkBox input:checked::after {
  transform: rotate(-45deg);
}

.annotationLayer .buttonWidgetAnnotation.radioButton input:checked::before {
  border-radius: 50%;
  height: 50%;
  left: 30%;
  top: 20%;
  width: 50%;
}

.annotationLayer .textWidgetAnnotation input.comb {
  font-family: monospace;
  padding-left: 2px;
  padding-right: 0;
}

.annotationLayer .textWidgetAnnotation input.comb:focus {
  /*
   * Letter spacing is placed on the right side of each character. Hence, the
   * letter spacing of the last character may be placed outside the visible
   * area, causing horizontal scrolling. We avoid this by extending the width
   * when the element has focus and revert this when it loses focus.
   */
  width: 103%;
}

.annotationLayer .buttonWidgetAnnotation:is(.checkBox, .radioButton) input {
  appearance: none;
}

.annotationLayer .fileAttachmentAnnotation .popupTriggerArea {
  height: 100%;
  width: 100%;
}

.annotationLayer .popupAnnotation {
  position: absolute;
  font-size: calc(9px * var(--scale-factor));
  pointer-events: none;
  width: max-content;
  max-width: 45%;
  height: auto;
}

.annotationLayer .popup {
  background-color: rgb(255 255 153);
  box-shadow: 0 calc(2px * var(--scale-factor)) calc(5px * var(--scale-factor))
    rgb(136 136 136);
  border-radius: calc(2px * var(--scale-factor));
  outline: 1.5px solid rgb(255 255 74);
  padding: calc(6px * var(--scale-factor));
  cursor: pointer;
  font: message-box;
  white-space: normal;
  word-wrap: break-word;
  pointer-events: auto;
}

.annotationLayer .popupAnnotation.focused .popup {
  outline-width: 3px;
}

.annotationLayer .popup * {
  font-size: calc(9px * var(--scale-factor));
}

.annotationLayer .popup > .header {
  display: inline-block;
}

.annotationLayer .popup > .header h1 {
  display: inline;
}

.annotationLayer .popup > .header .popupDate {
  display: inline-block;
  margin-left: calc(5px * var(--scale-factor));
  width: fit-content;
}

.annotationLayer .popupContent {
  border-top: 1px solid rgb(51 51 51);
  margin-top: calc(2px * var(--scale-factor));
  padding-top: calc(2px * var(--scale-factor));
}

.annotationLayer .richText > * {
  white-space: pre-wrap;
  font-size: calc(9px * var(--scale-factor));
}

.annotationLayer .popupTriggerArea {
  cursor: pointer;
}

.annotationLayer section svg {
  position: absolute;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
}

.annotationLayer .annotationTextContent {
  position: absolute;
  width: 100%;
  height: 100%;
  opacity: 0;
  color: transparent;
  user-select: none;
  pointer-events: none;
}

.annotationLayer .annotationTextContent span {
  width: 100%;
  display: inline-block;
}

.annotationLayer svg.quadrilateralsContainer {
  contain: strict;
  width: 0;
  height: 0;
  position: absolute;
  top: 0;
  left: 0;
  z-index: -1;
}
`

// PDF pages are never rasterized to PNG/DataURL for the reader. They are
// painted onto a <canvas> by PDF.js, with a vector text layer on top, and
// re-rendered at the current zoom/device density when a gesture ends.
//
// Super high densities would need huge backing stores (a 3.5x zoom on a 3x
// screen is already ~10x the page size), which would kill the WebView. These
// caps keep the longest side at 5120px / 18MP, enough for a fully sharp 3.5x
// zoom on a typical page, without risking an out-of-memory crash.
const MAX_CANVAS_DIMENSION = 5120
const MAX_CANVAS_PIXELS = 18 * 1024 * 1024
// Beyond this the page is already several times the screen size; rendering the
// whole canvas at that density only costs memory.
const MAX_RENDER_ZOOM = 3.5
// El tamaño de fuente por defecto (BookStyle.fontSize) es 1.4: el deslizador
// actúa como multiplicador de escala a partir de ese valor.
const PDF_DEFAULT_FONT_SIZE = 1.4
// Cuánto se puede ampliar la página al recortar los márgenes de imprenta.
const MAX_CROP_SCALE = 1.45
const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

// Marca en la ventana principal que hay una página ampliada. El visor usa
// esta bandera para bloquear el gesto de cambio de página por swipe.
const setPdfZoomed = zoomed => {
    try {
        window.__anxPdfZoomed = !!zoomed
        if (window.flutter_inappwebview?.callHandler) {
            window.flutter_inappwebview.callHandler('onPdfZoom', { zoomed: !!zoomed })
        }
    } catch (_) {}
}

// Estado global del visor PDF:
//  - zoom: multiplicador de escala (deslizador de tamaño de fuente)
//  - filter: filtro CSS de lectura nocturna/sepia
const pdfState = {
    zoom: 1,
    filter: 'none',
}

// Páginas PDF montadas, para poder aplicarles los cambios de estilo.
const pdfPageControllers = new Set()

// Subrayados/notas de PDF guardados por la app, agrupados por página (1-based).
// Cada entrada: { id, start, end, color, type, note }, donde `start`/`end` son
// desplazamientos de caracteres sobre los nodos de texto de la capa de texto.
const pdfHighlightStore = new Map()

// Última página PDF avisada a Flutter (global, no por página): al volver a una
// hoja ya visitada también hay que refrescar el encabezado y el pie.
let lastReportedPdfPage = 0

/// Reemplaza los subrayados conocidos y repinta las páginas ya montadas.
///
/// Se llama desde Flutter cada vez que se crea, edita o borra una nota.
export const applyPdfHighlights = list => {
    pdfHighlightStore.clear()
    for (const raw of list ?? []) {
        const page = Number(raw?.page)
        const start = Number(raw?.start)
        const end = Number(raw?.end)
        if (!Number.isFinite(page) || page < 1) continue
        if (!Number.isFinite(start) || !Number.isFinite(end)) continue
        if (end <= start) continue
        const bucket = pdfHighlightStore.get(page) || []
        bucket.push({
            id: raw?.id ?? null,
            start,
            end,
            color: String(raw?.color || 'FFEB3B'),
            type: String(raw?.type || 'highlight'),
            note: String(raw?.note || ''),
        })
        pdfHighlightStore.set(page, bucket)
    }
    for (const controller of pdfPageControllers) {
        try { controller.paintHighlights() } catch (_) {}
    }
}

// Calcula el filtro de lectura a partir del color de fondo del tema.
// El filtro se aplica por CSS, así que los píxeles del canvas (y por tanto la
// captura que se envía a la IA) siguen siendo los originales.
const computeReadingFilter = backgroundColor => {
    const match = /^#?([0-9a-f]{6})/i.exec(String(backgroundColor || '').trim())
    if (!match) return 'none'
    const hex = match[1]
    const r = parseInt(hex.slice(0, 2), 16)
    const g = parseInt(hex.slice(2, 4), 16)
    const b = parseInt(hex.slice(4, 6), 16)
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    if (luminance < 0.25) {
        // Modo nocturno: invierte la página manteniendo el tono de la tinta.
        return 'invert(0.92) hue-rotate(180deg) brightness(0.92) contrast(0.95)'
    }
    if (r > g && g > b && r - b > 12) {
        // Modo sepia.
        return 'sepia(0.35) contrast(0.96) saturate(0.9)'
    }
    return 'none'
}

// Every mounted PDF page registers its canvas here so the AI screenshot can
// grab the real pixels of the visible page without going through the native
// WebView surface (which `RepaintBoundary.toImage()` cannot capture).
const pdfPageRegistry = new Set()

const captureVisiblePdfPage = () => {
    const viewport = globalThis.visualViewport
    const viewLeft = viewport ? viewport.offsetLeft : 0
    const viewTop = viewport ? viewport.offsetTop : 0
    const viewRight = viewLeft + (viewport ? viewport.width : window.innerWidth)
    const viewBottom = viewTop + (viewport ? viewport.height : window.innerHeight)

    let best = null
    for (const entry of pdfPageRegistry) {
        const { canvas, iframe } = entry
        if (!canvas?.width || !iframe?.isConnected) continue
        let rect
        try { rect = iframe.getBoundingClientRect() } catch (_) { continue }
        const left = Math.max(rect.left, viewLeft)
        const top = Math.max(rect.top, viewTop)
        const right = Math.min(rect.right, viewRight)
        const bottom = Math.min(rect.bottom, viewBottom)
        const area = Math.max(0, right - left) * Math.max(0, bottom - top)
        if (area > 0 && (!best || area > best.area))
            best = { canvas, rect, left, top, right, bottom, area }
    }
    if (!best) return ''

    const { canvas, rect } = best
    const scaleX = canvas.width / Math.max(rect.width, 1)
    const scaleY = canvas.height / Math.max(rect.height, 1)

    // Crop the part of the page that is actually on screen.
    const sx = clamp((best.left - rect.left) * scaleX, 0, canvas.width - 1)
    const sy = clamp((best.top - rect.top) * scaleY, 0, canvas.height - 1)
    const sw = clamp((best.right - best.left) * scaleX, 1, canvas.width - sx)
    const sh = clamp((best.bottom - best.top) * scaleY, 1, canvas.height - sy)

    // Keep the transfer small; the Flutter side re-compresses for the AI anyway.
    const ratio = Math.min(1, 2000 / Math.max(sw, sh))
    const width = Math.max(1, Math.round(sw * ratio))
    const height = Math.max(1, Math.round(sh * ratio))

    const output = document.createElement('canvas')
    output.width = width
    output.height = height
    const outputContext = output.getContext('2d', { alpha: false })
    outputContext.fillStyle = '#FFFFFF'
    outputContext.fillRect(0, 0, width, height)
    outputContext.imageSmoothingEnabled = true
    outputContext.imageSmoothingQuality = 'high'
    outputContext.drawImage(canvas, sx, sy, sw, sh, 0, 0, width, height)
    return output.toDataURL('image/jpeg', 0.92)
}

if (typeof window !== 'undefined') {
    globalThis.anxCaptureVisiblePage = globalThis.anxCaptureVisiblePage
        || captureVisiblePdfPage
}

// Optional PDF.js font assets (cMaps + standard fonts). They are wired only
// when the files are actually shipped, so a build without them never fires
// failed requests on every page; PDF.js then falls back to system fonts.
let fontAssetOptionsPromise = null
const getFontAssetOptions = () => {
    if (!fontAssetOptionsPromise) {
        fontAssetOptionsPromise = (async () => {
            try {
                const base = new URL('vendor/pdfjs/', import.meta.url)
                const probe = await fetch(
                    new URL('standard_fonts/LiberationSans-Regular.ttf', base),
                    { method: 'HEAD' })
                if (!probe.ok) return {}
                return {
                    cMapUrl: new URL('cmaps/', base).href,
                    cMapPacked: true,
                    standardFontDataUrl: new URL('standard_fonts/', base).href,
                }
            } catch (_) {
                return {}
            }
        })()
    }
    return fontAssetOptionsPromise
}

// Browser pinch-zoom (the WebView's native zoom used in paginated mode) scales
// the whole document without changing any page's CSS layout. That means the
// canvas itself is magnified too. Listen for the settled visual viewport scale
// and ask every mounted PDF page to re-render at that density, so releasing the
// fingers always lands on a sharp page.
const registerVisualZoom = refresh => {
    let state = globalThis.__anxPdfVisualZoom
    if (!state) {
        state = { listeners: new Set(), scale: 1, timer: 0, installed: false }
        globalThis.__anxPdfVisualZoom = state
    }
    const listener = () => refresh(state.scale)
    state.listeners.add(listener)

    if (!state.installed && typeof window !== 'undefined') {
        state.installed = true
        const onViewportChange = () => {
            const viewport = window.visualViewport
            const scale = viewport?.scale || 1
            if (Math.abs(scale - state.scale) < 0.01) return
            state.scale = scale
            if (state.timer) clearTimeout(state.timer)
            // Re-render after the pinch settles, exactly like a native viewer.
            state.timer = setTimeout(() => {
                state.timer = 0
                for (const notify of state.listeners) {
                    try { notify() } catch (_) {}
                }
            }, 120)
        }
        if (window.visualViewport) {
            window.visualViewport.addEventListener('resize', onViewportChange)
            window.visualViewport.addEventListener('scroll', onViewportChange)
        }
        window.addEventListener('resize', onViewportChange)
    }

    return () => state.listeners.delete(listener)
}

// Renders one PDF page into the canvas of its already-loaded iframe document
// and wires lazy, high-density re-rendering for that page.
const attachCanvasPage = ({ doc, index, getPage, prefetch, totalPages }) => {
    const canvas = doc.querySelector('canvas.pdf-page-canvas')
    if (!canvas) return

    const textLayer = doc.querySelector('.textLayer')
    const annotationLayer = doc.querySelector('.annotationLayer')
    const highlightLayer = doc.querySelector('.pdf-highlight-layer')

    let cssScale = 1
    let fitScale = 1
    let visualScale = 1
    let renderedScale = 0
    let timer = 0
    let generation = 0
    let task = null
    let destroyed = false

    // Geometría de la página (en unidades PDF) y estado visual.
    let pageWidth = 0
    let pageHeight = 0
    // Margenes de imprenta detectados: { left, top, right, bottom } en fracción.
    let contentBox = null
    let cropScale = 1
    let tapZoom = 1
    let tapOffsetX = 0
    let tapOffsetY = 0

    const schedule = delay => {
        if (destroyed) return
        if (timer) clearTimeout(timer)
        timer = setTimeout(() => {
            timer = 0
            render()
        }, delay)
    }

    const iframe = doc.defaultView?.frameElement
    const registryEntry = { doc, canvas, iframe }
    pdfPageRegistry.add(registryEntry)

    // Escala total aplicada sobre la página: recorte + tamaño de fuente +
    // zoom por doble toque.
    const displayScale = () => cropScale * pdfState.zoom * tapZoom

    // Desplazamiento que centra el contenido y mantiene fijo el punto del
    // doble toque.
    const transformFor = () => {
        const s = displayScale()
        const x0 = contentBox ? contentBox.left * pageWidth : 0
        const y0 = contentBox ? contentBox.top * pageHeight : 0
        const x1 = contentBox ? contentBox.right * pageWidth : pageWidth
        const y1 = contentBox ? contentBox.bottom * pageHeight : pageHeight
        return {
            x: (pageWidth - (x1 - x0) * s) / 2 - x0 * s + tapOffsetX,
            y: (pageHeight - (y1 - y0) * s) / 2 - y0 * s + tapOffsetY,
            s,
        }
    }

    // Aplica el filtro de lectura y la escala/recorte visual. El canvas, la
    // capa de texto y la de anotaciones se transforman igual para que la
    // selección siga alineada con lo que se ve.
    const applyVisualState = () => {
        const root = doc.documentElement
        if (root) {
            root.style.setProperty('--pdf-filter', pdfState.filter || 'none')
        }
        if (!pageWidth) return
        const { x, y, s } = transformFor()
        const transform = `translate(${x}px, ${y}px) scale(${s})`
        for (const element of [canvas, highlightLayer, textLayer, annotationLayer]) {
            if (!element) continue
            element.style.transformOrigin = '0 0'
            element.style.transform = transform
        }
    }

    // Nodos de texto de la capa de selección, en el mismo orden que usa el
    // cálculo de desplazamientos al seleccionar.
    const textLayerTextNodes = () => {
        const nodes = []
        if (!textLayer) return nodes
        const walker = doc.createTreeWalker(textLayer, NodeFilter.SHOW_TEXT)
        let node
        while ((node = walker.nextNode())) {
            if (node.parentElement?.closest?.('.endOfContent')) continue
            nodes.push(node)
        }
        return nodes
    }

    // Convierte desplazamientos de caracteres en un Range del documento.
    const offsetsToRange = (start, end) => {
        const nodes = textLayerTextNodes()
        let acc = 0
        let startNode = null
        let startOffset = 0
        let endNode = null
        let endOffset = 0
        for (const node of nodes) {
            const length = node.nodeValue?.length ?? 0
            if (!startNode && start >= acc && start <= acc + length) {
                startNode = node
                startOffset = start - acc
            }
            if (!endNode && end >= acc && end <= acc + length) {
                endNode = node
                endOffset = end - acc
            }
            acc += length
            if (startNode && endNode) break
        }
        if (!startNode || !endNode) return null
        try {
            const range = doc.createRange()
            range.setStart(startNode, startOffset)
            range.setEnd(endNode, endOffset)
            return range
        } catch (_) {
            return null
        }
    }

    // Pinta los subrayados guardados de esta página sobre el canvas.
    const paintHighlights = () => {
        if (!highlightLayer || destroyed || !pageWidth) return
        const items = pdfHighlightStore.get(index + 1) || []
        highlightLayer.replaceChildren()
        if (!items.length) return
        // `getClientRects()` devuelve coordenadas ya transformadas: la capa de
        // texto se escala y se desplaza con el zoom/recorte, y la capa de
        // subrayados recibe exactamente la misma transformación. Hay que volver
        // al espacio local de la página para no aplicar la escala dos veces.
        const { x, y, s } = transformFor()
        const scale = s || 1
        for (const item of items) {
            const range = offsetsToRange(item.start, item.end)
            if (!range) continue
            let rects
            try { rects = range.getClientRects() } catch (_) { continue }
            const color = /^[0-9a-f]{6}$/i.test(item.color) ? item.color : 'FFEB3B'
            for (const rect of rects) {
                if (rect.width <= 0 || rect.height <= 0) continue
                const left = (rect.left - x) / scale
                const top = (rect.top - y) / scale
                const width = rect.width / scale
                const height = rect.height / scale
                const box = doc.createElement('div')
                box.className = 'pdf-highlight'
                box.style.left = `${left}px`
                box.style.top = `${top}px`
                box.style.width = `${width}px`
                box.style.backgroundColor = `#${color}`
                if (item.type === 'underline') {
                    box.style.height = '2px'
                    box.style.top = `${top + height - 2}px`
                    box.style.opacity = '0.95'
                    box.style.borderRadius = '0'
                } else {
                    box.style.height = `${height}px`
                    box.style.opacity = '0.38'
                }
                if (item.note) box.title = item.note
                highlightLayer.appendChild(box)
            }
        }
    }

    // ¿Hay una selección activa? Mientras el usuario ajusta los selectores
    // verdes no se debe repintar el canvas: Android muestra la lupa sobre la
    // superficie y un repintado la dejaba en blanco.
    const hasActiveSelection = () => {
        try {
            const own = doc.getSelection?.()
            if (own && own.toString().length > 0) return true
            const parent = window.getSelection?.()
            if (parent && parent.toString().length > 0) return true
        } catch (_) {}
        return false
    }

    // Fracción del área de la hoja que se ve en pantalla (0..1). Durante un
    // deslizamiento hay dos hojas visibles: sólo la que ocupa la mayor parte
    // debe anunciarse como página actual.
    const visibleRatio = () => {
        if (!iframe) return 1
        try {
            const rect = iframe.getBoundingClientRect()
            const width = Math.min(rect.right, window.innerWidth) - Math.max(rect.left, 0)
            const height = Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0)
            if (width <= 0 || height <= 0) return 0
            const area = Math.max(1, rect.width * rect.height)
            return (width * height) / area
        } catch (_) {
            return 1
        }
    }

    // Avisa a Flutter de la página visible para que el encabezado y el pie
    // (Page X / X/26) se actualicen al instante al cambiar de hoja.
    const reportVisiblePage = () => {
        if (destroyed || visibleRatio() < 0.55) return
        const page = index + 1
        if (page === lastReportedPdfPage) return
        lastReportedPdfPage = page
        try {
            window.flutter_inappwebview?.callHandler?.('onPdfPageChanged', {
                page,
                total: Number(totalPages) || 0,
            })
        } catch (_) {}
    }

    const controller = {
        doc, canvas, iframe,
        refresh: () => {
            applyVisualState()
            updateZoomState()
            schedule(0)
        },
        paintHighlights: () => paintHighlights(),
    }
    pdfPageControllers.add(controller)

    // Nivel de zoom real del usuario (sin contar el recorte automático de
    // márgenes): a partir de 1.05x la página está ampliada.
    const isZoomed = () => tapZoom * pdfState.zoom * visualScale > 1.05

    let zoomed = false
    const updateZoomState = () => {
        const next = isZoomed()
        if (next === zoomed) return
        zoomed = next
        setPdfZoomed(next)
    }

    const isVisible = () => {
        if (!iframe) return true
        try {
            const rect = iframe.getBoundingClientRect()
            return rect.bottom > 0 && rect.top < window.innerHeight
                && rect.right > 0 && rect.left < window.innerWidth
        } catch (_) {
            return true
        }
    }

    // Detecta los márgenes blancos de imprenta analyzing el bitmap renderizado.
    const analyzeContentBox = surface => {
        const width = 160
        const height = Math.max(1, Math.round(surface.height * width / surface.width))
        const probe = document.createElement('canvas')
        probe.width = width
        probe.height = height
        const probeContext = probe.getContext('2d', { willReadFrequently: true })
        probeContext.fillStyle = '#FFFFFF'
        probeContext.fillRect(0, 0, width, height)
        probeContext.drawImage(surface, 0, 0, width, height)
        let data
        try {
            data = probeContext.getImageData(0, 0, width, height).data
        } catch (_) {
            return null
        }
        let minX = width, minY = height, maxX = -1, maxY = -1
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const i = (y * width + x) * 4
                if (data[i] < 242 || data[i + 1] < 242 || data[i + 2] < 242) {
                    if (x < minX) minX = x
                    if (x > maxX) maxX = x
                    if (y < minY) minY = y
                    if (y > maxY) maxY = y
                }
            }
        }
        if (maxX < 0 || maxY < 0) return null
        return {
            left: minX / width,
            top: minY / height,
            right: (maxX + 1) / width,
            bottom: (maxY + 1) / height,
        }
    }

    // Escala con la que se recorta el margen: justo la que hace que el
    // contenido ocupe la página, sin pasarse.
    const computeCropScale = () => {
        if (!contentBox) return 1
        const contentWidth = contentBox.right - contentBox.left
        const contentHeight = contentBox.bottom - contentBox.top
        if (contentWidth <= 0.05 || contentHeight <= 0.05) return 1
        const scale = Math.min(1 / contentWidth, 1 / contentHeight, MAX_CROP_SCALE)
        return scale > 1.02 ? scale : 1
    }

    const render = async () => {
        // Nunca se limpia/repinta el canvas mientras hay texto seleccionado:
        // Android dibuja la lupa sobre la superficie y un repintado la dejaba
        // en blanco (recuadro blanco sin letras).
        if (hasActiveSelection()) {
            schedule(200)
            return
        }
        const token = ++generation
        try {
            const page = await getPage(index)
            if (destroyed || token !== generation) return

            const baseViewport = page.getViewport({ scale: 1 })
            pageWidth = baseViewport.width
            pageHeight = baseViewport.height
            const dpr = (typeof devicePixelRatio === 'number' && devicePixelRatio) || 1
            // `cssScale` is baseScale * zoomLevel (fixed-layout applies both);
            // the native pinch adds `visualScale` on top. Cap the zoom factor so
            // a 5x pinch does not allocate a canvas no screen can show.
            const currentZoom = Math.max(cssScale * visualScale, 0.1)
            const zoomLimit = Math.max(fitScale, 0.1) * MAX_RENDER_ZOOM
            let scale = Math.min(currentZoom, zoomLimit) * dpr * displayScale()
            const byDimension = Math.min(
                MAX_CANVAS_DIMENSION / baseViewport.width,
                MAX_CANVAS_DIMENSION / baseViewport.height)
            const byArea = Math.sqrt(
                MAX_CANVAS_PIXELS / (baseViewport.width * baseViewport.height))
            scale = clamp(scale, 0.1, Math.min(byDimension, byArea))

            // Off-screen neighbours only keep a cheap preview. Full density is
            // reserved for the page the reader is actually looking at, so
            // zooming never allocates several giant canvases at once.
            if (!isVisible()) scale = Math.min(scale, 1.25 * dpr)

            if (canvas.width && Math.abs(scale - renderedScale) < 0.02) {
                applyVisualState()
                paintHighlights()
                reportVisiblePage()
                return
            }

            const viewport = page.getViewport({ scale })
            const width = Math.max(1, Math.floor(viewport.width))
            const height = Math.max(1, Math.floor(viewport.height))
            if (task) {
                try { task.cancel() } catch (_) {}
                task = null
            }

            // Render in the PARENT document. PDF.js registers its FontFaces on
            // the main document, and a canvas owned by this iframe cannot see
            // them: it would fall back to generic fonts and draw wrong glyphs
            // (the □□□ boxes). The finished bitmap is blitted below.
            const surface = document.createElement('canvas')
            surface.width = width
            surface.height = height
            const surfaceContext = surface.getContext('2d', { alpha: false })
            // White canvas from the first paint: no black/transparent flash.
            surfaceContext.fillStyle = '#FFFFFF'
            surfaceContext.fillRect(0, 0, width, height)
            surfaceContext.imageSmoothingEnabled = true
            surfaceContext.imageSmoothingQuality = 'high'

            task = page.render({
                canvasContext: surfaceContext,
                viewport,
                intent: 'display',
                background: '#FFFFFF',
            })
            await task.promise
            if (destroyed || token !== generation) return
            // La selección pudo empezar durante el render: se conserva el
            // bitmap anterior y se reintenta al terminar de seleccionar.
            if (hasActiveSelection()) {
                surface.width = 0
                surface.height = 0
                schedule(200)
                return
            }

            // Primera pasada: se buscan los márgenes blancos para ampliar la
            // página hasta que el texto llene el ancho disponible.
            if (!contentBox) {
                const box = analyzeContentBox(surface)
                if (box) {
                    contentBox = box
                    const newCrop = computeCropScale()
                    if (Math.abs(newCrop - cropScale) > 0.01) {
                        cropScale = newCrop
                        surface.width = 0
                        surface.height = 0
                        applyVisualState()
                        schedule(0)
                        return
                    }
                }
            }

            // Same CSS size as before, only the backing store grows, so the
            // text layer and the page layout stay untouched.
            canvas.width = width
            canvas.height = height
            const canvasContext = canvas.getContext('2d', { alpha: false })
            canvasContext.fillStyle = '#FFFFFF'
            canvasContext.fillRect(0, 0, width, height)
            canvasContext.imageSmoothingEnabled = true
            canvasContext.imageSmoothingQuality = 'high'
            canvasContext.drawImage(surface, 0, 0)
            surface.width = 0
            surface.height = 0
            renderedScale = scale
            applyVisualState()
            paintHighlights()
            reportVisiblePage()
        } catch (error) {
            if (error?.name !== 'RenderingCancelledException')
                console.warn('PDF page render failed', error)
        }
    }

    // Doble toque: alterna entre 1x y 2x centrado en el punto tocado.
    const toggleTapZoom = (clientX, clientY) => {
        if (destroyed || !pageWidth) return
        const current = displayScale()
        const x = clientX / current
        const y = clientY / current
        const next = tapZoom > 1 ? 1 : 2
        const nextScale = cropScale * pdfState.zoom * next
        const delta = nextScale - current
        tapOffsetX -= x * delta
        tapOffsetY -= y * delta
        tapZoom = next
        applyVisualState()
        updateZoomState()
        schedule(0)
    }

    // Con la página ampliada se bloquea el arrastre horizontal para poder
    // explorar la zona ampliada sin cambiar de página por accidente. El
    // pinzamiento (dos dedos) no se toca para no romper el zoom nativo.
    let touchStartX = null
    let touchStartY = null
    const onTouchStart = event => {
        const touch = event.touches?.[0]
        if (!touch) return
        touchStartX = touch.clientX
        touchStartY = touch.clientY
    }
    const onTouchMove = event => {
        if (!isZoomed()) return
        if (event.touches.length !== 1) return
        if (touchStartX == null) return
        const touch = event.touches[0]
        const dx = Math.abs(touch.clientX - touchStartX)
        const dy = Math.abs(touch.clientY - touchStartY)
        if (dx > dy && dx > 8) event.preventDefault()
    }

    let lastTapTime = 0
    let lastTapX = 0
    let lastTapY = 0
    const onTouchEnd = event => {
        const touch = event.changedTouches?.[0]
        if (!touch) return
        const now = Date.now()
        const isDoubleTap = now - lastTapTime < 320
            && Math.abs(touch.clientX - lastTapX) < 48
            && Math.abs(touch.clientY - lastTapY) < 48
        if (isDoubleTap) {
            lastTapTime = 0
            toggleTapZoom(touch.clientX, touch.clientY)
        } else {
            lastTapTime = now
            lastTapX = touch.clientX
            lastTapY = touch.clientY
        }
    }
    const onDoubleClick = event => {
        if (typeof event.clientX !== 'number') return
        toggleTapZoom(event.clientX, event.clientY)
    }
    try {
        doc.addEventListener('touchstart', onTouchStart, { passive: true })
        doc.addEventListener('touchmove', onTouchMove, { passive: false })
        doc.addEventListener('touchend', onTouchEnd, { passive: true })
        doc.addEventListener('dblclick', onDoubleClick)
    } catch (_) {}

    // The renderer (fixed-layout) assigns `doc.scale` with baseScale * zoom
    // and then on every pinch update. Re-render only once the value settles.
    try {
        const initialScale = Number(doc.scale)
        if (Number.isFinite(initialScale) && initialScale > 0) {
            cssScale = initialScale
            // Scale that fits the page on screen (zoom factor 1).
            fitScale = initialScale
        }
        Object.defineProperty(doc, 'scale', {
            configurable: true,
            get: () => cssScale,
            set: value => {
                const next = Number(value) || 1
                if (Math.abs(next - cssScale) < 0.001) return
                cssScale = next
                schedule(120)
            },
        })
    } catch (_) {
        // A cross-origin page cannot be controlled; it is not expected here.
    }

    const unregister = registerVisualZoom(scale => {
        visualScale = scale
        updateZoomState()
        schedule(120)
    })

    // When a neighbour scrolls into view, upgrade it from preview to full
    // density.
    let visibilityObserver = null
    if (iframe && typeof IntersectionObserver === 'function') {
        visibilityObserver = new IntersectionObserver(entries => {
            if (!entries.some(entry => entry.isIntersecting)) return
            schedule(0)
            // Solo la hoja que ocupa la mayor parte de la pantalla se anuncia
            // como página actual (evita que la vecina pise el contador).
            if (entries.some(entry => entry.intersectionRatio >= 0.6)) {
                reportVisiblePage()
            }
        }, { threshold: [0, 0.6] })
        try { visibilityObserver.observe(iframe) } catch (_) {}
    }

    const cleanup = () => {
        destroyed = true
        if (timer) clearTimeout(timer)
        pdfPageRegistry.delete(registryEntry)
        pdfPageControllers.delete(controller)
        unregister()
        visibilityObserver?.disconnect()
        try {
            doc.removeEventListener('touchstart', onTouchStart)
            doc.removeEventListener('touchmove', onTouchMove)
            doc.removeEventListener('touchend', onTouchEnd)
            doc.removeEventListener('dblclick', onDoubleClick)
        } catch (_) {}
        if (task) {
            try { task.cancel() } catch (_) {}
        }
    }
    try {
        doc.defaultView?.addEventListener('pagehide', cleanup, { once: true })
        doc.defaultView?.addEventListener('unload', cleanup, { once: true })
    } catch (_) {}

    // Paint a first frame immediately (white background until PDF.js finishes),
    // then let the real layout scale replace it with a sharper render.
    applyVisualState()
    paintHighlights()
    schedule(0)

    // Pre-load only the adjacent pages in the background, as Google Drive does.
    prefetch(index - 1)
    prefetch(index + 1)
}

// Cover thumbnail used only while importing a book into the library. The
// reader itself never rasterizes pages.
const renderCover = async page => {
    const viewport = page.getViewport({ scale: 1.5 })
    const canvas = document.createElement('canvas')
    canvas.width = Math.max(1, Math.ceil(viewport.width))
    canvas.height = Math.max(1, Math.ceil(viewport.height))
    const canvasContext = canvas.getContext('2d')
    canvasContext.fillStyle = '#FFFFFF'
    canvasContext.fillRect(0, 0, canvas.width, canvas.height)
    await page.render({
        canvasContext, viewport, background: '#FFFFFF',
    }).promise
    return new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
}

/// Aplica los cambios de estilo del lector al visor PDF:
///  - el tamaño de fuente funciona como multiplicador de escala de la página
///  - el color de fondo del tema activa el filtro nocturno/sepia
export const applyPdfStyle = style => {
    const fontSize = Number(style?.fontSize)
    if (Number.isFinite(fontSize) && fontSize > 0) {
        pdfState.zoom = clamp(fontSize / PDF_DEFAULT_FONT_SIZE, 0.35, 2.2)
    }
    pdfState.filter = computeReadingFilter(style?.backgroundColor)
    for (const controller of pdfPageControllers) {
        try { controller.refresh() } catch (_) {}
    }
}

export const makePDF = async file => {
    const data = new Uint8Array(await file.arrayBuffer())
    const fontAssets = await getFontAssetOptions()
    const pdf = await pdfjsLib.getDocument({
        data,
        // Embedded fonts go through the FontFace API: that is what draws the
        // real glyphs instead of empty boxes.
        disableFontFace: false,
        ...fontAssets,
    }).promise

    const book = { rendition: { layout: 'pre-paginated' } }
    book.isPDF = true

    const info = (await pdf.getMetadata())?.info
    book.metadata = {
        title: info?.Title,
        author: info?.Author,
    }

    const outline = await pdf.getOutline()
    // Índice real del PDF: los marcadores (outline) con la página a la que
    // apunta cada uno. El href es el id de la sección (índice de página), que
    // es lo que usa el visor para saltar al contenido.
    const resolveDestIndex = async dest => {
        try {
            if (dest == null) return null
            const resolved = typeof dest === 'string'
                ? await pdf.getDestination(dest)
                : dest
            if (!resolved || !resolved[0]) return null
            const index = await pdf.getPageIndex(resolved[0])
            return Number.isInteger(index) ? index : null
        } catch (_) {
            return null
        }
    }

    const buildOutlineTOC = async items => {
        const result = []
        for (const item of items ?? []) {
            const index = await resolveDestIndex(item.dest)
            if (index == null) continue
            const subitems = item.items?.length
                ? await buildOutlineTOC(item.items)
                : null
            result.push({
                label: item.title,
                href: String(index),
                subitems,
            })
        }
        return result
    }

    const toc = await buildOutlineTOC(outline)
    if (toc.length) {
        book.toc = toc
    } else {
        // El PDF no trae marcadores internos: se usa la lista de páginas.
        book.toc = Array.from({ length: pdf.numPages }, (_, index) => ({
            label: `Page ${index + 1}`,
            href: String(index),
            subitems: null,
        }))
    }

    // Only metadata is requested up front. Pages are fetched on demand, so a
    // 500+ page document opens as fast as a 5 page one.
    const pagePromises = new Map()
    const textPromises = new Map()
    const annotationPromises = new Map()
    const shellPromises = new Map()

    const getPage = index => {
        if (index < 0 || index >= pdf.numPages)
            return Promise.reject(new Error('Page out of range'))
        if (!pagePromises.has(index))
            pagePromises.set(index, pdf.getPage(index + 1))
        return pagePromises.get(index)
    }
    const getTextContent = index => {
        if (!textPromises.has(index))
            textPromises.set(index, getPage(index).then(page => page.getTextContent()))
        return textPromises.get(index)
    }
    const getAnnotations = index => {
        if (!annotationPromises.has(index))
            annotationPromises.set(index, getPage(index).then(page => page.getAnnotations()))
        return annotationPromises.get(index)
    }

    // Builds the white page shell (canvas + vector text layer + annotations).
    // Nothing is rasterized here: the canvas is painted later by attachCanvasPage.
    const buildShell = async index => {
        const [page, textContent, annotations] = await Promise.all([
            getPage(index), getTextContent(index), getAnnotations(index),
        ])
        const viewport = page.getViewport({ scale: 1 })

        const textLayer = document.createElement('div')
        textLayer.classList.add('textLayer')
        textLayer.style.setProperty('--scale-factor', '1')
        // PDF.js reads `--scale-factor` through getComputedStyle, which only
        // works reliably for elements attached to the document.
        const staging = document.createElement('div')
        staging.style.cssText =
            'position:absolute;left:-100000px;top:0;visibility:hidden;pointer-events:none;'
        staging.append(textLayer)
        document.body.append(staging)
        // PDF.js entrega los fragmentos en el orden interno del PDF, que a
        // veces no coincide con el orden visual. Al ordenarlos de arriba hacia
        // abajo (transform[5] descendente) y de izquierda a derecha
        // (transform[4] ascendente), arrastrar los selectores verdes sigue el
        // texto de la página y no salta al pie ni a otra columna. Los
        // marcadores de contenido (sin `transform`) se quedan en su sitio.
        const items = Array.isArray(textContent?.items)
            ? [...textContent.items]
            : []
        const textSlots = []
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (Array.isArray(item?.transform) && typeof item.str === 'string')
                textSlots.push(i)
        }
        const orderedItems = textSlots.map(i => items[i]).sort((a, b) => {
            const ay = Number(a?.transform?.[5]) || 0
            const by = Number(b?.transform?.[5]) || 0
            if (Math.abs(by - ay) > 0.5) return by - ay
            const ax = Number(a?.transform?.[4]) || 0
            const bx = Number(b?.transform?.[4]) || 0
            return ax - bx
        })
        textSlots.forEach((slot, k) => { items[slot] = orderedItems[k] })
        const sortedTextContent = { ...textContent, items }
        try {
            await pdfjsLib.renderTextLayer({
                textContentSource: sortedTextContent,
                container: textLayer,
                viewport,
            }).promise
        } finally {
            staging.remove()
        }

        const annotationLayer = document.createElement('div')
        annotationLayer.classList.add('annotationLayer')
        annotationLayer.style.setProperty('--scale-factor', '1')
        await new pdfjsLib.AnnotationLayer({
            page, viewport, div: annotationLayer,
        }).render({
            annotations,
            linkService: {
                getDestinationHash: dest => JSON.stringify(dest),
                addLinkAttributes: (link, url) => link.href = url,
            },
        })

        const width = viewport.width
        const height = viewport.height
        return URL.createObjectURL(new Blob([`
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=${width}, height=${height}">
            <style>
            :root {
                --scale-factor: 1;
            }
            html, body {
                margin: 0;
                padding: 0;
                width: 100%;
                height: 100%;
                overflow: hidden;
                background: #FFFFFF;
            }
            body > canvas.pdf-page-canvas {
                display: block;
                width: 100%;
                height: 100%;
                background: #FFFFFF;
                /* Filtro de lectura nocturna/sepia. Al ser un filtro CSS los
                   píxeles del canvas no cambian, así que la captura para la IA
                   sigue siendo la imagen original. */
                filter: var(--pdf-filter, none);
            }
            /* Capa propia para los subrayados guardados: se pinta con rects del
               rango de texto, así que no modifica el DOM de la capa de texto ni
               afecta a la selección. */
            .pdf-highlight-layer {
                position: absolute;
                inset: 0;
                overflow: hidden;
                pointer-events: none;
                transform-origin: 0 0;
                z-index: 1;
            }
            .pdf-highlight-layer .pdf-highlight {
                position: absolute;
                border-radius: 2px;
                mix-blend-mode: multiply;
                pointer-events: none;
            }
            ${textLayerBuilderCSS}
            ${annotationLayerBuilderCSS}
            /* La capa de texto es solo una superficie invisible de selección:
               sus glifos nunca se pintan y los resaltados se mezclan con el
               canvas (multiply) para no tapar las letras. */
            :root {
                --highlight-bg-color: rgba(59, 130, 246, 0.32);
                --highlight-selected-bg-color: rgba(59, 130, 246, 0.45);
            }
            .textLayer {
                opacity: 1;
                mix-blend-mode: multiply;
                /* El contenedor no es seleccionable: tocar un hueco en blanco
                   entre líneas ya no arrastra toda la página. Solo los <span>
                   con texto real participan en la selección. */
                user-select: none;
                -webkit-user-select: none;
            }
            .textLayer span {
                user-select: text;
                -webkit-user-select: text;
                line-height: 1.0;
            }
            .textLayer :is(span, br) {
                color: transparent !important;
                -webkit-text-fill-color: transparent !important;
                text-shadow: none !important;
            }
            .textLayer .highlight,
            .textLayer .highlight.selected,
            .textLayer .highlight.appended {
                mix-blend-mode: multiply;
            }
            .textLayer ::selection {
                background: rgba(59, 130, 246, 0.25);
                color: transparent;
                -webkit-text-fill-color: transparent;
            }
            </style>
            </head>
            <body>
            <canvas class="pdf-page-canvas"></canvas>
            <div class="pdf-highlight-layer"></div>
            ${textLayer.outerHTML}
            ${annotationLayer.outerHTML}
            </body>
            </html>
        `], { type: 'text/html' }))
    }

    const getShellUrl = index => {
        if (!shellPromises.has(index)) {
            const promise = buildShell(index).catch(error => {
                shellPromises.delete(index)
                throw error
            })
            shellPromises.set(index, promise)
        }
        return shellPromises.get(index)
    }

    // Background warm-up of the neighbouring pages (never the whole document).
    const prefetch = index => {
        if (index < 0 || index >= pdf.numPages) return
        setTimeout(() => {
            getShellUrl(index).catch(() => {})
        }, 80)
    }

    book.onPageLoad = (doc, index) => attachCanvasPage({
        doc, index, getPage, prefetch, totalPages: pdf.numPages,
    })

    book.sections = Array.from({ length: pdf.numPages }).map((_, i) => ({
        id: i,
        load: () => getShellUrl(i),
        size: 1000,
    }))
    book.sections[0].pageSpread = 'right'
    // size of a page at scale 1, used to reserve space before it is rendered
    book.getPageSize = async index => {
        const page = await getPage(index)
        const { width, height } = page.getViewport({ scale: 1 })
        return { width, height }
    }
    book.isExternal = uri => /^\w+:/i.test(uri)
    book.resolveHref = async href => {
        // El índice del PDF usa el id de la sección (índice de página).
        if (typeof href === 'string' && /^\d+$/.test(href)) {
            const index = Math.min(Math.max(Number(href), 0), pdf.numPages - 1)
            return { index }
        }
        const parsed = JSON.parse(href)
        const dest = typeof parsed === 'string'
            ? await pdf.getDestination(parsed) : parsed
        if (!dest || !dest[0]) return { index: 0 }
        const index = await pdf.getPageIndex(dest[0])
        return { index }
    }
    book.splitTOCHref = async href => {
        if (typeof href === 'string' && /^\d+$/.test(href)) {
            return [Math.min(Math.max(Number(href), 0), pdf.numPages - 1), null]
        }
        const parsed = JSON.parse(href)
        const dest = typeof parsed === 'string'
            ? await pdf.getDestination(parsed) : parsed
        if (!dest || !dest[0]) return [0, null]
        const index = await pdf.getPageIndex(dest[0])
        return [index, null]
    }
    book.getTOCFragment = doc => doc.documentElement
    book.getCover = async () => renderCover(await getPage(0))
    return book
}
