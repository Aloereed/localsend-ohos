import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:localsend_app/util/ui/visuals.dart';

class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final orbLayers = [
      Positioned(
        top: -120,
        left: -90,
        child: _GlowOrb(
          size: 260,
          color: visuals.accentGlow,
        ),
      ),
      Positioned(
        top: 120,
        right: -110,
        child: _GlowOrb(
          size: 220,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        ),
      ),
      Positioned(
        bottom: -120,
        left: 40,
        child: _GlowOrb(
          size: 280,
          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.08),
        ),
      ),
    ];

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: visuals.backgroundGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (visuals.showBackdropOrbs) ...orbLayers,
            if (!visuals.showBackdropOrbs) ...[
              _BackdropWash(
                gradient: RadialGradient(
                  center: const Alignment(-0.92, -1.0),
                  radius: 1.08,
                  colors: [
                    visuals.backdropPrimaryWash,
                    visuals.backdropPrimaryWash.withOpacity(0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
              _BackdropWash(
                gradient: RadialGradient(
                  center: const Alignment(1.08, 1.05),
                  radius: 1.16,
                  colors: [
                    visuals.backdropDepthWash,
                    visuals.backdropDepthWash.withOpacity(0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _BackdropWash extends StatelessWidget {
  final Gradient gradient;

  const _BackdropWash({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
      ),
    );
  }
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool strong;
  final bool applyBlur;
  final double? blurSigma;
  final Color? color;
  final Gradient? gradient;
  final AlignmentGeometry? alignment;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius,
    this.strong = false,
    this.applyBlur = true,
    this.blurSigma,
    this.color,
    this.gradient,
    this.alignment,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final resolvedRadius = borderRadius ?? visuals.largeRadius;
    final shadowBlur = strong ? 32.0 : 24.0;
    final shadowOffset = const Offset(0, 16);
    final reducedShadowBlur = shadowBlur * 0.5;
    final reducedShadowOffset = Offset(shadowOffset.dx, shadowOffset.dy * 0.6);
    final childWidget = Container(
      width: width,
      height: height,
      alignment: alignment,
      decoration: BoxDecoration(
        color: gradient == null
            ? color ??
                (strong ? visuals.glassSurfaceStrong : visuals.glassSurface)
            : null,
        gradient: gradient,
        borderRadius: resolvedRadius,
        border: Border.all(color: visuals.glassBorder),
        boxShadow: [
          BoxShadow(
            color: visuals.shadowColor,
            blurRadius: visuals.reduceEffects ? reducedShadowBlur : shadowBlur,
            offset: visuals.reduceEffects ? reducedShadowOffset : shadowOffset,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: resolvedRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    final surface = ClipRRect(
      borderRadius: resolvedRadius,
      child: visuals.useGlass && !visuals.reduceEffects && applyBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma ?? visuals.glassBlur,
                sigmaY: blurSigma ?? visuals.glassBlur,
              ),
              child: childWidget,
            )
          : childWidget,
    );

    if (margin == null) {
      return surface;
    }

    return Padding(padding: margin!, child: surface);
  }
}

class GlassSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final bool strong;
  final bool applyBlur;

  const GlassSectionCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.margin,
    this.strong = false,
    this.applyBlur = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final phone = context.isPhoneLayout;
    final compactPhone = context.isCompactPhoneLayout;
    final stackedHeader = context.isNarrowWidth;
    final titleStyle =
        (phone ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.titleLarge)?.copyWith(
          fontWeight: FontWeight.w700,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: visuals.mutedForeground,
          height: phone ? 1.28 : 1.35,
        );

    return GlassSurface(
      strong: strong,
      applyBlur: applyBlur,
      margin: margin,
      padding: EdgeInsets.all(compactPhone ? 14 : phone ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackedHeader)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: subtitleStyle),
                ],
                if (trailing != null) ...[
                  SizedBox(height: phone ? 12 : 14),
                  Align(alignment: Alignment.centerLeft, child: trailing!),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(subtitle!, style: subtitleStyle),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          SizedBox(height: phone ? 14 : 20),
          child,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool emphasized;

  const StatusChip({
    required this.label,
    this.icon,
    this.color,
    this.emphasized = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhoneLayout;
    final compactPhone = context.isCompactPhoneLayout;
    final scheme = Theme.of(context).colorScheme;
    final resolved = color ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compactPhone ? 8 : phone ? 10 : 12,
        vertical: phone ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? resolved.withOpacity(0.18)
            : scheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? resolved.withOpacity(0.24)
              : scheme.outline.withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compactPhone ? 12 : phone ? 13 : 14,
              color: emphasized ? resolved : null,
            ),
            SizedBox(width: compactPhone ? 4 : phone ? 5 : 6),
          ],
          Text(
            label,
            style: (phone
                    ? Theme.of(context).textTheme.labelMedium
                    : Theme.of(context).textTheme.labelLarge)
                ?.copyWith(
                  color: emphasized ? resolved : null,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class ModernActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool highlighted;

  const ModernActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.highlighted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhoneLayout;
    final compactPhone = context.isCompactPhoneLayout;
    final theme = Theme.of(context);
    final visuals = context.visuals;
    final scheme = theme.colorScheme;

    return GlassSurface(
      applyBlur: false,
      strong: highlighted,
      color: highlighted
          ? scheme.primary.withOpacity(0.16)
          : visuals.glassSurfaceStrong,
      borderRadius: visuals.mediumRadius,
      padding: EdgeInsets.all(compactPhone ? 12 : phone ? 14 : 20),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          Container(
            width: compactPhone ? 36 : phone ? 38 : 44,
            height: compactPhone ? 36 : phone ? 38 : 44,
            decoration: BoxDecoration(
              color: highlighted
                  ? scheme.primary.withOpacity(0.18)
                  : scheme.surface.withOpacity(0.5),
              borderRadius: visuals.smallRadius,
            ),
            child: Icon(
              icon,
              size: compactPhone ? 18 : phone ? 19 : 24,
              color: highlighted ? scheme.primary : scheme.onSurface,
            ),
          ),
          SizedBox(width: compactPhone ? 10 : phone ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: (compactPhone
                          ? theme.textTheme.titleSmall
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: phone ? 3 : 4),
                  Text(
                    subtitle!,
                    style: (phone
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                      color: visuals.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: phone ? 10 : 12),
            trailing!,
          ] else
            Icon(Icons.chevron_right, color: visuals.mutedForeground),
        ],
      ),
    );
  }
}

class FloatingTabDock<T> extends StatelessWidget {
  final T currentValue;
  final ValueChanged<T> onChanged;
  final List<FloatingTabDockItem<T>> items;

  const FloatingTabDock({
    required this.currentValue,
    required this.onChanged,
    required this.items,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhoneLayout;
    final compactPhone = context.isCompactPhoneLayout;
    final showLabels = !phone && !context.isCompactWidth && !context.isNarrowWidth;
    final visuals = context.visuals;
    final scheme = Theme.of(context).colorScheme;

    return GlassSurface(
      padding: EdgeInsets.symmetric(
        horizontal: compactPhone ? 4 : phone ? 6 : 10,
        vertical: compactPhone ? 4 : phone ? 6 : 10,
      ),
      borderRadius: BorderRadius.circular(compactPhone ? 22 : phone ? 24 : 28),
      strong: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final selected = item.value == currentValue;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: compactPhone ? 1 : phone ? 2 : 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(compactPhone ? 16 : phone ? 18 : 22),
                onTap: () => onChanged(item.value),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: compactPhone ? 10 : phone ? 12 : 16,
                      vertical: compactPhone ? 8 : phone ? 9 : 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        compactPhone ? 16 : phone ? 18 : 22,
                      ),
                      color: selected
                          ? scheme.primary.withOpacity(0.18)
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: compactPhone ? 17 : phone ? 18 : 20,
                          color: selected ? scheme.primary : visuals.mutedForeground,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: showLabels && selected
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8),
                                    Text(
                                      item.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FloatingTabDockItem<T> {
  final T value;
  final IconData icon;
  final String label;

  const FloatingTabDockItem({
    required this.value,
    required this.icon,
    required this.label,
  });
}

class ModernDialogScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets insetPadding;
  final VoidCallback? onClose;

  const ModernDialogScaffold({
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.maxWidth = 560,
    this.insetPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final actionBottomPadding = actions != null && actions!.isNotEmpty && context.isPhoneLayout
        ? math.max(8.0, MediaQuery.viewPaddingOf(context).bottom).toDouble()
        : 0.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: GlassSurface(
          strong: true,
          blurSigma: visuals.dialogBlur,
          borderRadius: visuals.largeRadius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: visuals.mutedForeground,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              child,
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.only(bottom: actionBottomPadding),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: actions!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ModernPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Widget? trailing;
  final Widget? leading;
  final bool lowProfile;

  const ModernPageHeader({
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.trailing,
    this.leading,
    this.lowProfile = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhoneLayout;
    final compactPhone = context.isCompactPhoneLayout;
    final theme = Theme.of(context);
    final visuals = context.visuals;
    final titleStyle =
        (compactPhone
                ? theme.textTheme.titleLarge
                : phone
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.headlineMedium)
            ?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: compactPhone ? -0.2 : phone ? -0.3 : -0.6,
    );
    final subtitleStyle =
        (compactPhone
                ? theme.textTheme.bodySmall
                : phone
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.bodyLarge)
            ?.copyWith(
      color: visuals.mutedForeground,
      height: phone ? 1.3 : 1.45,
    );

    if (phone && lowProfile) {
      return GlassSurface(
        strong: true,
        padding: EdgeInsets.symmetric(
          horizontal: compactPhone ? 12 : 14,
          vertical: compactPhone ? 10 : 11,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (compactPhone
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.titleLarge)
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: visuals.mutedForeground,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
            if (chips.isNotEmpty) ...[
              SizedBox(height: compactPhone ? 8 : 10),
              Wrap(
                spacing: compactPhone ? 6 : 8,
                runSpacing: compactPhone ? 6 : 8,
                children: chips,
              ),
            ],
          ],
        ),
      );
    }

    if (phone) {
      return GlassSurface(
        strong: true,
        padding: EdgeInsets.all(compactPhone ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null || trailing != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) leading!,
                  const Spacer(),
                  if (trailing != null) trailing!,
                ],
              ),
            if (leading != null || trailing != null)
              SizedBox(height: compactPhone ? 10 : 12),
            Text(title, style: titleStyle),
            SizedBox(height: compactPhone ? 4 : 6),
            Text(subtitle, style: subtitleStyle),
            if (chips.isNotEmpty) ...[
              SizedBox(height: compactPhone ? 10 : 12),
              Wrap(
                spacing: compactPhone ? 6 : 8,
                runSpacing: compactPhone ? 6 : 8,
                children: chips,
              ),
            ],
          ],
        ),
      );
    }

    return GlassSurface(
      strong: true,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                const SizedBox(height: 8),
                Text(subtitle, style: subtitleStyle),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, children: chips),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 16),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}
