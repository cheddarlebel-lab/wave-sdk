import { stateStream } from "./stream.js";
import type { EmitterLike, UnlockState, WaveNativeModule, WaveRNConfig } from "./types.js";

export type { UnlockState, WaveRNConfig } from "./types.js";
export { isTerminal } from "./types.js";
export { stateStream } from "./stream.js";

/// Loads the RN native module + event emitter lazily so this package is importable
/// (and testable) outside a React Native runtime.
async function defaultBindings(): Promise<{ native: WaveNativeModule; emitter: EmitterLike }> {
  const rn = await import("react-native");
  const native = (rn as unknown as { NativeModules: Record<string, WaveNativeModule> }).NativeModules.WaveUnlock;
  if (!native) throw new Error("WaveUnlock native module not linked. Rebuild the app after installing.");
  const Emitter = (rn as unknown as { NativeEventEmitter: new (m: unknown) => EmitterLike }).NativeEventEmitter;
  return { native, emitter: new Emitter(native) };
}

/// The public facade. `unlock()` streams states from the native core.
///
/// ```ts
/// const wave = new WaveUnlock(config);
/// for await (const state of wave.unlock()) render(state);
/// ```
export class WaveUnlock {
  constructor(
    private config: WaveRNConfig,
    private deps?: { native: WaveNativeModule; emitter: EmitterLike },
  ) {}

  async *unlock(): AsyncGenerator<UnlockState> {
    const { native, emitter } = this.deps ?? (await defaultBindings());
    yield* stateStream(emitter, () => native.startUnlock(this.config), () => native.cancel());
  }
}
