// Hand-drawn 24-unit vector icons. No font glyph dependency or bitmap scaling.
@Component
export struct AppIcon {
  @Prop name: string = 'file';
  @Prop iconSize: number = 24;
  @Prop rtl: boolean = false;
  @Prop tint: ResourceColor = $r('sys.color.font_primary');

  path(): string {
    if (this.name === 'receive') return 'M12 3V15 M7 10L12 15L17 10 M4 16V20Q4 21 5 21H19Q20 21 20 20V16';
    if (this.name === 'send') return 'M12 16V4 M7 9L12 4L17 9 M4 16V20Q4 21 5 21H19Q20 21 20 20V16';
    if (this.name === 'message') return 'M6 4H18Q21 4 21 7V15Q21 18 18 18H10L5 21V18Q3 18 3 15V7Q3 4 6 4 M7 9H17 M7 13H14';
    if (this.name === 'settings') return 'M4 6H20 M4 12H20 M4 18H20 M9 3V9 M16 9V15 M9 15V21';
    if (this.name === 'photo') return 'M5 3H19Q21 3 21 5V19Q21 21 19 21H5Q3 21 3 19V5Q3 3 5 3 M3 17L9 11L14 16L17 13L21 17 M16 7H16.01';
    if (this.name === 'folder') return 'M3 7V5Q3 3 5 3H10L13 6H19Q21 6 21 8V19Q21 21 19 21H5Q3 21 3 19V7Z M3 10H21';
    if (this.name === 'text') return 'M3 5H15 M9 5V21 M5 21H13 M16 12H22 M19 12V21';
    if (this.name === 'clipboard') return 'M8 4H5Q3 4 3 6V20Q3 22 5 22H19Q21 22 21 20V6Q21 4 19 4H16 M8 2H16V7H8Z M7 12H17 M7 16H14';
    if (this.name === 'mobile') return 'M8 2H16Q19 2 19 5V19Q19 22 16 22H8Q5 22 5 19V5Q5 2 8 2Z M10 5H14 M11 19H13';
    if (this.name === 'desktop') return 'M4 3H20Q22 3 22 5V15Q22 17 20 17H4Q2 17 2 15V5Q2 3 4 3Z M12 17V21 M7 21H17';
    if (this.name === 'history') return 'M3 11A9 9 0 1 1 5 18 M3 4V11H10 M12 7V12L16 14';
    if (this.name === 'shield') return 'M12 2L21 6V12Q20 19 12 22Q4 19 3 12V6Z M8 12L11 15L17 9';
    if (this.name === 'link') return 'M9 15L15 9 M8 17L6 19A4 4 0 0 1 1 14L6 9A4 4 0 0 1 12 9 M16 7L18 5A4 4 0 0 1 23 10L18 15A4 4 0 0 1 12 15';
    if (this.name === 'search') return 'M17 10A7 7 0 1 1 3 10A7 7 0 1 1 17 10 M15 15L22 22';
    if (this.name === 'check') return 'M5 12L10 17L20 6';
    if (this.name === 'back') return this.rtl ? 'M9 5L16 12L9 19' : 'M15 5L8 12L15 19';
    if (this.name === 'forward') return this.rtl ? 'M15 5L8 12L15 19' : 'M9 5L16 12L9 19';
    if (this.name === 'close') return 'M6 6L18 18 M18 6L6 18';
    if (this.name === 'refresh') return 'M20 4V10H14 M4 20V14H10 M20 10A8 8 0 0 0 5 6 M4 14A8 8 0 0 0 19 18';
    if (this.name === 'star') return 'M12 2L15 8L22 9L17 14L18 21L12 18L6 21L7 14L2 9L9 8Z';
    return 'M6 2H14L21 9V20Q21 22 19 22H6Q4 22 4 20V4Q4 2 6 2Z M14 2V9H21 M8 14H17 M8 18H14';
  }

  build() {
    // Path commands use physical pixels. An explicit px viewport maps the
    // 24-unit drawing to the component's vp size on every display density.
    Shape() {
      Path().commands(this.path()).fill(Color.Transparent).stroke(this.tint).strokeWidth('1.7px')
        .strokeLineCap(LineCapStyle.Round).strokeLineJoin(LineJoinStyle.Round)
    }.viewPort({ x: '0px', y: '0px', width: '24px', height: '24px' })
      .width(this.iconSize).height(this.iconSize).accessibilityLevel('no')
  }
}
