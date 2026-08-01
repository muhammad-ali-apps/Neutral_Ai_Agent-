import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'screens/auth/login_screen.dart';

void main() {
  runApp(const NeuroRouteApp());
}

class NeuroRouteApp extends StatefulWidget {
  const NeuroRouteApp({super.key});

  @override
  State<NeuroRouteApp> createState() => _NeuroRouteAppState();
}

class _NeuroRouteAppState extends State<NeuroRouteApp> {
  bool _isDarkMode = true;

  void _toggleTheme() => setState(() => _isDarkMode = !_isDarkMode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroRoute - AI Router',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: LoginScreen(isDarkMode: _isDarkMode, onToggleTheme: _toggleTheme),
    );
  }
}
