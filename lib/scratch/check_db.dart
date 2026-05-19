import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final sb = Supabase.instance.client;
  try {
    final res = await sb.from('profiles').select('id').limit(1);
    debugPrint('Profiles table exists and is accessible. Found ${res.length} rows.');
  } catch (e) {
    debugPrint('Profiles table error: $e');
  }
}
