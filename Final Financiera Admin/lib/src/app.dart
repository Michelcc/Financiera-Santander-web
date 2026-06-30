import 'package:flutter/material.dart';

import '../widgets/brand_splash_wrapper.dart';
import '../views/app_shell.dart';
import 'theme/app_theme.dart';

class SantanderAsesorApp extends StatelessWidget {
  const SantanderAsesorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Santander Consumer - Fuerza de Ventas',
      theme: AppTheme.light(),
      home: const BrandSplashWrapper(child: AuthGate()),
    );
  }
}
