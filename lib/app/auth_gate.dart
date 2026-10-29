import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:npl_community/features/live_chat/presentation/screens/live_chat_screens.dart';

import '../features/authentication/screens/login_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

/// Automatically routes users according to their Firebase sign-in state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Emits the current user and future authentication changes.
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const LiveChatScreen();
        }

        return const LoginScreen();
      },
    );
  }
}