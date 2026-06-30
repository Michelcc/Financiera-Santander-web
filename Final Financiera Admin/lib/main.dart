import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/network_monitor.dart';
import 'services/sync_service.dart';
import 'src/app.dart';
import 'src/core/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  await NetworkMonitor.instance.init();
  await SyncService.instance.init();

  runApp(const ProviderScope(child: SantanderAsesorApp()));
}
