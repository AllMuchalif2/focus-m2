import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/app_user.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return StreamBuilder<AppUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pomodoro Focus'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Keluar',
                onPressed: () => context.read<AuthService>().logout(),
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'Selamat Datang,',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
