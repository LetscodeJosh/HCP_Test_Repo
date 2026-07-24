import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';

import 'app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.mode = AppMode.hcp;
  runApp(
    ChangeNotifierProvider<ApiService>(
      create: (_) => ApiService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PIMS HCP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0B192C),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B192C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0B192C),
          secondary: Color(0xFF0066FF),
          surface: Colors.white,
          background: Color(0xFFF4F6F9),
          error: Color(0xFFFF3B30),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF0F172A)),
          bodyMedium: TextStyle(color: Color(0xFF475569)),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
