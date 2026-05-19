import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'l10n/strings.dart';
import 'screens/find_screen.dart';
import 'screens/donate_screen.dart';
import 'screens/requests_screen.dart';
import 'screens/pharmacies_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/reset_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://qyrnbnnhoysnfclxeexc.supabase.co',
    anonKey: 'sb_publishable_jH4TnMLOtI_yAKYOfgAd3Q_lpPLT1EQ',
  );
  runApp(const MedApp());
}

// Restore session on cold start
Future<void> _restoreSession(AppState appState) async {
  try {
    final sb   = Supabase.instance.client;
    final user = sb.auth.currentUser;
    if (user == null) return;

    // Check if user exists in pharmacies table as the most reliable indicator
    final row = await sb.from('pharmacies').select('name').eq('user_id', user.id).maybeSingle();

    if (row != null || user.userMetadata?['role'] == 'pharmacy') {
      appState.login(
        type: UserType.pharmacy,
        name: row?['name'] ?? user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? '',
        email: user.email ?? '',
      );
    } else if (user.userMetadata?['role'] == 'admin') {
      appState.login(
        type: UserType.admin,
        name: user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? '',
        email: user.email ?? '',
      );
    } else {
      appState.login(
        type: UserType.user,
        name: user.userMetadata?['full_name'] ?? user.email?.split('@')[0] ?? '',
        email: user.email ?? '',
      );
    }
  } catch (e) {
    debugPrint('Error restoring session: $e');
  }
}

class MedApp extends StatefulWidget {
  const MedApp({super.key});
  @override
  State<MedApp> createState() => _MedAppState();
}

class _MedAppState extends State<MedApp> {
  final _appState = AppState();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _restoreSession(_appState);
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      } else if (event == AuthChangeEvent.signedIn) {
        // Welcome message is handled by the individual auth screens
      }
    });
  }

  @override
  void dispose() { _appState.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _appState,
      child: ListenableBuilder(
        listenable: _appState,
        builder: (_, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'DawaFind',
          debugShowCheckedModeBanner: false,
          themeMode: _appState.isDark ? ThemeMode.dark : ThemeMode.light,
          theme:     _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: const MainShell(),
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness b) => ThemeData(
    brightness: b,
    scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF5F5F5) : const Color(0xFF121212),
    fontFamily: 'Roboto',
    useMaterial3: true,
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  List<Widget> _buildScreens(bool isAdmin) => [
    const FindScreen(),
    const DonateScreen(),
    const RequestsScreen(),
    const PharmaciesScreen(),
    if (isAdmin) const AdminDashboard(),
  ];

  @override
  Widget build(BuildContext context) {
    final app      = AppStateScope.of(context);
    final s        = AppStrings.of(app.lang);
    final navDark  = app.isDark;
    final navBg    = navDark ? const Color(0xFF162032) : Colors.white;
    final inactive = navDark ? Colors.white38 : Colors.grey;

    // Reset to Account tab if admin logs out while on the Admin Dashboard
    if (_index == 4 && !app.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 3);
      });
    }

    // 4th tab changes based on login state
    final accountIcon       = app.isLoggedIn ? Icons.account_circle          : Icons.account_circle_outlined;
    final accountIconActive = app.isLoggedIn ? Icons.account_circle          : Icons.account_circle_outlined;

    final items = [
      _NavDef(Icons.search,            Icons.search,        s.navFind),
      _NavDef(Icons.favorite_border,   Icons.favorite,      s.navDonate),
      _NavDef(Icons.back_hand_outlined, Icons.back_hand,    s.navRequests),
      app.isAdmin 
          ? const _NavDef(Icons.admin_panel_settings, Icons.admin_panel_settings, 'Admin')
          : _NavDef(accountIcon,             accountIconActive,   'Account'),
    ];

    // Safety: ensure index doesn't exceed current items length if they changed
    final screens    = _buildScreens(app.isAdmin);
    final safeIndex  = _index >= screens.length ? 0 : _index;

    return Directionality(
      textDirection: app.lang == 'AR' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: IndexedStack(index: safeIndex, children: screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: navBg,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: navDark ? 0.4 : 0.08), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: List.generate(items.length, (i) {
                final item   = items[i];
                final active = (_index == i) || (app.isAdmin && i == 3 && _index == 4);
                final color  = active ? const Color(0xFF2EB15B) : inactive;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      int screenIndex = i;
                      if (app.isAdmin && i == 3) screenIndex = 4; // Map 4th tab to AdminDashboard
                      setState(() => _index = screenIndex);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(active ? item.activeIcon : item.icon, size: 22, color: color),
                      const SizedBox(height: 4),
                      Text(item.label, style: TextStyle(fontSize: 11, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  ),
                );
              })),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData icon, activeIcon;
  final String label;
  const _NavDef(this.icon, this.activeIcon, this.label);
}
