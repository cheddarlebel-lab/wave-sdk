# Wave Unlock — Web

`index.html` here is fully runnable. Serve it and open in Chrome/Edge:

```bash
python3 -m http.server 8000   # then visit http://localhost:8000
```

- **Simulate unlock** works anywhere — it drives the live gateway mock (no hardware).
- **Unlock a real door** needs Web Bluetooth: Chrome/Edge, a **secure context (https)**, and
  physical proximity to an `SKBluTag` reader.

For a real app use the package instead of raw fetch:

```ts
import { WaveUnlock } from "@wave/unlock-web";
const wave = new WaveUnlock({ publishableKey, userNumber });
for await (const state of wave.unlock()) render(state);
```

Web BLE is **foreground-only** — no background unlock. For that, use a native platform.
