import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const supabaseUrl = 'https://jyuclilkqegictxmunfb.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_1MEOuTvmRbHlDXDFelOtrQ_JPtyRAIN';

  static const dniValidationUrl = String.fromEnvironment(
    'DNI_VALIDATION_URL',
    defaultValue: 'https://dniruc.apisperu.com/api/v1/dni/{dni}',
  );
  static const dniValidationToken = String.fromEnvironment(
    'DNI_VALIDATION_TOKEN',
    defaultValue:
        'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbCI6ImpmY2M5NTAxMjMwOUBnbWFpbC5jb20ifQ.UaK6eecpbt-mVnF9hI-BYSHtl6QQ5hCLU1MNItWe9P8',
  );

  static bool get hasDniValidationApi => dniValidationUrl.isNotEmpty;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
}
