import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../../core/widgets/neo_input.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_card.dart';
import '../../core/theme/atayr_colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PLEASE ENTER EMAIL AND PASSWORD')),
      );
      return;
    }

    bool success;
    if (_isLogin) {
      success = await authProvider.signIn(email, password);
    } else {
      success = await authProvider.signUp(email, password);
    }

    if (!mounted) return;
    
    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!.toUpperCase())),
      );
    }
  }

  void _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PLEASE ENTER YOUR EMAIL FIRST')),
      );
      return;
    }
    
    final authProvider = context.read<AuthProvider>();
    await authProvider.resetPassword(email);
    
    if (!mounted) return;
    
    if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!.toUpperCase())),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PASSWORD RESET EMAIL SENT!')),
      );
    }
  }

  void _googleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.signInWithGoogle();
    
    if (!mounted) return;
    
    if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.errorMessage!.toUpperCase())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AtayrColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ATAYR',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    letterSpacing: -1,
                    fontSize: 48,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin ? 'WELCOME BACK.' : 'CREATE ACCOUNT.',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                NeoCard(
                  child: Column(
                    children: [
                      NeoInput(
                        label: 'EMAIL',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      NeoInput(
                        label: 'PASSWORD',
                        controller: _passwordController,
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: NeoButton(
                          label: _isLogin ? 'LOGIN' : 'SIGN UP',
                          onPressed: _submit,
                          isLoading: isLoading,
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin ? 'NEED AN ACCOUNT? SIGN UP' : 'ALREADY HAVE AN ACCOUNT? LOGIN',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AtayrColors.ink),
                  ),
                ),
                if (_isLogin)
                  TextButton(
                    onPressed: _resetPassword,
                    child: const Text(
                      'FORGOT PASSWORD?',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AtayrColors.ink),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AtayrColors.ink, thickness: 2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const Expanded(child: Divider(color: AtayrColors.ink, thickness: 2)),
                  ],
                ),
                const SizedBox(height: 24),
                NeoButton(
                  label: 'CONTINUE WITH GOOGLE',
                  onPressed: _googleSignIn,
                  isPrimary: false,
                  icon: Icons.g_mobiledata,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
