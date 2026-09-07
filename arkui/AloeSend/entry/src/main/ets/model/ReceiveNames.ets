import { TransferFile } from './AppStore';
import { safeRelativePath, uniqueName } from '../network/Protocol';
import { util } from '@kit.ArkTS';

export function receiveName(input: string, original: string): string {
  const name = safeRelativePath(input.trim());
  const source = safeRelativePath(original);
  const base = name.slice(name.lastIndexOf('/') + 1);
  const dot = source.lastIndexOf('.');
  const extension = dot > source.lastIndexOf('/') + 1 ? source.slice(dot) : '';
  return safeRelativePath(!base.includes('.') && extension ? name + extension : name);
}

export function batchReceiveNames(files: TransferFile[], mode: string, prefix: string, padZero: boolean, sortFirst: boolean): TransferFile[] {
  if (/[\\/:*?"<>|\x00-\x1f]/.test(prefix) || prefix.length > 100) throw new Error('文件名前缀无效');
  const selected = files.filter((file: TransferFile) => file.selected && !file.preview).slice();
  if (sortFirst) selected.sort((a: TransferFile, b: TransferFile) => a.name.localeCompare(b.name));
  const names: Map<string, string> = new Map();
  const occupied = files.filter((file: TransferFile) => !file.selected || !!file.preview).map((file: TransferFile) => file.name);
  selected.forEach((file: TransferFile, index: number) => {
    const path = safeRelativePath(file.name); const slash = path.lastIndexOf('/'); const dot = path.lastIndexOf('.');
    const extension = dot > slash + 1 ? path.slice(dot) : '';
    const number = padZero ? String(index + 1).padStart(String(selected.length).length, '0') : String(index + 1);
    const stem = mode === 'random' ? util.generateRandomUUID() : `${prefix}${number}`;
    const name = uniqueName(`${path.slice(0, slash + 1)}${stem}${extension}`, occupied);
    occupied.push(name); names.set(file.id, name);
  });
  return files.map((file: TransferFile) => {
    const copy = JSON.parse(JSON.stringify(file)) as TransferFile; copy.name = names.get(file.id) || file.name; return copy;
  });
}
