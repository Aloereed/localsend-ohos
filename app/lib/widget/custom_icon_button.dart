/*
 * @Author: 
 * @Date: 2024-12-21 15:37:26
 * @LastEditors: 
 * @LastEditTime: 2025-01-13 11:46:48
 * @Description: file content
 */
import 'package:flutter/material.dart';
import 'package:localsend_app/util/native/platform_check.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final Color? color;
  final Color? hoverColor;

  const CustomIconButton({
    required this.onPressed,
    required this.child,
    this.iconSize,
    this.padding,
    this.alignment,
    this.color,
    this.hoverColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: child,
      iconSize: iconSize ?? 24.0,
      padding: padding ??
          (checkPlatformIsDesktop()
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 16)
              : const EdgeInsets.all(8)),
      alignment: alignment ?? Alignment.center,
      color: color,
      hoverColor: hoverColor,
      constraints: const BoxConstraints(), // Remove default constraints
      splashRadius: null, // IconButton defaults to a circular splash; customize if needed
    );
  }
}
