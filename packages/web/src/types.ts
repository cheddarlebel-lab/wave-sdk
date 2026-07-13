export type UnlockState =
  | { kind: "scanning" }
  | { kind: "readerFound" }
  | { kind: "writing" }
  | { kind: "awaitingConfirmation" }
  | { kind: "granted"; reason: string }
  | { kind: "denied"; reason: string }
  | { kind: "timedOut" }
  | { kind: "failed"; error: string };

export type WaveWebConfig = {
  gatewayUrl: string;
  anonKey: string;
  publishableKey: string;
  userNumber: string;
};

export type UnlockOptions = {
  cloudTimeoutMs?: number; // default 5000
  pollIntervalMs?: number; // default 500
};

// A connect+write transport. WebBluetoothTransport is the real one; tests inject a mock.
export interface WebTransport {
  connect(): Promise<void>;
  write(payload: Uint8Array): Promise<void>;
  disconnect(): void;
}

export function payloadFor(userNumber: string): Uint8Array {
  return new Uint8Array([0x01, ...new TextEncoder().encode(userNumber)]);
}
