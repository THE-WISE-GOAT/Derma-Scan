import 'package:flutter/material.dart';
import '../../modules/app_theme.dart';

class GlassScaffold extends StatelessWidget {
  final Widget child;
  const GlassScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: AppTheme.background(context)),

        Positioned(
          top: -60,
          right: -40,
          child: _bubble(160),
        ),
        Positioned(
          bottom: -80,
          left: -50,
          child: _bubble(220),
        ),

        SafeArea(child: child),
      ],
    );
  }

  Widget _bubble(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha:0.08),
      ),
    );
  }
}
