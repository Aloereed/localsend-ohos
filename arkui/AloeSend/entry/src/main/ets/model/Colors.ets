function channel(value: number): number {
  const normalized = value / 255;
  return normalized <= 0.04045 ? normalized / 12.92 : Math.pow((normalized + 0.055) / 1.055, 2.4);
}

function rgb(hex: string): number[] {
  const value = /^#[0-9a-f]{6}$/i.test(hex) ? hex : '#168A75';
  return [parseInt(value.slice(1, 3), 16), parseInt(value.slice(3, 5), 16), parseInt(value.slice(5, 7), 16)];
}

function luminance(values: number[]): number {
  return channel(values[0]) * 0.2126 + channel(values[1]) * 0.7152 + channel(values[2]) * 0.0722;
}

export function contrast(foreground: string, background: string): number {
  const a = luminance(rgb(foreground)); const b = luminance(rgb(background));
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

export function readableColor(accent: string, background: string): string {
  if (contrast(accent, background) >= 4.6) return accent;
  const source = rgb(accent); const target = luminance(rgb(background)) < 0.2 ? 255 : 0;
  for (let step = 1; step <= 100; step++) {
    const factor = step / 100;
    const adjusted = '#' + source.map((value: number) => Math.round(value + (target - value) * factor).toString(16).padStart(2, '0')).join('');
    if (contrast(adjusted, background) >= 4.6) return adjusted;
  }
  return target === 255 ? '#FFFFFF' : '#000000';
}
