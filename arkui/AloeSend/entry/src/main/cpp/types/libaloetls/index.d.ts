export interface TlsResult { plain: ArrayBuffer; wire: ArrayBuffer; closed: boolean; }
export const createServer: (certificate: string, key: string) => number;
export const createSession: (server: number) => number;
export const feed: (session: number, bytes: ArrayBuffer) => TlsResult;
export const write: (session: number, bytes: ArrayBuffer) => TlsResult;
export const closeSession: (session: number) => void;
export const closeServer: (server: number) => void;
