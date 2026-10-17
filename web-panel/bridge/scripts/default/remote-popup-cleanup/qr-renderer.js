import { isRecord } from '../installed-apps-sync/runtime.js';

const WAND_QR_RENDERER_EXPORT = 'mo';

export function resolveQrRenderer(webpackRequire) {
    for (const record of Object.values(webpackRequire?.c || {})) {
        const exports = record?.exports;
        if (isRecord(exports)) {
            if (typeof exports[WAND_QR_RENDERER_EXPORT] === 'function') {
                return exports[WAND_QR_RENDERER_EXPORT];
            }
            if (typeof exports.toCanvas === 'function') {
                return exports.toCanvas;
            }
        }
    }

    return null;
}
