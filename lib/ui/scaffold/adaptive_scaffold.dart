import 'package:flutter/material.dart';
import '../responsive/responsive.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNav;   // petit écran
  final Widget? sideNav;     // grand écran
  final Widget? floatingActionButton;
  const AdaptiveScaffold({
    super.key,
    required this.body,
    this.bottomNav,
    this.sideNav,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final s = useScreenSize(context);

    if (s.isMD || s.isLG || s.isXL) {
      return Scaffold(
        body: Row(
          children: [
            if (sideNav != null) SizedBox(width: 72, child: sideNav!),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: bottomNav,
      floatingActionButton: floatingActionButton,
    );
  }
}
