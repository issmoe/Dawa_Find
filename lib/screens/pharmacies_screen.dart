import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/strings.dart';
import '../widgets/pharmacy_logo.dart';
import 'user_dashboard.dart';
import 'pharmacy_dashboard.dart';
import 'user_auth_screen.dart';
import 'pharmacy_auth_screen.dart';

import 'admin_dashboard.dart';

class PharmaciesScreen extends StatelessWidget {
  const PharmaciesScreen({super.key});

  static const _green  = Color(0xFF2EB15B);
  static const _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);

    // ── If logged in → show the right dashboard ──────────
    if (app.isAdmin)    return const AdminDashboard();
    if (app.isUser)     return const UserDashboard();
    if (app.isPharmacy) return const PharmacyDashboard();

    // ── Not logged in → welcome screen ───────────────────
    final s    = AppStrings.of(app.lang);
    final dark = app.isDark;
    final bg       = dark ? const Color(0xFF0D1421) : const Color(0xFFF5F5F5);
    final cardBg   = dark ? const Color(0xFF1A2537) : Colors.white;
    final cardBorder = dark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade200;
    final titleCol = dark ? Colors.white : const Color(0xFF1A1A1A);
    final subCol   = dark ? Colors.white60 : const Color(0xFF666666);
    final chevCol  = dark ? Colors.white38 : Colors.grey.shade400;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(20)),
              child: const PharmacyLogo(size: 80, bgColor: Color(0xFF2EB15B)),
            ),
            const SizedBox(height: 28),
            Text(s.welcomeTitle, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: titleCol)),
            const SizedBox(height: 12),
            Text(s.welcomeSubtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: subCol, height: 1.5)),
            const SizedBox(height: 48),
            _OptionCard(
              iconBg: _green, icon: Icons.person_outline,
              title: s.imUser, subtitle: s.imUserSub,
              cardBg: cardBg, cardBorder: cardBorder,
              titleCol: titleCol, subCol: subCol, chevCol: chevCol,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserAuthScreen())),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              iconBg: _purple, icon: Icons.local_pharmacy_outlined,
              customIcon: const PharmacyLogo(size: 52, bgColor: Color(0xFF7C3AED)),
              title: s.imPharmacy, subtitle: s.imPharmacySub,
              cardBg: cardBg, cardBorder: cardBorder,
              titleCol: titleCol, subCol: subCol, chevCol: chevCol,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PharmacyAuthScreen())),
            ),
            const Spacer(flex: 2),
          ]),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final Color iconBg, cardBg, cardBorder, titleCol, subCol, chevCol;
  final IconData icon;
  final Widget? customIcon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _OptionCard({required this.iconBg, required this.icon, required this.title,
    required this.subtitle, required this.cardBg, required this.cardBorder,
    required this.titleCol, required this.subCol, required this.chevCol,
    required this.onTap, this.customIcon});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Row(children: [
        customIcon ?? Container(width: 52, height: 52,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: Colors.white, size: 26)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: titleCol)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: subCol, height: 1.4)),
        ])),
        Icon(Icons.chevron_right, color: chevCol, size: 22),
      ]),
    ),
  );
}
