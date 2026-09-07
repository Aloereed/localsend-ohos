import { BusinessError } from '@kit.BasicServicesKit';

export function storageError(error: Error): string {
  const code = String((error as BusinessError).code);
  if (code === '13900025' || code === 'ENOSPC') return '保存位置空间不足，请释放空间后重新发送';
  if (code === '13900012' || code === 'EACCES' || code === 'EPERM') return '保存位置没有写入权限，请重新授权或更改目录';
  if (code === '13900027' || code === 'EROFS') return '保存位置为只读，请更改目录后重新发送';
  return error.message;
}
