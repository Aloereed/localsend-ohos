// Match Flutter's HarmonyOS folder opener: public documents belong to file://docs.
// Application-private paths cannot be browsed by the system file manager.
export function publicParentUri(path: string): string {
  if (path.startsWith('file://docs/')) {
    const last = path.lastIndexOf('/');
    return last > 'file://docs'.length ? path.substring(0, last) : '';
  }
  if (!path.startsWith('/storage/Users/')) return '';
  const parent = path.substring(0, path.lastIndexOf('/'));
  return 'file://docs' + parent.split('/').map((part: string) => encodeURIComponent(part)).join('/');
}
