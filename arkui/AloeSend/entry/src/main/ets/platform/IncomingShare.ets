import { Want } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { AppStore } from '../model/AppStore';

export async function receiveSystemShare(want: Want, store: AppStore): Promise<void> {
  if (want.action !== 'ohos.want.action.sendData' && want.action !== 'ohos.want.action.viewData') return;
  try {
    const data = await systemShare.getSharedData(want);
    const records = data.getRecords();
    for (const record of records) {
      if (record.uri) await importSharedFile(record.uri, store);
      else if (record.content) store.addText(record.content);
    }
    if (records.length) { store.incomingShare = true; store.notice = '已加入系统分享的内容，请选择接收设备'; }
  } catch (e) {
    // Standard viewData wants may carry a single URI without SharedData.
    if (want.uri && want.uri.startsWith('file://')) {
      try { await importSharedFile(want.uri, store); store.incomingShare = true; return; }
      catch (error) { store.fail('导入分享文件失败', error as Error); return; }
    }
    store.fail('读取系统分享失败', e as Error);
  }
}

async function importSharedFile(uri: string, store: AppStore): Promise<void> {
  if (!store.context) return;
  const name = new fileUri.FileUri(uri).name.replace(/[\\/:*?"<>|]/g, '_') || 'shared-file';
  const folder = `${store.context.cacheDir}/shared-${util.generateRandomUUID()}`;
  await fs.mkdir(folder, true);
  const path = `${folder}/${name}`;
  const source = await fs.open(uri, fs.OpenMode.READ_ONLY);
  try {
    const destination = await fs.open(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try { await fs.copyFile(source.fd, destination.fd); }
    finally { await fs.close(destination); }
  } finally { await fs.close(source); }
  await store.addUri(fileUri.getUriFromPath(path), name);
}
