export interface TlsResult { plain: ArrayBuffer; wire: ArrayBuffer; closed: boolean; }
export const createServer: (certificate: string, key: string) => number;
export const createSession: (server: number) => number;
export const feed: (session: number, bytes: ArrayBuffer) => TlsResult;
export const write: (session: number, bytes: ArrayBuffer) => TlsResult;
export const shutdown: (session: number) => ArrayBuffer;
export const closeSession: (session: number) => void;
export const closeServer: (server: number) => void;
export interface TcpEvent { kind: string; id: number; ip: string; data: ArrayBuffer; error: string; }
export const tcpListen: (address: string, port: number, callback: (event: TcpEvent) => void) => number;
export const tcpRead: (connection: number) => void;
export const tcpSend: (connection: number, bytes: ArrayBuffer) => Promise<void>;
export const tcpClose: (connection: number) => void;
export const tcpStop: (server: number) => void;
