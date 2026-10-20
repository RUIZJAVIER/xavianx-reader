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
// painted straight onto a <canvas> by PDF.js, with a vector text layer on top,
// and re-rendered at the current zoom/device density when a gesture ends.
//
// A 5x zoom on a 3x screen would need a ~9k x 12k backing store (hundreds of
// MB), which would kill the WebView. These caps keep the longest side at
// 4096px / 16MP: at 5x that is still at least one physical pixel per displayed
// pixel (and much more at normal zoom), so text and vectors stay crisp without
// risking an out-of-memory crash.
const MAX_CANVAS_DIMENSION = 4096
const MAX_CANVAS_PIXELS = 16 * 1024 * 1024
const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

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
            }, 160)
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
const attachCanvasPage = ({ doc, index, getPage, prefetch }) => {
    const canvas = doc.querySelector('canvas.pdf-page-canvas')
    if (!canvas) return

    let cssScale = 1
    let visualScale = 1
    let renderedScale = 0
    let timer = 0
    let generation = 0
    let task = null
    let destroyed = false

    const schedule = delay => {
        if (destroyed) return
        if (timer) clearTimeout(timer)
        timer = setTimeout(() => {
            timer = 0
            render()
        }, delay)
    }

    const iframe = doc.defaultView?.frameElement
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

    const render = async () => {
        const token = ++generation
        try {
            const page = await getPage(index)
            if (destroyed || token !== generation) return

            const baseViewport = page.getViewport({ scale: 1 })
            const dpr = (typeof devicePixelRatio === 'number' && devicePixelRatio) || 1
            // baseScale * zoomLevel * devicePixelRatio. `cssScale` already
            // contains baseScale * zoomLevel (fixed-layout applies both).
            let scale = Math.max(cssScale, 0.1)
                * Math.max(visualScale, 0.1)
                * dpr
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

            if (canvas.width && Math.abs(scale - renderedScale) < 0.02) return

            const viewport = page.getViewport({ scale })
            if (task) {
                try { task.cancel() } catch (_) {}
                task = null
            }
            canvas.width = Math.max(1, Math.floor(viewport.width))
            canvas.height = Math.max(1, Math.floor(viewport.height))

            // White canvas from the first paint: no black/transparent flash.
            const canvasContext = canvas.getContext('2d', { alpha: false })
            canvasContext.fillStyle = '#FFFFFF'
            canvasContext.fillRect(0, 0, canvas.width, canvas.height)
            canvasContext.imageSmoothingEnabled = true
            canvasContext.imageSmoothingQuality = 'high'

            task = page.render({
                canvasContext,
                viewport,
                background: '#FFFFFF',
            })
            await task.promise
            if (token === generation) renderedScale = scale
        } catch (error) {
            if (error?.name !== 'RenderingCancelledException')
                console.warn('PDF page render failed', error)
        }
    }

    // The renderer (fixed-layout) assigns `doc.scale` with baseScale * zoom
    // and then on every pinch update. Re-render only once the value settles.
    try {
        const initialScale = Number(doc.scale)
        if (Number.isFinite(initialScale) && initialScale > 0)
            cssScale = initialScale
        Object.defineProperty(doc, 'scale', {
            configurable: true,
            get: () => cssScale,
            set: value => {
                const next = Number(value) || 1
                if (Math.abs(next - cssScale) < 0.001) return
                cssScale = next
                schedule(140)
            },
        })
    } catch (_) {
        // A cross-origin page cannot be controlled; it is not expected here.
    }

    const unregister = registerVisualZoom(scale => {
        visualScale = scale
        schedule(160)
    })

    // When a neighbour scrolls into view, upgrade it from preview to full
    // density.
    let visibilityObserver = null
    if (iframe && typeof IntersectionObserver === 'function') {
        visibilityObserver = new IntersectionObserver(entries => {
            if (entries.some(entry => entry.isIntersecting)) schedule(0)
        })
        try { visibilityObserver.observe(iframe) } catch (_) {}
    }

    const cleanup = () => {
        destroyed = true
        if (timer) clearTimeout(timer)
        unregister()
        visibilityObserver?.disconnect()
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
    schedule(0)

    // Pre-load only the adjacent pages in the background, as Google Drive does.
    prefetch(index - 1)
    prefetch(index + 1)
}

const makeTOCItem = item => ({
    label: item.title,
    href: JSON.stringify(item.dest),
    subitems: item.items.length ? item.items.map(makeTOCItem) : null,
})

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

export const makePDF = async file => {
    const data = new Uint8Array(await file.arrayBuffer())
    const pdf = await pdfjsLib.getDocument({ data }).promise

    const book = { rendition: { layout: 'pre-paginated' } }
    book.isPDF = true

    const info = (await pdf.getMetadata())?.info
    book.metadata = {
        title: info?.Title,
        author: info?.Author,
    }

    const outline = await pdf.getOutline()
    book.toc = outline?.map(makeTOCItem)

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
        try {
            await pdfjsLib.renderTextLayer({
                textContentSource: textContent,
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
            }
            ${textLayerBuilderCSS}
            ${annotationLayerBuilderCSS}
            </style>
            </head>
            <body>
            <canvas class="pdf-page-canvas"></canvas>
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
        doc, index, getPage, prefetch,
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
        const parsed = JSON.parse(href)
        const dest = typeof parsed === 'string'
            ? await pdf.getDestination(parsed) : parsed
        if (!dest || !dest[0]) return { index: 0 }
        const index = await pdf.getPageIndex(dest[0])
        return { index }
    }
    book.splitTOCHref = async href => {
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
