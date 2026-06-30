import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitor de conectividad (UML: NetworkMonitor).
class NetworkMonitor {
  NetworkMonitor._();
  static final NetworkMonitor instance = NetworkMonitor._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> init() async {
    _isOnline = await checkNow();
    _subscription ??= _connectivity.onConnectivityChanged.listen((_) async {
      final online = await checkNow();
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) return false;

      if (kIsWeb) return true;

      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
