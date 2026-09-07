export class ParsedAddress {
  ip: string = '';
  port: number = 53317;
  protocol: string = 'https';
  explicitProtocol: boolean = false;
}

export class LocalInterface {
  name: string = '';
  ip: string = '';
  prefixLength: number = 0;
  ignored: boolean = false;
}

export function ipv4(ip: string): boolean {
  return /^\d{1,3}(\.\d{1,3}){3}$/.test(ip) && ip.split('.').every((part: string) => Number(part) <= 255);
}

export function multicastAddress(input: string): string {
  const address = input.trim();
  if (!ipv4(address)) throw new Error('请输入有效的 IPv4 组播地址');
  const parts = address.split('.').map((part: string) => Number(part));
  if (parts[0] < 224 || parts[0] > 239) throw new Error('请输入有效的 IPv4 组播地址');
  return parts.join('.');
}

export function ipv6(ip: string): boolean {
  const scoped = ip.split('%');
  if (scoped.length > 2 || (scoped.length === 2 && !/^[a-zA-Z0-9_.-]+$/.test(scoped[1]))) return false;
  let address = scoped[0];
  if (address.includes('.')) {
    const last = address.lastIndexOf(':');
    if (last < 0 || !ipv4(address.slice(last + 1))) return false;
    address = address.slice(0, last + 1) + '0:0';
  }
  if (!address.includes(':') || address.includes(':::') || address.split('::').length > 2) return false;
  const groups = address.split(':').filter((part: string) => part !== '');
  if (!groups.every((part: string) => /^[0-9a-f]{1,4}$/i.test(part))) return false;
  return address.includes('::') ? groups.length < 8 : groups.length === 8 && !address.startsWith(':') && !address.endsWith(':');
}

export function parseAddress(input: string): ParsedAddress {
  const parsed = new ParsedAddress();
  let host = input.trim();
  if (/^https?:\/\//i.test(host)) {
    parsed.explicitProtocol = true; parsed.protocol = host.toLowerCase().startsWith('http://') ? 'http' : 'https';
    host = host.replace(/^https?:\/\//i, '');
  }
  host = host.replace(/\/$/, '');
  let port = '';
  if (host.startsWith('[')) {
    const end = host.indexOf(']'); if (end < 0) throw new Error('IPv6 地址缺少右括号');
    parsed.ip = host.slice(1, end).replace('%25', '%');
    if (host.length > end + 1) {
      if (host[end + 1] !== ':') throw new Error('地址格式无效');
      port = host.slice(end + 2); if (!port) throw new Error('端口不能为空');
    }
    if (!ipv6(parsed.ip)) throw new Error('请输入有效 IPv6 地址');
  } else if (host.split(':').length > 2) {
    parsed.ip = host; if (!ipv6(host)) throw new Error('请输入有效 IPv6 地址');
  } else {
    const parts = host.split(':'); parsed.ip = parts[0]; port = parts[1] || '';
    if (!ipv4(parsed.ip)) throw new Error('请输入有效 IP 地址');
    if (parts.length === 2 && !port) throw new Error('端口不能为空');
  }
  if (port) {
    if (!/^\d+$/.test(port)) throw new Error('端口无效'); parsed.port = Number(port);
    if (!Number.isInteger(parsed.port) || parsed.port < 1 || parsed.port > 65535) throw new Error('端口无效');
  }
  return parsed;
}

export function matchesPattern(ip: string, pattern: string): boolean {
  if (!/^[a-zA-Z0-9.:_%*-]+$/.test(pattern)) return false;
  return new RegExp('^' + pattern.replace(/\./g, '\\.').replace(/\*/g, '[^.]+') + '$', 'i').test(ip);
}

export function ignoredInterface(ips: string[], mode: string, patterns: string[]): boolean {
  if (mode === 'none') return false;
  const matches = ips.some((ip: string) => patterns.some((pattern: string) => matchesPattern(ip, pattern)));
  return mode === 'allow' ? !matches : matches;
}

export function sameSubnet(a: string, b: string, prefix: number): boolean {
  if (!ipv4(a) || !ipv4(b) || prefix < 1 || prefix > 32) return false;
  const number = (ip: string): number => ip.split('.').reduce((value: number, part: string) => value * 256 + Number(part), 0);
  const divisor = Math.pow(2, 32 - prefix);
  return Math.floor(number(a) / divisor) === Math.floor(number(b) / divisor);
}
