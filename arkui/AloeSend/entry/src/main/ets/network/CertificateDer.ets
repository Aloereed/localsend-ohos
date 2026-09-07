// Minimal DER encoder for a per-installation self-signed LocalSend TLS identity.
// Cryptographic key generation and signing are performed by HarmonyOS CryptoFramework.
export function joinDer(parts: Uint8Array[]): Uint8Array {
  const size = parts.reduce((sum: number, part: Uint8Array) => sum + part.length, 0);
  const result = new Uint8Array(size); let offset = 0;
  for (const part of parts) { result.set(part, offset); offset += part.length; }
  return result;
}

export function der(tag: number, data: Uint8Array): Uint8Array {
  const length: number[] = [];
  let remaining = data.length;
  if (remaining < 128) length.push(remaining);
  else {
    while (remaining > 0) { length.unshift(remaining & 255); remaining = Math.floor(remaining / 256); }
    length.unshift(128 | length.length);
  }
  return joinDer([new Uint8Array([tag, ...length]), data]);
}

export function sequence(parts: Uint8Array[]): Uint8Array { return der(48, joinDer(parts)); }

export function oid(value: string): Uint8Array {
  const components = value.split('.').map((part: string) => Number(part));
  const output: number[] = [components[0] * 40 + components[1]];
  for (let i = 2; i < components.length; i++) {
    let value = components[i]; const encoded: number[] = [value & 127];
    while (value >= 128) { value = Math.floor(value / 128); encoded.unshift((value & 127) | 128); }
    output.push(...encoded);
  }
  return der(6, new Uint8Array(output));
}

export function signatureAlgorithm(): Uint8Array { return sequence([oid('1.2.840.113549.1.1.11'), der(5, new Uint8Array(0))]); }

function asciiDer(value: string): Uint8Array {
  return new Uint8Array(value.split('').map((char: string) => char.charCodeAt(0)));
}

function dateDer(date: Date): Uint8Array {
  const value = date.toISOString().replace(/[-:]/g, '').split('.')[0].replace('T', '') + 'Z';
  return date.getUTCFullYear() < 2050 ? der(23, asciiDer(value.slice(2))) : der(24, asciiDer(value));
}

export function makeTbsCertificate(publicKeySpki: Uint8Array, serial: Uint8Array, now: number): Uint8Array {
  let first = 0;
  while (first < serial.length && serial[first] === 0) first++;
  let positiveSerial = first === serial.length ? new Uint8Array([1]) : serial.slice(first);
  // DER INTEGER is signed and requires minimal encoding: only a high leading
  // bit needs a zero prefix. Random leading zeros must not become padding.
  if (positiveSerial[0] >= 128) positiveSerial = joinDer([new Uint8Array([0]), positiveSerial]);
  const name = sequence([der(49, sequence([oid('2.5.4.3'), der(12, asciiDer('LocalSend ArkUI'))]))]);
  const extensions = sequence([
    sequence([oid('2.5.29.19'), der(1, new Uint8Array([255])), der(4, sequence([]))]),
    sequence([oid('2.5.29.15'), der(1, new Uint8Array([255])), der(4, der(3, new Uint8Array([5, 160])))]),
    sequence([oid('2.5.29.37'), der(4, sequence([oid('1.3.6.1.5.5.7.3.1'), oid('1.3.6.1.5.5.7.3.2')]))])
  ]);
  return sequence([
    der(160, der(2, new Uint8Array([2]))), der(2, positiveSerial), signatureAlgorithm(), name,
    sequence([dateDer(new Date(now - 86400000)), dateDer(new Date(now + 3650 * 86400000))]),
    name, publicKeySpki, der(163, extensions)
  ]);
}

export function assembleCertificate(tbs: Uint8Array, signature: Uint8Array): Uint8Array {
  return sequence([tbs, signatureAlgorithm(), der(3, joinDer([new Uint8Array([0]), signature]))]);
}
