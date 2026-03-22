import 'package:flutter/material.dart';
import 'package:localsend_app/util/ui/visuals.dart';
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
    final phone = context.isPhoneLayout;
    final compactPhone = context.isCompactPhoneLayout;
    final resolvedPadding = padding == const EdgeInsets.all(15)
        ? EdgeInsets.all(compactPhone ? 10 : phone ? 12 : 15)
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
            SizedBox(width: compactPhone ? 10 : phone ? 12 : 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: compactPhone
                      ? Theme.of(context).textTheme.titleSmall
                      : Theme.of(context).textTheme.titleMedium,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: title,
                  ),
                ),
                SizedBox(height: compactPhone ? 4 : phone ? 6 : 8),
                subTitle,
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: compactPhone ? 6 : phone ? 8 : 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
