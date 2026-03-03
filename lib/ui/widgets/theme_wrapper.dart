import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ThemeWrapper extends StatelessWidget {
  final Widget child;

  const ThemeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Set status and navigation bar colors
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF0F1013),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0F1013),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return child;
  }
}
