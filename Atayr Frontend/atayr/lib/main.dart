import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/garment_repository.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/root_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AppConfig.init();
  
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  
  // Initialize singleton services
  final authService = AuthService();
  
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(authService)),
        Provider<ApiService>(create: (_) => ApiService()),
        Provider<GarmentRepository>(create: (_) => GarmentRepository()),
      ],
      child: const AtayrApp(),
    ),
  );
}

class AtayrApp extends StatelessWidget {
  const AtayrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atayr',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // RootScreen handles checking the session and routing to Home or Auth
      home: const RootScreen(),
    );
  }
}
