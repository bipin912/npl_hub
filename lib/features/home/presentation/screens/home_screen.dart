import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../authentication/data/auth_service.dart';

/// First screen shown to authenticated users.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NPL Community'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthService().signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user?.photoURL != null)
              CircleAvatar(
                radius: 36,
                backgroundImage: NetworkImage(user!.photoURL!),
              )
            else
              const CircleAvatar(
                radius: 36,
                child: Icon(Icons.person, size: 36),
              ),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${user?.displayName ?? 'Cricket fan'}!',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(user?.email ?? ''),
            const SizedBox(height: 24),
            const Text('Your NPL cricket community starts here.'),
          ],
        ),
      ),
    );
  }
}