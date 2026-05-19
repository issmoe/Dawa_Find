import 'package:flutter/material.dart';
import '../l10n/strings.dart';

// ── Dark palette (used when isDark = true) ────────────────
const Color kDarkInput  = Color(0xFF1E2E45);
const Color kDarkBorder = Color(0xFF2A3E5C);
const Color kDarkCard   = Color(0xFF1A2537);
const Color kDarkBg     = Color(0xFF0D1421);

// ── Light palette ─────────────────────────────────────────
const Color kLightInput  = Color(0xFFF5F5F5);
const Color kLightBorder = Color(0xFFDDDDDD);
const Color kLightCard   = Color(0xFFFFFFFF);
const Color kLightBg     = Color(0xFFF5F5F5);

const Color kGreen = Color(0xFF2EB15B);

// ── Auth color bundle ─────────────────────────────────────
class AuthColors {
  final Color bg, card, input, border, text, subText, labelText, btnOutline, toggleBg, inactiveTabText;
  final bool dark;

  const AuthColors._({
    required this.bg, required this.card, required this.input,
    required this.border, required this.text, required this.subText,
    required this.labelText, required this.btnOutline,
    required this.toggleBg, required this.inactiveTabText,
    required this.dark,
  });

  factory AuthColors.of(bool isDark) => isDark
    ? const AuthColors._(
        bg: kDarkBg, card: kDarkCard, input: kDarkInput,
        border: kDarkBorder, text: Colors.white, subText: Colors.white70,
        labelText: Colors.white70, btnOutline: Colors.white12,
        toggleBg: kDarkCard, inactiveTabText: Colors.white54,
        dark: true,
      )
    : AuthColors._(
        bg: kLightBg, card: kLightCard, input: kLightInput,
        border: kLightBorder,
        text: const Color(0xFF1A1A1A), subText: const Color(0xFF555555),
        labelText: const Color(0xFF444444), btnOutline: Colors.grey.shade200,
        toggleBg: const Color(0xFFEEEEEE), inactiveTabText: Colors.black45,
        dark: false,
      );
}

// ── Sign In / Sign Up toggle ──────────────────────────────
class AuthToggle extends StatelessWidget {
  final bool isSignUp;
  final void Function(bool) onToggle;
  final AuthColors c;
  const AuthToggle({super.key, required this.isSignUp, required this.onToggle, required this.c});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: c.toggleBg, borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.all(4),
    child: Row(children: [
      _Tab(label: 'Sign In', active: !isSignUp, onTap: () => onToggle(false), inactiveColor: c.inactiveTabText),
      _Tab(label: 'Sign Up', active: isSignUp,  onTap: () => onToggle(true),  inactiveColor: c.inactiveTabText),
    ]),
  );
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final Color inactiveColor;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap, required this.inactiveColor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: active ? kGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: active ? Colors.white : inactiveColor,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          fontSize: 14,
        )),
      ),
    ),
  );
}

// ── Field label ───────────────────────────────────────────
class FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  const FieldLabel(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
  );
}

// ── Adaptive input field ──────────────────────────────────
class AdaptiveInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final AuthColors c;

  const AdaptiveInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.c,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    style: TextStyle(color: c.text, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.subText.withValues(alpha: 0.5), fontSize: 14),
      filled: true, fillColor: c.input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5)),
      suffixIcon: onToggleObscure != null
          ? IconButton(
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: c.subText.withValues(alpha: 0.5), size: 18),
              onPressed: onToggleObscure,
            )
          : null,
    ),
  );
}

// ── Green button ──────────────────────────────────────────
class GreenButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const GreenButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ),
  );
}

// ── Lock / sign-in required ───────────────────────────────
class SignInRequired extends StatelessWidget {
  final bool dark;
  final AppStrings s;
  const SignInRequired({super.key, required this.dark, required this.s});

  @override
  Widget build(BuildContext context) {
    final iconColor = dark ? Colors.white38 : const Color(0xFFBBBBBB);
    final titleCol  = dark ? Colors.white   : const Color(0xFF1A1A1A);
    final msgCol    = dark ? Colors.white54 : const Color(0xFF888888);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 60, color: iconColor),
            const SizedBox(height: 20),
            Text(s.signInRequired, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: titleCol)),
            const SizedBox(height: 12),
            Text(s.signInMsg, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: msgCol, height: 1.55)),
          ],
        ),
      ),
    );
  }
}
