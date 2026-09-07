export class FloatingBarLayout {
  width: number = 0;
  sideMargin: number = 0;
}

export function floatingBarLayout(availableWidth: number): FloatingBarLayout {
  const available = Number.isFinite(availableWidth) ? Math.max(0, availableWidth) : 0;
  const layout = new FloatingBarLayout();
  layout.width = Math.max(0, Math.min(520, available - 32));
  layout.sideMargin = (available - layout.width) / 2;
  return layout;
}
