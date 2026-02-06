import 'package:flutter/material.dart';

class NavbarWidget extends StatelessWidget {
  final ValueNotifier<int> selectedPageNotifier;

  const NavbarWidget({
    super.key,
    required this.selectedPageNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedPageNotifier,
      builder: (context, selectedPage, _) {
        return NavigationBar(
          selectedIndex: selectedPage,
          onDestinationSelected: (value) {
            selectedPageNotifier.value = value;
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
}
