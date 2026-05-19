import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class UserAuthScreen extends StatefulWidget {
  const UserAuthScreen({super.key});
  @override
  State<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<UserAuthScreen> {
  bool _isSignUp = false;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  final _siEmail   = TextEditingController();
  final _siPw      = TextEditingController();
  final _suName    = TextEditingController();
  final _suEmail   = TextEditingController();
  final _suPhone   = TextEditingController();
  final _suPw      = TextEditingController();
  final _suConfirm = TextEditingController();

  @override
  void dispose() {
    _siEmail.dispose(); _siPw.dispose(); _suName.dispose();
    _suEmail.dispose(); _suPhone.dispose(); _suPw.dispose(); _suConfirm.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_siEmail.text.trim().isEmpty || _siPw.text.isEmpty) { _showError('Please fill in all fields.'); return; }
    setState(() => _loading = true);
    final result = await AuthService.userSignIn(email: _siEmail.text.trim(), password: _siPw.text);
    setState(() => _loading = false);
    if (!mounted) return;
    if (result.success) {
      final type = result.role == 'admin' ? UserType.admin : UserType.user;
      AppStateScope.of(context).login(type: type, name: result.name ?? '', email: result.email ?? '');
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
    final name  = _suName.text.trim();
    final email = _suEmail.text.trim();
    final pw    = _suPw.text;
    if (name.isEmpty || email.isEmpty || pw.isEmpty) { _showError('Please fill in all required fields.'); return; }
    if (_suPw.text != _suConfirm.text) { _showError('Passwords do not match.'); return; }
    if (pw.length < 6) { _showError('Password must be at least 6 characters.'); return; }
    setState(() => _loading = true);
    final result = await AuthService.userSignUp(
      fullName: _suName.text.trim(), email: _suEmail.text.trim(),
      password: _suPw.text, phone: _suPhone.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (result.success) {
      AppStateScope.of(context).login(type: UserType.user, name: result.name ?? '', email: result.email ?? '');
      _showSuccess('Account created! Welcome, ${result.name}!');
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
                  child: const Icon(Icons.person, color: Colors.white, size: 32)),
                const SizedBox(height: 16),
                Text('User Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 8),
                Text('Sign in to manage your donations and requests',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: headerSub, height: 1.4)),
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
              child: _isSignUp ? _signUpForm(c) : _signInForm(c),
            ),
          ]),
        )),
      ])),
    );
  }

  Widget _signInForm(AuthColors c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FieldLabel('Email address', color: c.labelText),
    AdaptiveInput(controller: _siEmail, hint: 'you@example.com', keyboardType: TextInputType.emailAddress, c: c),
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

  Widget _signUpForm(AuthColors c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    FieldLabel('Full Name', color: c.labelText),
    AdaptiveInput(controller: _suName, hint: 'Mohamed', c: c),
    const SizedBox(height: 16),
    FieldLabel('Email', color: c.labelText),
    AdaptiveInput(controller: _suEmail, hint: 'you@example.com', keyboardType: TextInputType.emailAddress, c: c),
    const SizedBox(height: 16),
    FieldLabel('Phone (optional)', color: c.labelText),
    AdaptiveInput(controller: _suPhone, hint: '+213 6xx xxx xxx', keyboardType: TextInputType.phone, c: c),
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
      child: const Text('Already have an account? Sign in', style: TextStyle(color: kGreen, fontSize: 14, fontWeight: FontWeight.w500)))),
  ]);
}
