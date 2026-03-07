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
    return DecoratedBox(
      decoration: BoxDecoration(gradient: visuals.backgroundGradient),
      child: Stack(
        children: [
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
          child,
        ],
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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final resolvedRadius = borderRadius ?? visuals.largeRadius;
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
            blurRadius: strong ? 32 : 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: resolvedRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    final surface = ClipRRect(
      borderRadius: resolvedRadius,
      child: visuals.useGlass && applyBlur
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
    final compact = context.isNarrowWidth;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: visuals.mutedForeground,
          height: 1.35,
        );

    return GlassSurface(
      strong: strong,
      applyBlur: applyBlur,
      margin: margin,
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: subtitleStyle),
                ],
                if (trailing != null) ...[
                  const SizedBox(height: 14),
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
          SizedBox(height: compact ? 16 : 20),
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
    final compact = context.isCompactWidth;
    final scheme = Theme.of(context).colorScheme;
    final resolved = color ?? scheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : 8,
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
            Icon(icon, size: compact ? 13 : 14, color: emphasized ? resolved : null),
            SizedBox(width: compact ? 5 : 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
  final Widget? trailing;
  final bool highlighted;

  const ModernActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.highlighted = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final compact = context.isNarrowWidth;
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
      padding: EdgeInsets.all(compact ? 14 : 20),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 44,
            height: compact ? 40 : 44,
            decoration: BoxDecoration(
              color: highlighted
                  ? scheme.primary.withOpacity(0.18)
                  : scheme.surface.withOpacity(0.5),
              borderRadius: visuals.smallRadius,
            ),
            child: Icon(
              icon,
              size: compact ? 20 : 24,
              color: highlighted ? scheme.primary : scheme.onSurface,
            ),
          ),
          SizedBox(width: compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: visuals.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
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
    final compact = context.isCompactWidth;
    final showLabels = !compact && !context.isNarrowWidth;
    final visuals = context.visuals;
    final scheme = Theme.of(context).colorScheme;

    return GlassSurface(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 6 : 10,
      ),
      borderRadius: BorderRadius.circular(compact ? 24 : 28),
      strong: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final selected = item.value == currentValue;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(compact ? 18 : 22),
                onTap: () => onChanged(item.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: compact ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 18 : 22),
                    color: selected
                        ? scheme.primary.withOpacity(0.18)
                        : Colors.transparent,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: compact ? 18 : 20,
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
    final compact = context.isNarrowWidth;
    final theme = Theme.of(context);
    final visuals = context.visuals;
    final titleStyle = (compact ? theme.textTheme.headlineSmall : theme.textTheme.headlineMedium)?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: compact ? -0.3 : -0.6,
    );
    final subtitleStyle = (compact ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)?.copyWith(
      color: visuals.mutedForeground,
      height: 1.45,
    );

    if (compact && lowProfile) {
      return GlassSurface(
        strong: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
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
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ],
        ),
      );
    }

    if (compact) {
      return GlassSurface(
        strong: true,
        padding: const EdgeInsets.all(18),
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
            if (leading != null || trailing != null) const SizedBox(height: 16),
            Text(title, style: titleStyle),
            const SizedBox(height: 6),
            Text(subtitle, style: subtitleStyle),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
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

  const _GlowOrb({required this.size, required this.color});

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
