/// State labels match the native cores + contract/conformance/state-sequences.json.
export type UnlockState =
  | { kind: "scanning" }
  | { kind: "readerFound"; rssi?: number }
  | { kind: "tooFar"; rssi?: number }
  | { kind: "writing" }
  | { kind: "awaitingConfirmation" }
  | { kind: "granted"; reason?: string }
  | { kind: "denied"; reason: string }
  | { kind: "timedOut" }
  | { kind: "failed"; error: string };

export type WaveRNConfig = {
  publishableKey: string;
  userNumber: string;
  /** Branded gateway; defaults to production on the native side. No Supabase key. */
  gatewayUrl?: string;
};

export const TERMINAL_KINDS = ["granted", "denied", "timedOut", "failed"] as const;

export function isTerminal(s: UnlockState): boolean {
  return (TERMINAL_KINDS as readonly string[]).includes(s.kind);
}

/// Minimal shape of RN's NativeEventEmitter that we depend on (keeps this testable).
export interface EmitterLike {
  addListener(event: string, cb: (payload: unknown) => void): { remove(): void };
}

/// The native module contract (implemented by ios/ + android/).
export interface WaveNativeModule {
  startUnlock(config: WaveRNConfig): void;
  cancel(): void;
}
