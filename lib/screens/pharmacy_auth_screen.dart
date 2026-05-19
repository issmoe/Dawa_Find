import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/pharmacy_logo.dart';

class PharmacyAuthScreen extends StatefulWidget {
  const PharmacyAuthScreen({super.key});
  @override
  State<PharmacyAuthScreen> createState() => _PharmacyAuthScreenState();
}

class _PharmacyAuthScreenState extends State<PharmacyAuthScreen> {
  bool _isSignUp = false;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _isDonationPoint = false;
  bool _loading = false;
  String? _certFileName;
  XFile? _certFile;

  final _siEmail   = TextEditingController();
  final _siPw      = TextEditingController();
  final _suName    = TextEditingController();
  final _suAddress = TextEditingController();
  final _suCity    = TextEditingController();
  final _suPhone   = TextEditingController();
  final _suHours   = TextEditingController();
  final _suEmail   = TextEditingController();
  final _suPw      = TextEditingController();
  final _suConfirm = TextEditingController();

  @override
  void dispose() {
    _siEmail.dispose(); _siPw.dispose(); _suName.dispose(); _suAddress.dispose();
    _suCity.dispose(); _suPhone.dispose(); _suHours.dispose();
    _suEmail.dispose(); _suPw.dispose(); _suConfirm.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_siEmail.text.trim().isEmpty || _siPw.text.isEmpty) { _showError('Please fill in all fields.'); return; }
    setState(() => _loading = true);
    final result = await AuthService.pharmacySignIn(email: _siEmail.text.trim(), password: _siPw.text);
    setState(() => _loading = false);
    if (!mounted) return;
    if (result.success) {
      AppStateScope.of(context).login(type: UserType.pharmacy, name: result.name ?? '', email: result.email ?? '');
      _showSuccess('Welcome back, ${result.name}!');
      Navigator.pop(context);
    } else { _showError(result.error ?? 'Sign in failed.'); }
  }

  void _forgotPassword() async {
    final email = _siEmail.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email first.');
      return;
    }

    setState(() => _loading = true);
    final res = await AuthService.resetPassword(email);
    setState(() => _loading = false);

    if (res.isError) {
      _showError(res.message!);
    } else {
      _showSuccess('Password reset email sent! Please check your inbox.');
    }
  }

  Future<void> _signUp() async {
    if (_suName.text.trim().isEmpty || _suAddress.text.trim().isEmpty ||
        _suCity.text.trim().isEmpty || _suPhone.text.trim().isEmpty ||
        _suEmail.text.trim().isEmpty || _suPw.text.isEmpty) { _showError('Please fill in all required fields.'); return; }
    if (_suPw.text != _suConfirm.text) { _showError('Passwords do not match.'); return; }
    if (_suPw.text.length < 6) { _showError('Password must be at least 6 characters.'); return; }
    if (_certFile == null) { _showError('Please upload your pharmacy license/certificate.'); return; }
    setState(() => _loading = true);
    Uint8List? certBytes;
    String? certExt;
    if (_certFile != null) {
      try {
        certBytes = await _certFile!.readAsBytes();
        certExt   = _certFile!.name.split('.').last;
      } catch (e) {
        debugPrint('Certificate read error: $e');
        setState(() => _loading = false);
        _showError('Failed to read certificate: $e');
        return;
      }
    }
    final result = await AuthService.pharmacySignUp(
      pharmacyName: _suName.text.trim(), address: _suAddress.text.trim(),
      city: _suCity.text.trim(), phone: _suPhone.text.trim(),
      email: _suEmail.text.trim(), password: _suPw.text,
      openingHours: _suHours.text.trim(), isDonationPoint: _isDonationPoint,
      certificateBytes: certBytes,
      certificateExt: certExt,
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (result.success) {
      // Sign out immediately — pharmacy must wait for admin verification
      await AuthService.signOut();
      if (!mounted) return;
      _showSuccess('Registration submitted! Please wait for the admin to verify your certificate before signing in.');
      Navigator.pop(context);
    } else { _showError(result.error ?? 'Sign up failed.'); }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: Colors.red.shade600,
    behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: const Color(0xFF2EB15B),
    behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));

  @override
  Widget build(BuildContext context) {
    final app  = AppStateScope.of(context);
    final dark = app.isDark;
    final c    = AuthColors.of(dark);
    final headerBg     = dark ? const Color(0xFF1B3D28) : const Color(0xFFE8F5EE);
    final headerBorder = dark ? kGreen.withValues(alpha: 0.3) : kGreen.withValues(alpha: 0.2);
    final headerSub    = dark ? Colors.white70 : const Color(0xFF555555);
    final backCol      = dark ? Colors.white70 : const Color(0xFF444444);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(child: Column(children: [
        Align(alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.chevron_left, color: backCol, size: 20),
            label: Text('Back', style: TextStyle(color: backCol, fontSize: 15)))),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(color: headerBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: headerBorder)),
              child: Column(children: [
                Container(width: 64, height: 64,
                  decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(16)),
                  child: const PharmacyLogo(size: 64, bgColor: Color(0xFF2EB15B))),
                const SizedBox(height: 16),
                Text('Manage Your Pharmacy Stock', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 8),
                Text('Sign in to your pharmacy account to update medication inventory so patients can find what they need.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: headerSub, height: 1.4)),
              ]),
            ),
            const SizedBox(height: 20),
            AuthToggle(isSignUp: _isSignUp, onToggle: (v) => setState(() => _isSignUp = v), c: c),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.card, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.btnOutline),
                boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
              child: _isSignUp ? _signUpForm(c, dark) : _signInForm(c),
            ),
          ]),
        )),
      ])),
    );
  }

  Widget _signInForm(AuthColors c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FieldLabel('Email address', color: c.labelText),
    AdaptiveInput(controller: _siEmail, hint: 'pharmacy@example.com', keyboardType: TextInputType.emailAddress, c: c),
    const SizedBox(height: 16),
    FieldLabel('Password', color: c.labelText),
    AdaptiveInput(controller: _siPw, hint: '', obscure: _obscurePw, onToggleObscure: () => setState(() => _obscurePw = !_obscurePw), c: c),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _forgotPassword,
        child: const Text('Forgot Password?', style: TextStyle(color: kGreen, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    ),
    const SizedBox(height: 12),
    _loading ? const Center(child: CircularProgressIndicator(color: kGreen)) : GreenButton(label: 'Sign In', onPressed: _signIn),
    const SizedBox(height: 16),
    Center(child: GestureDetector(onTap: () => setState(() => _isSignUp = true),
      child: const Text("Don't have an account?", style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.w500)))),
  ]);

  Widget _signUpForm(AuthColors c, bool dark) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FieldLabel('Pharmacy Name *', color: c.labelText),
    AdaptiveInput(controller: _suName, hint: 'Al-Shifa Pharmacy', c: c),
    const SizedBox(height: 16),
    FieldLabel('Address *', color: c.labelText),
    AdaptiveInput(controller: _suAddress, hint: ' Rue frieres kadik', c: c),
    const SizedBox(height: 16),
    FieldLabel('City *', color: c.labelText),
    AdaptiveInput(controller: _suCity, hint: 'Medea', c: c),
    const SizedBox(height: 16),
    FieldLabel('Phone *', color: c.labelText),
    AdaptiveInput(controller: _suPhone, hint: '+213 5xx xxx xxx', keyboardType: TextInputType.phone, c: c),
    const SizedBox(height: 16),
    FieldLabel('Opening Hours', color: c.labelText),
    AdaptiveInput(controller: _suHours, hint: '8:00 - 22:00', c: c),
    const SizedBox(height: 16),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.input, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Donation Collection Point', style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Acts as a hub for medication donations', style: TextStyle(color: c.subText, fontSize: 12, height: 1.4)),
        ])),
        Switch(value: _isDonationPoint, onChanged: (v) => setState(() => _isDonationPoint = v),
          activeThumbColor: kGreen,
          inactiveThumbColor: dark ? Colors.white60 : Colors.grey.shade400,
          inactiveTrackColor: dark ? Colors.white24 : Colors.grey.shade200),
      ]),
    ),
    const SizedBox(height: 20),
    Text('Pharmacy Certificate *', style: TextStyle(color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('Upload a photo of your pharmacy license/certificate', style: TextStyle(color: c.subText, fontSize: 12)),
    const SizedBox(height: 10),
    GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (picked != null) setState(() { _certFile = picked; _certFileName = picked.name; });
      },
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: kGreen, width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.upload_outlined, color: kGreen, size: 18),
          const SizedBox(width: 8),
          Text(_certFileName ?? 'Choose Photo', style: const TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
    const SizedBox(height: 20),
    FieldLabel('Email address', color: c.labelText),
    AdaptiveInput(controller: _suEmail, hint: 'pharmacy@example.com', keyboardType: TextInputType.emailAddress, c: c),
    const SizedBox(height: 16),
    FieldLabel('Password', color: c.labelText),
    AdaptiveInput(controller: _suPw, hint: '', obscure: _obscurePw, onToggleObscure: () => setState(() => _obscurePw = !_obscurePw), c: c),
    const SizedBox(height: 16),
    FieldLabel('Confirm Password', color: c.labelText),
    AdaptiveInput(controller: _suConfirm, hint: '', obscure: _obscureConfirm, onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm), c: c),
    const SizedBox(height: 24),
    _loading ? const Center(child: CircularProgressIndicator(color: kGreen)) : GreenButton(label: 'Create Account', onPressed: _signUp),
    const SizedBox(height: 16),
    Center(child: GestureDetector(onTap: () => setState(() => _isSignUp = false),
      child: const Text('Already have an account?', style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.w500)))),
  ]);
}
