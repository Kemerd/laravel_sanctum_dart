import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:laravel_sanctum_dart/laravel_sanctum_dart.dart';

import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/tokens_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SanctumExampleApp());
}

class SanctumExampleApp extends StatelessWidget {
  const SanctumExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp(
            title: 'Laravel Sanctum Dart Example',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            home: _buildHome(authProvider),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/tokens': (context) => const TokensScreen(),
            },
          );
        },
      ),
    );
  }

  Widget _buildHome(AuthProvider authProvider) {
    switch (authProvider.authState) {
      case SanctumAuthState.verifying:
        return const SplashScreen();
      case SanctumAuthState.authenticated:
        return const HomeScreen();
      case SanctumAuthState.unauthenticated:
        return const LoginScreen();
    }
  }
}

/// Extension to add convenience methods to BuildContext
extension SanctumExampleContext on BuildContext {
  /// Shows a snackbar with the given message
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () => ScaffoldMessenger.of(this).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Shows a loading dialog
  void showLoadingDialog() {
    showDialog(
      context: this,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hides the loading dialog
  void hideLoadingDialog() {
    Navigator.of(this).pop();
  }

  /// Gets the auth provider
  AuthProvider get authProvider => Provider.of<AuthProvider>(this, listen: false);

  /// Gets the auth provider with listening
  AuthProvider get watchAuthProvider => Provider.of<AuthProvider>(this);
}