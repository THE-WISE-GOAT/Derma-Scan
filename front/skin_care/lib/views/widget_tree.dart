import 'package:flutter/material.dart';
import 'package:skin_care/views/pages/home_page.dart';
import 'package:skin_care/views/pages/chatbot_page.dart';
import 'package:skin_care/views/pages/profile_page.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    ChatbotPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      extendBody: false,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: 70,
        backgroundColor: scheme.surface,        // solid-ish
        indicatorColor: scheme.primary.withValues(alpha:0.18),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.blur_circular_outlined),
            selectedIcon: Icon(Icons.blur_circular),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
