import { fileIo as fs } from '@kit.CoreFileKit';
import * as native from 'libaloetls.so';

export async function directoryIdentity(uri: string): Promise<string> {
  const directory = await fs.open(uri, fs.OpenMode.READ_ONLY);
  try { return native.fileIdentity(directory.fd); }
  finally { await fs.close(directory); }
}
