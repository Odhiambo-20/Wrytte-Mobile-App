import 'package:flutter/material.dart';

class WrytteTheme {
  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: Colors.black,
    brightness: Brightness.dark,
    fontFamily: 'Roboto', // Roboto as global font
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
  );
}
