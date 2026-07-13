import { describe, it, expect, vi } from "vitest";
import { WaveUnlock } from "./index.js";
import { stateStream } from "./stream.js";
import type { EmitterLike, UnlockState, WaveNativeModule } from "./types.js";

const config = { gatewayUrl: "https://x/functions/v1", publishableKey: "wave_pub_x", userNumber: "10001" };

/// A fake native emitter we can push states through.
function fakeEmitter() {
  let cb: ((p: unknown) => void) | null = null;
  const emitter: EmitterLike = {
    addListener: (_e, fn) => { cb = fn; return { remove: vi.fn() }; },
  };
  return { emitter, emit: (s: UnlockState) => cb?.(s) };
}

async function labels(gen: AsyncGenerator<UnlockState>): Promise<string[]> {
  const out: string[] = [];
  for await (const s of gen) out.push(s.kind);
  return out;
}

describe("stateStream (thin bridge)", () => {
  it("streams native states through to the terminal", async () => {
    const { emitter, emit } = fakeEmitter();
    const start = () => {
      // native pushes the full sequence
      queueMicrotask(() => {
        emit({ kind: "scanning" });
        emit({ kind: "readerFound", rssi: -50 });
        emit({ kind: "writing" });
        emit({ kind: "awaitingConfirmation" });
        emit({ kind: "granted", reason: "Access Granted" });
      });
    };
    const seq = await labels(stateStream(emitter, start, vi.fn()));
    expect(seq).toEqual(["scanning", "readerFound", "writing", "awaitingConfirmation", "granted"]);
  });

  it("stops at a denial and removes the listener", async () => {
    const { emitter, emit } = fakeEmitter();
    const remove = vi.fn();
    const em: EmitterLike = { addListener: (e, fn) => { (emitter.addListener as any)(e, fn); return { remove }; } };
    const start = () => queueMicrotask(() => {
      emit({ kind: "scanning" });
      emit({ kind: "denied", reason: "Member not found" });
      emit({ kind: "granted" }); // must be ignored after terminal
    });
    const out: UnlockState[] = [];
    for await (const s of stateStream(em, start, vi.fn())) out.push(s);
    expect(out.map((s) => s.kind)).toEqual(["scanning", "denied"]);
    expect(remove).toHaveBeenCalled();
  });

  it("WaveUnlock facade uses injected native bindings", async () => {
    const { emitter, emit } = fakeEmitter();
    const native: WaveNativeModule = {
      startUnlock: vi.fn(() => queueMicrotask(() => {
        emit({ kind: "scanning" });
        emit({ kind: "timedOut" });
      })),
      cancel: vi.fn(),
    };
    const wave = new WaveUnlock(config, { native, emitter });
    const seq = await labels(wave.unlock());
    expect(seq).toEqual(["scanning", "timedOut"]);
    expect(native.startUnlock).toHaveBeenCalledWith(config);
  });
});
