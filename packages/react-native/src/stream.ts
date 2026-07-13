import { isTerminal, type EmitterLike, type UnlockState } from "./types.js";

/// Convert the native module's "WaveUnlockState" events into an async iterator that
/// ends at the terminal state. This is the thin-bridge core; the native side runs the
/// real UnlockEngine (Swift/Kotlin) and emits each state.
export function stateStream(
  emitter: EmitterLike,
  start: () => void,
  cancel: () => void,
  eventName = "WaveUnlockState",
): AsyncGenerator<UnlockState> {
  const queue: UnlockState[] = [];
  let resolveNext: ((v: void) => void) | null = null;
  let finished = false;

  const sub = emitter.addListener(eventName, (payload) => {
    const state = payload as UnlockState;
    queue.push(state);
    if (isTerminal(state)) finished = true;
    resolveNext?.();
    resolveNext = null;
  });

  async function* gen(): AsyncGenerator<UnlockState> {
    try {
      start();
      while (true) {
        if (queue.length === 0) {
          if (finished) break;
          await new Promise<void>((r) => (resolveNext = r));
        }
        while (queue.length > 0) {
          const s = queue.shift()!;
          yield s;
          if (isTerminal(s)) return;
        }
      }
    } finally {
      sub.remove();
      if (!finished) cancel();
    }
  }

  return gen();
}
