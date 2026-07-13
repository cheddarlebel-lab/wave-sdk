import { Gateway } from "./gateway.js";
import { runUnlock } from "./engine.js";
import { WebBluetoothTransport } from "./transport.js";
import type { UnlockOptions, UnlockState, WaveWebConfig, WebTransport } from "./types.js";

export type { UnlockState, WaveWebConfig, UnlockOptions, WebTransport } from "./types.js";
export { runUnlock } from "./engine.js";
export { Gateway } from "./gateway.js";
export { WebBluetoothTransport } from "./transport.js";
export { friendly } from "./denials.js";

/// The public facade. `unlock()` returns an async iterator of states.
///
/// ```ts
/// const wave = new WaveUnlock({ gatewayUrl, anonKey, publishableKey, userNumber });
/// for await (const state of wave.unlock()) render(state);
/// ```
export class WaveUnlock {
  private gateway: Gateway;
  constructor(
    private config: WaveWebConfig,
    private deps: { transport?: WebTransport; fetchImpl?: typeof fetch } = {},
  ) {
    this.gateway = new Gateway(config, deps.fetchImpl);
  }

  unlock(options?: UnlockOptions): AsyncGenerator<UnlockState> {
    const transport = this.deps.transport ?? new WebBluetoothTransport();
    return runUnlock(transport, this.gateway, this.config, options);
  }
}
