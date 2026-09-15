import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'auth_screen.dart';
import '../dashboard/dashboard_screen.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isAuthenticated) {
      return const DashboardScreen();
    } else {
      return const AuthScreen();
    }
  }
}
