import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://qyrnbnnhoysnfclxeexc.supabase.co',
    'sb_publishable_jH4TnMLOtI_yAKYOfgAd3Q_lpPLT1EQ',
  );

  try {
    debugPrint('Trying join with explicit foreign key (reviewed_by)...');
    final res = await client
        .from('donations')
        .select('*, pharmacies!reviewed_by(name, phone)')
        .limit(2);
    debugPrint('Success with reviewed_by: $res');
  } catch (e) {
    debugPrint('Error with reviewed_by: $e');
  }

  try {
    debugPrint('\nTrying join with explicit foreign key (donations_reviewed_by_fkey)...');
    final res = await client
        .from('donations')
        .select('*, pharmacies!donations_reviewed_by_fkey(name, phone)')
        .limit(2);
    debugPrint('Success with donations_reviewed_by_fkey: $res');
  } catch (e) {
    debugPrint('Error with donations_reviewed_by_fkey: $e');
  }

  try {
    debugPrint('\nFetching pharmacies to see columns...');
    final res = await client.from('pharmacies').select('*').limit(1);
    debugPrint('$res');
  } catch (e) {
    debugPrint('Error fetching pharmacies: $e');
  }
}
