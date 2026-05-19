import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserType { none, user, pharmacy, admin }

class AppState extends ChangeNotifier {
  bool _isDark = false;
  String _lang = 'EN';
  UserType _userType = UserType.none;
  String _userName = '';
  String _userEmail = '';

  bool get isDark    => _isDark;
  String get lang    => _lang;
  UserType get userType => _userType;
  bool get isLoggedIn  => _userType != UserType.none;
  bool get isUser      => _userType == UserType.user;
  bool get isPharmacy  => _userType == UserType.pharmacy;
  bool get isAdmin     => _userType == UserType.admin;
  String get userName  => _userName;
  String get userEmail => _userEmail;

  AppState() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDark') ?? false;
    _lang   = prefs.getString('lang') ?? 'EN';
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _isDark);
    notifyListeners();
  }

  Future<void> setLang(String l) async {
    _lang = l;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', l);
    notifyListeners();
  }

  void login({ required UserType type, required String name, required String email }) {
    _userType  = type;
    _userName  = name;
    _userEmail = email;
    notifyListeners();
  }

  void updateUserName(String newName) {
    _userName = newName;
    notifyListeners();
  }

  void logout() {
    _userType  = UserType.none;
    _userName  = '';
    _userEmail = '';
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({ super.key, required AppState state, required super.child })
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}
