import { fileIo as fs } from '@kit.CoreFileKit';

// HarmonyOS mkdir(path, true) can report EEXIST for an existing final directory.
// DOWNLOAD authorization itself creates that directory before we get control.
export async function ensureDirectory(path: string): Promise<void> {
  if (await fs.access(path)) {
    if (!(await fs.stat(path)).isDirectory()) throw new Error('保存目录被同名文件占用');
    return;
  }
  try { await fs.mkdir(path, true); }
  catch (error) {
    // Another incoming file may have created a shared parent in the meantime.
    if (await fs.access(path) && (await fs.stat(path)).isDirectory()) return;
    throw error as Error;
  }
}
