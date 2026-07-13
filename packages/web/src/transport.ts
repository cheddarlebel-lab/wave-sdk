import type { WebTransport } from "./types.js";

const SERVICE = "496b2c43-b05e-4a9a-9592-535173b7ab51";
const WRITE_CHAR = "995b637f-13f2-4335-96f5-5541ecfce219";

/// Real Web Bluetooth transport. Foreground-only, secure context (https) required.
export class WebBluetoothTransport implements WebTransport {
  private device?: BluetoothDevice;
  private char?: BluetoothRemoteGATTCharacteristic;

  async connect(): Promise<void> {
    if (!("bluetooth" in navigator)) throw new Error("Web Bluetooth not supported in this browser");
    this.device = await navigator.bluetooth.requestDevice({
      filters: [{ namePrefix: "SKBluTag" }],
      optionalServices: [SERVICE],
    });
    const server = await this.device.gatt!.connect();
    const svc = await server.getPrimaryService(SERVICE);
    this.char = await svc.getCharacteristic(WRITE_CHAR);
  }

  async write(payload: Uint8Array): Promise<void> {
    if (!this.char) throw new Error("not connected");
    // write WITHOUT response; do not wait for a notify.
    const buffer = new ArrayBuffer(payload.byteLength);
    new Uint8Array(buffer).set(payload);
    await this.char.writeValueWithoutResponse(buffer);
  }

  disconnect(): void {
    this.device?.gatt?.disconnect();
  }
}
