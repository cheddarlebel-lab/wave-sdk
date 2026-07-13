import { Gateway } from "./gateway.js";
import { friendly } from "./denials.js";
import { payloadFor, type UnlockState, type UnlockOptions, type WaveWebConfig, type WebTransport } from "./types.js";

/// Streams an unlock through its states: scan -> write -> await cloud verdict.
/// Mirrors the native cores' state sequence (contract/conformance/state-sequences.json).
export async function* runUnlock(
  transport: WebTransport,
  gateway: Gateway,
  config: WaveWebConfig,
  options: UnlockOptions = {},
): AsyncGenerator<UnlockState> {
  const cloudTimeoutMs = options.cloudTimeoutMs ?? 5000;
  const pollMs = options.pollIntervalMs ?? 500;

  yield { kind: "scanning" };
  try {
    await transport.connect();
  } catch (e) {
    yield { kind: "failed", error: (e as Error).message };
    return;
  }
  yield { kind: "readerFound" };

  yield { kind: "writing" };
  try {
    await transport.write(payloadFor(config.userNumber));
  } catch (e) {
    yield { kind: "failed", error: (e as Error).message };
    return;
  }
  setTimeout(() => transport.disconnect(), 1500);

  yield { kind: "awaitingConfirmation" };
  let token: string;
  try {
    token = await gateway.fetchToken();
  } catch (e) {
    yield { kind: "failed", error: (e as Error).message };
    return;
  }
  const outcome = await gateway.awaitOutcome(token, cloudTimeoutMs, pollMs);
  if (outcome.status === "granted") yield { kind: "granted", reason: friendly(outcome.reason) };
  else if (outcome.status === "denied") yield { kind: "denied", reason: friendly(outcome.reason) };
  else yield { kind: "timedOut" };
}
