import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
    readInitialPairingToken,
    readInitialWebSocketUrl,
    TOKEN_QUERY_PARAM,
    WS_QUERY_PARAM,
} from './remote-session.urls';

describe('remote-session.urls', () => {
    beforeEach(() => {
        window.localStorage.clear();
        window.history.replaceState({}, '', '/');
    });

    afterEach(() => {
        window.localStorage.clear();
        window.history.replaceState({}, '', '/');
    });

    it('returns default fallback URL when no explicit query is provided', () => {
        const url = readInitialWebSocketUrl();
        expect(url).toContain('3223');
        expect(url).toContain('/remote/ws');
    });

    it('respects explicit ws query parameter over defaults', () => {
        window.history.replaceState({}, '', `/?${WS_QUERY_PARAM}=ws://192.168.1.100:9999/custom`);
        expect(readInitialWebSocketUrl()).toBe('ws://192.168.1.100:9999/custom');
    });

    it('extracts pairing token from url and persists it in localStorage', () => {
        window.history.replaceState({}, '', `/?${TOKEN_QUERY_PARAM}=secret123`);
        const token = readInitialPairingToken();
        expect(token).toBe('secret123');
        expect(window.localStorage.getItem('wand-remote.pairing-token.v1')).toBe('secret123');
    });

    it('reads pairing token from localStorage if absent in url', () => {
        window.localStorage.setItem('wand-remote.pairing-token.v1', 'stored_token_abc');
        window.history.replaceState({}, '', '/');

        expect(readInitialPairingToken()).toBe('stored_token_abc');
    });
});
