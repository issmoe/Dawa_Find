import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sb = Supabase.instance.client;

// ── Simple email format validator ────────────────────────
bool _isValidEmail(String email) {
  final re = RegExp(r'^[\w.+\-]+@[a-zA-Z\d\-]+\.[a-zA-Z\d.\-]+$');
  return re.hasMatch(email);
}

// ── In-memory drug list cache ─────────────────────────────
List<Map<String, dynamic>>? _drugCache;

class AuthService {
  static User? get currentUser => _sb.auth.currentUser;
  static bool get isLoggedIn => _sb.auth.currentUser != null;

  static Future<AuthResult> userSignUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (!_isValidEmail(email)) return AuthResult.error('Please enter a valid email address.');
    try {
      final res = await _sb.auth.signUp(
        email: email, password: password,
        data: {'full_name': fullName, 'phone': phone ?? '', 'role': 'user'},
      );
      if (res.user == null) return AuthResult.error('Sign up failed.');
      
      // Create profile in database
      try {
        await _sb.from('profiles').insert({
          'id': res.user!.id,
          'full_name': fullName,
          'phone': phone ?? '',
        });
      } catch (e) {
        debugPrint('Error creating profile: $e');
      }

      return AuthResult.success(name: fullName, email: email, role: 'user');
    } on AuthException catch (e) { return AuthResult.error(e.message); }
    catch (e) { return AuthResult.error('Unexpected error. Please try again.'); }
  }

  static Future<AuthResult> userSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _sb.auth.signInWithPassword(email: email, password: password);
      // Get role from auth metadata if present
      var role = res.user?.userMetadata?['role'];
      // If role is missing, try to read it from the profiles table (admin may be stored only there)
      if (role == null) {
        final profile = await _sb.from('profiles').select('role').eq('id', res.user!.id).maybeSingle();
        if (profile != null && profile['role'] != null) {
          role = profile['role'];
          // Update the auth metadata so the JWT contains the role claim
          await _sb.auth.updateUser(UserAttributes(data: {"role": role}));
        }
      }
      final isPharmacyDb = await _sb.from('pharmacies').select('id').eq('user_id', res.user!.id).maybeSingle() != null;
      if (role == 'pharmacy' || isPharmacyDb) {
        await _sb.auth.signOut();
        return AuthResult.error('This account belongs to a pharmacy. Please use the pharmacy login.');
      }
      final name = res.user?.userMetadata?['full_name'] ?? email.split('@')[0];
      return AuthResult.success(name: name, email: email, role: role == 'admin' ? 'admin' : 'user');
    } on AuthException catch (e) { return AuthResult.error(e.message); }
    catch (e) { return AuthResult.error('Unexpected error. Please try again.'); }
  }

  static Future<AuthResult> pharmacySignUp({
    required String pharmacyName,
    required String address,
    required String city,
    required String phone,
    required String email,
    required String password,
    String? openingHours,
    bool isDonationPoint = false,
    Uint8List? certificateBytes,
    String? certificateExt,
  }) async {
    if (!_isValidEmail(email)) return AuthResult.error('Please enter a valid email address.');
    try {
      final res = await _sb.auth.signUp(
        email: email, password: password,
        data: {'full_name': pharmacyName, 'role': 'pharmacy'},
      );
      if (res.user == null) return AuthResult.error('Sign up failed.');

      String? certUrl;
      if (certificateBytes != null && certificateExt != null) {
        final path = 'certificates/${DateTime.now().millisecondsSinceEpoch}.$certificateExt';
        await _sb.storage.from('certificates').uploadBinary(path, certificateBytes);
        certUrl = _sb.storage.from('certificates').getPublicUrl(path);
      }

      await _sb.from('pharmacies').insert({
        'user_id': res.user!.id, 'name': pharmacyName,
        'address': address, 'city': city, 'phone': phone,
        'opening_hours': openingHours,
        'is_donation_point': isDonationPoint,
        'certificate_url': certUrl,
      });
      return AuthResult.success(name: pharmacyName, email: email, role: 'pharmacy');
    } on AuthException catch (e) { return AuthResult.error(e.message); }
    on PostgrestException catch (e) { return AuthResult.error(e.message); }
    catch (e) { return AuthResult.error('Unexpected error. Please try again.'); }
  }

  static Future<AuthResult> pharmacySignIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _sb.auth.signInWithPassword(email: email, password: password);
      final role = res.user?.userMetadata?['role'];

      final pharmacyRow = await _sb.from('pharmacies')
          .select('name, is_verified').eq('user_id', res.user!.id).maybeSingle();

      if (pharmacyRow == null) {
        await _sb.auth.signOut();
        return AuthResult.error('This account has an incomplete registration or is not a pharmacy. Please contact support.');
      }

      // Block login if not yet verified by admin
      if (pharmacyRow['is_verified'] != true) {
        await _sb.auth.signOut();
        return AuthResult.error('Your account is pending verification. Please wait for the admin to review and approve your certificate.');
      }

      // fetch pharmacy name
      String name = email.split('@')[0];
      name = pharmacyRow['name'] ?? name;
          return AuthResult.success(name: name, email: email, role: 'pharmacy');
    } on AuthException catch (e) { return AuthResult.error(e.message); }
    catch (e) { return AuthResult.error('Unexpected error. Please try again.'); }
  }

  static Future<void> signOut() async => await _sb.auth.signOut();

  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _sb.auth.resetPasswordForEmail(email);
      return AuthResult.success(name: '', email: email, role: '');
    } on AuthException catch (e) {
      return AuthResult.error(e.message);
    } catch (e) {
      return AuthResult.error('Failed to send reset email.');
    }
  }

  // Fetch current user's donations
  static Future<List<Map<String, dynamic>>> myDonations() async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _sb.from('donations')
          .select('*, pharmacies!donations_reviewed_by_fkey(name, phone)')
          .eq('donor_id', user.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching myDonations with join, trying without join: $e');
      try {
        final resFallback = await _sb.from('donations')
            .select('*')
            .eq('donor_id', user.id)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(resFallback);
      } catch (fallbackError) {
        debugPrint('Fallback error myDonations: $fallbackError');
        return [];
      }
    }
  }

  // Fetch current user's requests
  static Future<List<Map<String, dynamic>>> myRequests() async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];
    try {
      final res = await _sb.from('donation_requests')
          .select()
          .eq('requester_id', user.id)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching myRequests: $e');
      return [];
    }
  }

  // Fetch pharmacy stock for logged-in pharmacy
  static Future<List<Map<String, dynamic>>> myPharmacyStock() async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];
    final pharmacy = await _sb.from('pharmacies')
        .select('id').eq('user_id', user.id).maybeSingle();
    if (pharmacy == null) return [];
    final res = await _sb.from('pharmacy_stock')
        .select()
        .eq('pharmacy_id', pharmacy['id'])
        .order('medication_name');
    return List<Map<String, dynamic>>.from(res);
  }

  // Fetch medications from Supabase (cached per session)
  static Future<List<Map<String, dynamic>>> fetchDrugs() async {
    if (_drugCache != null) return _drugCache!;
    try {
      final res = await _sb.from('medications').select('name, generic_name').order('name');
      _drugCache = List<Map<String, dynamic>>.from(res);
      return _drugCache!;
    } catch (e) {
      debugPrint('Error fetching medications: $e');
      return [];
    }
  }

  /// Call this after admin adds/deletes a medication so the cache refreshes.
  static void invalidateDrugCache() => _drugCache = null;

  // Fetch pharmacies that act as relation points
  static Future<List<Map<String, dynamic>>> fetchRelationPoints() async {
    try {
      final res = await _sb.from('pharmacies')
          .select('id, name, address, city')
          .eq('is_donation_point', true)
          .eq('is_verified', true)
          .order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching relation points: $e');
      return [];
    }
  }

  // Update user profile (name and phone)
  static Future<AuthResult> updateUserProfile({required String fullName, required String phone}) async {
    try {
      final user = _sb.auth.currentUser;
      if (user == null) return AuthResult.error('Not logged in.');
      await _sb.auth.updateUser(UserAttributes(data: {'full_name': fullName, 'phone': phone}));
      return AuthResult.success(name: fullName, email: user.email ?? '', role: 'user');
    } catch (e) {
      return AuthResult.error('Failed to update profile.');
    }
  }

  // Update pharmacy profile
  static Future<AuthResult> updatePharmacyProfile({
    required String pharmacyName,
    required String address,
    required String city,
    required String phone,
    String? openingHours,
    bool? isDonationPoint,
  }) async {
    try {
      final user = _sb.auth.currentUser;
      if (user == null) return AuthResult.error('Not logged in.');

      // Build the update map dynamically
      final updates = <String, dynamic>{
        'name':    pharmacyName,
        'address': address,
        'city':    city,
        'phone':   phone,
      };
      if (openingHours != null) updates['opening_hours'] = openingHours;
      if (isDonationPoint != null) updates['is_donation_point'] = isDonationPoint;

      // Update pharmacy table
      await _sb.from('pharmacies').update(updates).eq('user_id', user.id);

      // Update auth metadata
      await _sb.auth.updateUser(UserAttributes(data: {'full_name': pharmacyName}));

      return AuthResult.success(name: pharmacyName, email: user.email ?? '', role: 'pharmacy');
    } catch (e) {
      return AuthResult.error('Failed to update profile.');
    }
  }

  // Fetch all donations directed at this pharmacy (pending & history)
  static Future<List<Map<String, dynamic>>> fetchPharmacyDonations() async {
    try {
      final user = _sb.auth.currentUser;
      if (user == null) return [];

      // Get this pharmacy's ID first
      final pharmacyRow = await _sb
          .from('pharmacies')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (pharmacyRow == null) return [];

      final pharmacyId = pharmacyRow['id'].toString();

      // Step 1: Fetch all donations for this pharmacy
      final res = await _sb
          .from('donations')
          .select('*')
          .eq('pharmacy_id', pharmacyId)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> donations = List<Map<String, dynamic>>.from(res);
      if (donations.isEmpty) return donations;

      // Step 2: Collect unique donor IDs and fetch their profiles
      final donorIds = donations.map((d) => d['donor_id']).whereType<String>().toSet().toList();
      final profilesMap = <String, Map<String, dynamic>>{};

      if (donorIds.isNotEmpty) {
        // Fetch all donor profiles in batch
        for (final donorId in donorIds) {
          try {
            final profile = await _sb
                .from('profiles')
                .select('full_name, phone')
                .eq('id', donorId)
                .maybeSingle();
            if (profile != null) {
              profilesMap[donorId] = Map<String, dynamic>.from(profile);
            }
          } catch (_) {}
        }

        // Count total donations per donor (across ALL pharmacies)
        try {
          final allDonations = await _sb.from('donations').select('donor_id');
          final counts = <String, int>{};
          for (final row in allDonations) {
            final dId = row['donor_id'] as String?;
            if (dId != null) counts[dId] = (counts[dId] ?? 0) + 1;
          }
          for (final id in donorIds) {
            if (profilesMap.containsKey(id)) {
              profilesMap[id]!['donation_count'] = counts[id] ?? 0;
            }
          }
        } catch (e) {
          debugPrint('Could not fetch donor counts: $e');
        }
      }

      // Step 3: Attach profile data to each donation
      for (var d in donations) {
        final donorId = d['donor_id'] as String?;
        if (donorId != null && profilesMap.containsKey(donorId)) {
          d['profiles'] = profilesMap[donorId];
        }
      }

      return donations;
    } catch (e) {
      debugPrint('Error fetching pharmacy donations: $e');
      return [];
    }
  }

  // Accept or reject a donation
  static Future<bool> updateDonationStatus({
    required String donationId,
    required String status,
    String? reviewedByPharmacyId,
  }) async {
    try {
      final update = <String, dynamic>{'status': status};
      if (reviewedByPharmacyId != null) {
        update['reviewed_by'] = reviewedByPharmacyId;
      }
      await _sb.from('donations').update(update).eq('id', donationId);
      return true;
    } catch (e) {
      debugPrint('Error updating donation status: $e');
      return false;
    }
  }

  // Delete user donation
  static Future<bool> deleteDonation(String id) async {
    try {
      await _sb.from('donations').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting donation: $e');
      return false;
    }
  }

  // Update user donation
  static Future<bool> updateDonation({
    required String id,
    required String medicationName,
    required int quantity,
    required String? expiryDate,
    required String? notes,
  }) async {
    try {
      final updates = {
        'medication_name': medicationName,
        'quantity': quantity,
        'expiry_date': expiryDate,
        'notes': notes,
      };
      await _sb.from('donations').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating donation: $e');
      return false;
    }
  }

  // Delete user request
  static Future<bool> deleteRequest(String id) async {
    try {
      await _sb.from('requests').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting request: $e');
      return false;
    }
  }

  // Update user request
  static Future<bool> updateRequest({
    required String id,
    required String medicationName,
    required int quantityNeeded,
  }) async {
    try {
      final updates = {
        'medication_name': medicationName,
        'quantity_needed': quantityNeeded,
      };
      await _sb.from('requests').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating request: $e');
      return false;
    }
  }

  // Get pharmacy ID for current user
  static Future<String?> getMyPharmacyId() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    final row = await _sb.from('pharmacies').select('id').eq('user_id', user.id).maybeSingle();
    return row?['id']?.toString();
  }
}

class AuthResult {
  final bool success;
  final String? error;
  final String? name;
  final String? email;
  final String? role;
  const AuthResult._({required this.success, this.error, this.name, this.email, this.role});
  factory AuthResult.success({required String name, required String email, required String role}) =>
      AuthResult._(success: true, name: name, email: email, role: role);
  factory AuthResult.error(String msg) => AuthResult._(success: false, error: msg);

  bool get isError => !success;
  String? get message => error;
}
