import 'package:flutter/material.dart';

import '../widgets/brand_splash_wrapper.dart';
import '../views/auth_gate.dart';
import 'theme/app_theme.dart';

class SantanderClientesApp extends StatelessWidget {
  const SantanderClientesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Santander Consumer - Clientes',
      theme: AppTheme.light(),
      home: const BrandSplashWrapper(child: AuthGate()),
    );
  }
}
