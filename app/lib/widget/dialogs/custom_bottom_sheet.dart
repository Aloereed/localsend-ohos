import 'package:flutter/material.dart';
import 'package:localsend_app/util/ui/visuals.dart';
import 'package:routerino/routerino.dart';

class CustomBottomSheet extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  const CustomBottomSheet({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final dialogColor = Theme.of(context).dialogTheme.backgroundColor;

    return RouterinoBottomSheet(
      title: title,
      description: description,
      backgroundColor: dialogColor ?? visuals.glassSurfaceStrong,
      borderRadius: 28,
      child: child,
    );
  }
}
