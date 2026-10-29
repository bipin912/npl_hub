import 'package:flutter/material.dart';


import 'app_theme.dart';
import 'auth_gate.dart';

/// Root widget: application-wide configuration belongs here.
class NplCommunityApp extends StatelessWidget {
  const NplCommunityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NPL Community',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
        home: const AuthGate(),
    );
  }
}
