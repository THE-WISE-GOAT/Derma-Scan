import 'package:flutter/material.dart';
import 'package:skin_care/modules/app_theme.dart';
import 'package:skin_care/views/pages/settings_page.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration:
                    AppTheme.glassCardDecoration(context, radius: 26),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha:0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration:
                  AppTheme.glassCardDecoration(context, radius: 20),
              child: IconButton(
                icon: Icon(Icons.settings_outlined,
                    color: scheme.onSurface),
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder:
                          (context, animation, secondaryAnimation) =>
                              const SettingsPage(),
                      transitionsBuilder: (context, animation,
                          secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
