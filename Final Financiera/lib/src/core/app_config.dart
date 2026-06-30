import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const supabaseUrl = 'https://jyuclilkqegictxmunfb.supabase.co';
  static const supabaseAnonKey =
      'sb_publishable_1MEOuTvmRbHlDXDFelOtrQ_JPtyRAIN';

  static const teaReferencial = 0.60;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
}
