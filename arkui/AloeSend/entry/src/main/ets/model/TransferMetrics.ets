import { TransferView, TransferFile } from './AppStore';

export function formatRemaining(seconds: number, dayLabel: string = 'd'): string {
  const total = Number.isFinite(seconds) ? Math.max(0, Math.ceil(seconds)) : 0;
  const minutes = Math.floor(total / 60); const hours = Math.floor(minutes / 60);
  const suffix = String(total % 60).padStart(2, '0');
  if (hours >= 24) return `${Math.floor(hours / 24)}${dayLabel} ${hours % 24}:${String(minutes % 60).padStart(2, '0')}:${suffix}`;
  return hours > 0 ? `${hours}:${String(minutes % 60).padStart(2, '0')}:${suffix}` : `${minutes}:${suffix}`;
}

export function transferTotal(transfer: TransferView): number {
  return transfer.files.reduce((sum: number, file: TransferFile) =>
    sum + (file.selected && file.status !== 'skipped' ? file.size : 0), 0);
}

export function transferredBytes(transfer: TransferView): number {
  return transfer.files.reduce((sum: number, file: TransferFile) =>
    sum + (file.selected && file.status !== 'skipped' ? file.transferred : 0), 0);
}

export function remainingSeconds(transfer: TransferView, speed: number): number {
  if (transfer.status !== 'transferring' || speed <= 0) return 0;
  return Math.max(0, Math.ceil((transferTotal(transfer) - transferredBytes(transfer)) / speed));
}

export function transferSpeed(transfer: TransferView, now: number = Date.now()): number {
  const bytes = transfer.activeBytes >= 0 ? transfer.activeBytes : transferredBytes(transfer);
  const seconds = Math.max(1, ((transfer.finished || now) - (transfer.activeStarted || transfer.started)) / 1000);
  return Math.max(0, bytes / seconds);
}

export function filePercent(file: TransferFile): number {
  if (file.status === 'complete') return 100;
  if (file.size <= 0) return 0;
  return Math.max(0, Math.min(100, file.transferred * 100 / file.size));
}
