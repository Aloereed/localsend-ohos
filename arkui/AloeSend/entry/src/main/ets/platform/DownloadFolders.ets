import { fileIo as fs } from '@kit.CoreFileKit';

export interface DownloadFile { path: string; name: string; }

export function insideDownloadFolder(root: string, path: string): boolean {
  return (path === root || path.startsWith(`${root}/`)) && !path.includes('\\') &&
    !path.split('/').some((part: string) => part === '.' || part === '..');
}

export async function checkDownloadFolder(root: string, path: string): Promise<void> {
  if (!insideDownloadFolder(root, path)) throw new Error('请选择应用下载目录内的文件夹');
  let current = root;
  const rootStat = await fs.lstat(root);
  if (!rootStat.isDirectory() || rootStat.isSymbolicLink()) throw new Error('下载目录暂不可用');
  for (const part of path.slice(root.length).split('/').filter((value: string) => !!value)) {
    current += `/${part}`;
    const stat = await fs.lstat(current);
    if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error('文件夹已移动或不可访问');
  }
}

export async function downloadSubfolders(root: string, path: string): Promise<string[]> {
  await checkDownloadFolder(root, path);
  const folders: string[] = [];
  for (const name of await fs.listFile(path)) {
    if (name.startsWith('.') || name.includes('/') || name.includes('\\')) continue;
    try { const stat = await fs.lstat(`${path}/${name}`); if (stat.isDirectory() && !stat.isSymbolicLink()) folders.push(name); }
    catch (_) { /* A removed child must not discard all remaining choices. */ }
  }
  return folders.sort();
}

async function collect(path: string, prefix: string, files: DownloadFile[], checkpoint: () => void): Promise<void> {
  checkpoint();
  for (const name of await fs.listFile(path)) {
    checkpoint();
    if (name === '.' || name === '..' || name.includes('/') || name.includes('\\')) continue;
    const child = `${path}/${name}`; const stat = await fs.lstat(child);
    if (stat.isSymbolicLink()) continue;
    if (stat.isDirectory()) await collect(child, `${prefix}/${name}`, files, checkpoint);
    else if (stat.isFile()) files.push({ path: child, name: `${prefix}/${name}` });
  }
}

export async function downloadFolderFiles(root: string, path: string, checkpoint: () => void = () => {}): Promise<DownloadFile[]> {
  await checkDownloadFolder(root, path);
  const files: DownloadFile[] = [];
  await collect(path, path.slice(path.lastIndexOf('/') + 1), files, checkpoint);
  return files;
}
