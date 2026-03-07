import 'package:flutter/material.dart';
import 'package:localsend_app/widget/modern/modern_ui.dart';

class CustomListTile extends StatelessWidget {
  final Widget? icon;
  final Widget title;
  final Widget subTitle;
  final Widget? trailing;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const CustomListTile({
    this.icon,
    required this.title,
    required this.subTitle,
    this.trailing,
    this.padding = const EdgeInsets.all(15),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 430;
    final resolvedPadding = padding == const EdgeInsets.all(15)
        ? EdgeInsets.all(compact ? 12 : 15)
        : padding;

    return GlassSurface(
      padding: resolvedPadding,
      applyBlur: false,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            SizedBox(width: compact ? 12 : 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.titleMedium,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: title,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                subTitle,
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: compact ? 8 : 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
