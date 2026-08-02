/** Semver of the IPC protocol. Major = breaking, minor = additive, patch = docs. */
export const PROTOCOL_VERSION = "0.1.0";

/** Oldest protocol version this side still speaks. */
export const MIN_SUPPORTED = "0.1.0";

/** Default dev port for the shell's WebSocket server (env TUTOR_IPC_PORT overrides). */
export const DEFAULT_IPC_PORT = 47100;

/** WebSocket path on the shell's server. */
export const IPC_PATH = "/ipc";

/** Milliseconds the shell waits for session.hello before closing the socket. */
export const HELLO_TIMEOUT_MS = 3000;

/** WebSocket close code for a bad or missing token in session.hello. */
export const CLOSE_INVALID_TOKEN = 4401;

/** Default request timeout (ms); overlay.draw uses OVERLAY_TIMEOUT_MS. */
export const REQUEST_TIMEOUT_MS = 5000;
export const OVERLAY_TIMEOUT_MS = 2000;
