import 'package:flutter/material.dart';
import 'menu_screen.dart';

void main() {
  runApp(const OXOApp());
}

class OXOApp extends StatelessWidget {
  const OXOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OXO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MenuScreen(),
    );
  }
}
