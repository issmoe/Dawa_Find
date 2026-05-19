import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../widgets/pharmacy_logo.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  int _accountsSubTab = 0; // 0 = Pharmacies, 1 = Users

  int _totalUsers = 0;
  int _totalPharmacies = 0;
  int _totalDonations = 0;
  int _totalRequests = 0;

  List<Map<String, dynamic>> _pharmacies = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _requests = [];

  final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load Stats
      final pharmsRes = await _sb.from('pharmacies').select('id').count(CountOption.exact);
      final donsRes = await _sb.from('donations').select('id').count(CountOption.exact);
      final reqsRes = await _sb.from('donation_requests').select('id').count(CountOption.exact);
      
      _totalPharmacies = pharmsRes.count;
      _totalDonations = donsRes.count;
      _totalRequests = reqsRes.count;
      // We will skip users count if there's no public users table
      
      // Load Pharmacies
      final pList = await _sb.from('pharmacies').select('*').order('created_at', ascending: false);
      _pharmacies = List<Map<String, dynamic>>.from(pList);

      // Load Users
      try {
        final uList = await _sb.from('profiles').select('*').order('created_at', ascending: false);
        final pharmacyUserIds = _pharmacies.map((p) => p['user_id']).toSet();
        final allUsers = List<Map<String, dynamic>>.from(uList);
        _users = allUsers.where((u) => !pharmacyUserIds.contains(u['id']) && u['role'] != 'admin' && u['role'] != 'pharmacy').toList();
        _totalUsers = _users.length;
      } catch (e) {
        debugPrint('Error loading profiles: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load user profiles: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }

      // Load Medications
      final mList = await _sb.from('medications').select('*').order('name');
      _medications = List<Map<String, dynamic>>.from(mList);

      // Load Donations (plain query — names resolved from _users list)
      final dList = await _sb.from('donations').select('*').order('created_at', ascending: false);
      _donations = List<Map<String, dynamic>>.from(dList);

      // Load Requests (plain query — names resolved from _users list)
      final rList = await _sb.from('donation_requests').select('*').order('created_at', ascending: false);
      _requests = List<Map<String, dynamic>>.from(rList);
      
    } catch (e) {
      debugPrint('Admin load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }



  Future<void> _togglePharmacyApproval(String id, bool currentStatus) async {
    try {
      await _sb.from('pharmacies').update({'is_verified': !currentStatus}).eq('id', id);
      _loadData();
    } catch (e) {
      debugPrint('Error toggling approval: $e');
    }
  }

  Future<void> _toggleCollectionPoint(String id, bool currentStatus) async {
    try {
      await _sb.from('pharmacies').update({'is_donation_point': !currentStatus}).eq('id', id);
      _loadData();
    } catch (e) {
      debugPrint('Error toggling donation point: $e');
    }
  }



  Future<void> _deleteMedication(String id) async {
    final dark = AppStateScope.of(context).isDark;
    final cardBg = dark ? const Color(0xFF1E1E2E) : Colors.white;
    final textPrimary = dark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecond = dark ? Colors.white70 : const Color(0xFF555555);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Medication?', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Text('This action cannot be undone and will remove it from the dictionary.', style: TextStyle(color: textSecond)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: textSecond))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _sb.from('medications').delete().eq('id', id);
      AuthService.invalidateDrugCache();
      _loadData();
    } catch (e) {
      debugPrint('Error deleting medication: $e');
    }
  }

  void _showAddDrugSheet(Color cardBg, Color textPrimary, Color textSecond) {
    final nameCtrl = TextEditingController();
    final genericCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(innerContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Medication', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Brand Name *',
                  labelStyle: TextStyle(color: textSecond),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: genericCtrl,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Generic Name (optional)',
                  labelStyle: TextStyle(color: textSecond),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: submitting ? null : () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setSheetState(() => submitting = true);
                    try {
                      await _sb.from('medications').insert({
                        'name': nameCtrl.text.trim(),
                        'generic_name': genericCtrl.text.trim().isEmpty ? null : genericCtrl.text.trim(),
                      });
                      AuthService.invalidateDrugCache();
                      if (innerContext.mounted) Navigator.pop(innerContext);
                      _loadData();
                    } catch (e) {
                      setSheetState(() => submitting = false);
                      debugPrint('Error adding drug: $e');
                    }
                  },
                  child: submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Medication'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _signOut() async {
    final app = AppStateScope.of(context);
    final dark = app.isDark;
    final cardBg = dark ? const Color(0xFF1E1E2E) : Colors.white;
    final textPrimary = dark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecond = dark ? Colors.white70 : const Color(0xFF555555);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out from the Admin Dashboard?', style: TextStyle(color: textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textSecond)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.signOut();
      if (mounted) AppStateScope.of(context).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final dark = app.isDark;
    final textPrimary = dark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecond = dark ? Colors.white60 : const Color(0xFF888888);
    final scaffoldBg = dark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Admin Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
                      IconButton(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tab,
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: textSecond,
                    indicatorColor: Colors.blueAccent,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Accounts'),
                      Tab(text: 'Donations'),
                      Tab(text: 'Requests'),
                      Tab(text: 'Dictionary'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      _buildOverview(textPrimary, textSecond, dark),
                      _buildAllAccounts(textPrimary, textSecond, dark),
                      _buildDonations(textPrimary, textSecond, dark),
                      _buildRequests(textPrimary, textSecond, dark),
                      _buildDrugs(textPrimary, textSecond, dark),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(Color textPrimary, Color textSecond, bool dark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _statCard('Total Pharmacies', _totalPharmacies.toString(), Icons.local_pharmacy, Colors.green, dark,
            customIcon: const PharmacyLogo(size: 28, bgColor: Color(0xFF2EB15B)),
            onTap: () => _tab.animateTo(1)),
        const SizedBox(height: 16),
        _statCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue, dark,
            onTap: () => _tab.animateTo(1)),
        const SizedBox(height: 16),
        _statCard('Total Donations', _totalDonations.toString(), Icons.favorite, Colors.purple, dark,
            onTap: () => _tab.animateTo(2)),
        const SizedBox(height: 16),
        _statCard('Total Requests', _totalRequests.toString(), Icons.back_hand, Colors.orange, dark,
            onTap: () => _tab.animateTo(3)),
        const SizedBox(height: 16),
        _statCard('Medications Dictionary', _medications.length.toString(), Icons.menu_book, Colors.teal, dark,
            onTap: () => _tab.animateTo(4)),
      ],
    );
  }

  Widget _buildAllAccounts(Color textPrimary, Color textSecond, bool dark) {
    final cardBg = dark ? const Color(0xFF1E1E2E) : Colors.white;

    return Column(
      children: [
        // ── Segmented sub-tab bar ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _accountsSubTab = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _accountsSubTab == 0 ? Colors.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      PharmacyLogo(size: 18, bgColor: _accountsSubTab == 0 ? Colors.transparent : Colors.green, symbolColor: _accountsSubTab == 0 ? Colors.white : Colors.green, showBackground: _accountsSubTab != 0),
                      const SizedBox(width: 6),
                      Text(
                        'Pharmacies (${_pharmacies.length})',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _accountsSubTab == 0 ? Colors.white : textSecond,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _accountsSubTab = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _accountsSubTab == 1 ? Colors.blue : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.people, size: 16, color: _accountsSubTab == 1 ? Colors.white : textSecond),
                      const SizedBox(width: 6),
                      Text(
                        'Users (${_users.length})',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _accountsSubTab == 1 ? Colors.white : textSecond,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: Colors.blueAccent,
            child: _accountsSubTab == 0
              // ── PHARMACIES ──
              ? (_pharmacies.isEmpty
                ? _emptyState(Icons.local_pharmacy_outlined, 'No pharmacies found', textSecond, dark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _pharmacies.length,
                    itemBuilder: (_, i) {
                      final p = _pharmacies[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: Key('pharm_${p['id']}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(
                            'Delete Pharmacy?',
                            'This will remove ${p['name'] ?? 'this pharmacy'} and all its stock.',
                            cardBg, textPrimary, textSecond,
                          ),
                          onDismissed: (_) {
                            setState(() => _pharmacies.removeAt(i));
                            _sb.from('pharmacies').delete().eq('id', p['id'].toString())
                              .catchError((_) => _loadData());
                          },
                          background: _swipeDeleteBackground(),
                          child: Container(
                            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              onTap: () => _showPharmacyDetail(p, textPrimary, textSecond, dark, cardBg),
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.withValues(alpha: 0.1),
                                child: const PharmacyLogo(size: 36, bgColor: Color(0xFF2EB15B)),
                              ),
                              title: Text(p['name'] ?? '', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                              subtitle: Text('${p['city'] ?? ''} • ${p['is_verified'] == true ? '✓ Verified' : 'Pending'}',
                                style: TextStyle(color: p['is_verified'] == true ? Colors.green : Colors.orange, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  ))
              // ── USERS ──
              : (_users.isEmpty
                ? _emptyState(Icons.people_outline, 'No users found', textSecond, dark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _users.length,
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: Key('user_${u['id']}'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(
                            'Delete User?',
                            'This will remove ${u['full_name'] ?? 'this user'}\'s profile. The auth account must be removed separately in Supabase.',
                            cardBg, textPrimary, textSecond,
                          ),
                          onDismissed: (_) {
                            setState(() => _users.removeAt(i));
                            _sb.from('profiles').delete().eq('id', u['id'].toString())
                              .catchError((_) => _loadData());
                          },
                          background: _swipeDeleteBackground(),
                          child: Container(
                            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              onTap: () => _showUserDetail(u, textPrimary, textSecond, dark, cardBg),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                child: const Icon(Icons.person, color: Colors.blue, size: 20),
                              ),
                              title: Text(u['full_name'] ?? 'No Name', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                              subtitle: Text(u['phone'] ?? 'No phone', style: TextStyle(color: textSecond, fontSize: 12)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.blueAccent, size: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  )),
          ),
        ),
      ],
    );
  }

  // Shared swipe-to-delete red background
  Widget _swipeDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.delete_outline, color: Colors.white, size: 24),
        SizedBox(height: 4),
        Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // Shared empty state widget
  Widget _emptyState(IconData icon, String label, Color textSecond, bool dark) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
      const SizedBox(height: 14),
      Text(label, style: TextStyle(color: textSecond, fontSize: 15)),
    ]));
  }

  // Shared confirmation dialog for destructive actions
  Future<bool?> _confirmDelete(String title, String body, Color cardBg, Color textPrimary, Color textSecond) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Text(body, style: TextStyle(color: textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textSecond)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  // ── Pharmacy detail sheet: full info + stock + donations ─────────────
  void _showPharmacyDetail(Map<String, dynamic> pharmacy, Color textPrimary, Color textSecond, bool dark, Color cardBg) async {
    List<Map<String, dynamic>> stock = [];
    List<Map<String, dynamic>> pharmDonations = [];
    bool loading = true;
    int sheetTab = 0; // 0 = Info, 1 = Stock, 2 = Donations

    // Mutable local state for live toggling inside the sheet
    bool isVerified = pharmacy['is_verified'] == true;
    bool isPoint    = pharmacy['is_donation_point'] == true;
    final innerBg    = dark ? const Color(0xFF2A2A3E) : const Color(0xFFF8F8F8);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (innerCtx, setSheet) {
          if (loading) {
            Future.wait([
              _sb.from('pharmacy_stock').select('*').eq('pharmacy_id', pharmacy['id'].toString()).order('medication_name'),
              _sb.from('donations').select('*').eq('pharmacy_id', pharmacy['id'].toString()).order('created_at', ascending: false),
            ]).then((res) {
              if (innerCtx.mounted) {
                setSheet(() {
                  stock         = List<Map<String,dynamic>>.from(res[0] as List);
                  pharmDonations = List<Map<String,dynamic>>.from(res[1] as List);
                  loading = false;
                });
              }
            }).catchError((_) {
              if (innerCtx.mounted) {
                setSheet(() => loading = false);
              }
            });
          }

          Widget badge(String label, Color color) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          );

          Widget infoRow(IconData icon, String label, String value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(icon, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text('$label: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecond)),
              Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: textPrimary))),
            ]),
          );

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    CircleAvatar(radius: 26, backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: const PharmacyLogo(size: 40, bgColor: Color(0xFF2EB15B))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pharmacy['name'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        badge(isVerified ? '✓ Verified' : '⏳ Pending', isVerified ? Colors.green : Colors.orange),
                        const SizedBox(width: 6),
                        if (isPoint) badge('📍 Collection Point', Colors.blue),
                      ]),
                    ])),
                  ]),
                ),
                const SizedBox(height: 10),
                // ── Sub-tab bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    for (final entry in [
                      (0, Icons.info_outline, 'Info', Colors.blueAccent),
                      (1, Icons.verified_user_outlined, 'Certificate', Colors.purple),
                      (2, Icons.inventory_2_outlined, 'Stock (${loading ? '…' : stock.length})', Colors.green),
                      (3, Icons.favorite_outline, 'Donations (${loading ? '…' : pharmDonations.length})', Colors.orange),
                    ]) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheet(() => sheetTab = entry.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: sheetTab == entry.$1 ? entry.$4 : Colors.transparent, width: 2.5)),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(entry.$2, size: 14, color: sheetTab == entry.$1 ? entry.$4 : textSecond),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(entry.$3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: sheetTab == entry.$1 ? entry.$4 : textSecond)),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      if (entry.$1 < 3) const SizedBox(width: 4),
                    ],
                  ]),
                ),
                const Divider(height: 1),
                // ── Content ──
                Expanded(
                  child: loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.green))
                    : sheetTab == 0
                      // Info tab
                      ? ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(20),
                          children: [
                            infoRow(Icons.location_city, 'City', pharmacy['city'] ?? 'N/A'),
                            infoRow(Icons.phone_outlined, 'Phone', pharmacy['phone'] ?? 'N/A'),
                            infoRow(Icons.location_on_outlined, 'Address', pharmacy['address'] ?? 'N/A'),
                            infoRow(Icons.access_time_outlined, 'Opening Hours', pharmacy['opening_hours'] ?? 'N/A'),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // ── Collection Point Toggle ──
                            Row(children: [
                              Container(width: 32, height: 32,
                                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.location_on, color: Colors.blue, size: 16)),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Donation Collection Point', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                                Text('Acts as a hub for medication donations', style: TextStyle(fontSize: 11, color: textSecond)),
                              ])),
                              Switch(
                                value: isPoint,
                                activeColor: Colors.blue,
                                onChanged: (val) async {
                                  setSheet(() => isPoint = val);
                                  await _sb.from('pharmacies').update({'is_donation_point': val}).eq('id', pharmacy['id'].toString());
                                  if (mounted) _loadData();
                                },
                              ),
                            ]),
                            const SizedBox(height: 16),


                            // ── Verify / Reject Buttons ──
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.cancel_outlined, size: 16),
                                  label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    setSheet(() => isVerified = false);
                                    await _sb.from('pharmacies').update({'is_verified': false}).eq('id', pharmacy['id'].toString());
                                    if (mounted) {
                                      _loadData();
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text('Pharmacy rejected.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    setSheet(() => isVerified = true);
                                    await _sb.from('pharmacies').update({'is_verified': true}).eq('id', pharmacy['id'].toString());
                                    if (mounted) {
                                      _loadData();
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text('Pharmacy verified!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                                    }
                                  },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                          ],
                        )
                      : sheetTab == 1
                        // Certificate tab
                        ? ListView(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(20),
                            children: [
                              if (pharmacy['certificate_url'] != null && pharmacy['certificate_url'].toString().isNotEmpty) ...[
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        insetPadding: EdgeInsets.zero,
                                        backgroundColor: Colors.transparent,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            InteractiveViewer(
                                              child: Image.network(pharmacy['certificate_url'].toString(), fit: BoxFit.contain),
                                            ),
                                            Positioned(
                                              top: 40,
                                              right: 20,
                                              child: IconButton(
                                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                                onPressed: () => Navigator.pop(ctx),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      pharmacy['certificate_url'].toString(),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 150,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: innerBg, borderRadius: BorderRadius.circular(12)),
                                        child: Text('Could not load image', style: TextStyle(color: textSecond)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text('Tap to view full screen', textAlign: TextAlign.center, style: TextStyle(color: textSecond, fontSize: 12)),
                              ] else
                                Center(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    const SizedBox(height: 40),
                                    Icon(Icons.no_photography_outlined, color: Colors.grey.shade500, size: 48),
                                    const SizedBox(height: 12),
                                    Text('No certificate uploaded', style: TextStyle(color: textSecond)),
                                  ])
                                ),
                            ],
                          )
                      : sheetTab == 2
                        // Stock tab
                        ? (stock.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: dark ? Colors.white24 : Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No stock recorded', style: TextStyle(color: textSecond)),
                            ]))
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.all(16),
                              itemCount: stock.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final s = stock[i];
                                final inStock = s['in_stock'] == true;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: innerBg, borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    Container(width: 36, height: 36,
                                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.medication, color: Colors.green, size: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(s['medication_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                                      Text('Qty: ${s['quantity'] ?? 'N/A'} • Exp: ${s['expiry_date'] ?? 'N/A'}', style: TextStyle(color: textSecond, fontSize: 12)),
                                    ])),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: (inStock ? Colors.green : Colors.grey).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                      child: Text(inStock ? 'In Stock' : 'Out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: inStock ? Colors.green : Colors.grey)),
                                    ),
                                  ]),
                                );
                              },
                            ))
                        // Donations tab
                        : (pharmDonations.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.volunteer_activism_outlined, size: 48, color: dark ? Colors.white24 : Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No donations directed here', style: TextStyle(color: textSecond)),
                            ]))
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.all(16),
                              itemCount: pharmDonations.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final d = pharmDonations[i];
                                final status = (d['status'] ?? 'pending').toString();
                                final statusColor = status == 'accepted' ? Colors.green : status == 'rejected' ? Colors.redAccent : Colors.orange;
                                final donorId = d['donor_id']?.toString() ?? '';
                                final donor = _users.firstWhere((u) => u['id']?.toString() == donorId, orElse: () => {});
                                final donorName = donor['full_name'] as String? ?? 'Unknown donor';
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: innerBg, borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    Container(width: 36, height: 36,
                                      decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.favorite, color: Colors.purple, size: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(d['medication_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                                      Text('From: $donorName • Qty: ${d['quantity'] ?? 'N/A'}', style: TextStyle(color: textSecond, fontSize: 12)),
                                    ])),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                                    ),
                                  ]),
                                );
                              },
                            )),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── User detail sheet: donations + requests ──────────────────────────
  void _showUserDetail(Map<String, dynamic> user, Color textPrimary, Color textSecond, bool dark, Color cardBg) async {
    final userId = user['id'].toString();
    List<Map<String, dynamic>> userDonations = [];
    List<Map<String, dynamic>> userRequests = [];
    bool loading = true;
    int sheetTab = 0; // 0 = donations, 1 = requests

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (innerCtx, setSheet) {
          if (loading) {
            Future.wait([
              _sb.from('donations').select('*').eq('donor_id', userId).order('created_at', ascending: false),
              _sb.from('donation_requests').select('*').eq('requester_id', userId).order('created_at', ascending: false),
            ]).then((results) {
              if (innerCtx.mounted) {
                setSheet(() {
                  userDonations = List<Map<String,dynamic>>.from(results[0] as List);
                  userRequests  = List<Map<String,dynamic>>.from(results[1] as List);
                  loading = false;
                });
              }
            }).catchError((_) {
              if (innerCtx.mounted) {
                setSheet(() => loading = false);
              }
            });
          }
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.1), child: const Icon(Icons.person, color: Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user['full_name'] ?? 'Unknown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                      Text(user['phone'] ?? 'No phone', style: TextStyle(color: textSecond, fontSize: 13)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                // Mini tab bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheet(() => sheetTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: sheetTab == 0 ? Colors.purple : Colors.transparent, width: 2)),
                          ),
                          child: Text('Donations (${loading ? '…' : userDonations.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600,
                              color: sheetTab == 0 ? Colors.purple : textSecond)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheet(() => sheetTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: sheetTab == 1 ? Colors.orange : Colors.transparent, width: 2)),
                          ),
                          child: Text('Requests (${loading ? '…' : userRequests.length})',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600,
                              color: sheetTab == 1 ? Colors.orange : textSecond)),
                        ),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                    : sheetTab == 0
                      ? (userDonations.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.favorite_outline, size: 48, color: dark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No donations', style: TextStyle(color: textSecond)),
                          ]))
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            itemCount: userDonations.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final d = userDonations[i];
                              final status = (d['status'] ?? 'pending').toString();
                              final statusColor = status == 'accepted' ? Colors.green : status == 'rejected' ? Colors.redAccent : Colors.orange;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: dark ? const Color(0xFF2A2A3E) : const Color(0xFFF8F8F8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(children: [
                                  Container(width: 36, height: 36,
                                    decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.favorite, color: Colors.purple, size: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(d['medication_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                                    Text('Qty: ${d['quantity'] ?? 'N/A'}', style: TextStyle(color: textSecond, fontSize: 12)),
                                  ])),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                    child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                                  ),
                                ]),
                              );
                            },
                          ))
                      : (userRequests.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.back_hand_outlined, size: 48, color: dark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No requests', style: TextStyle(color: textSecond)),
                          ]))
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(16),
                            itemCount: userRequests.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final r = userRequests[i];
                              final status = (r['status'] ?? 'open').toString();
                              final statusColor = status == 'fulfilled' ? Colors.green : status == 'closed' ? Colors.grey : Colors.orange;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: dark ? const Color(0xFF2A2A3E) : const Color(0xFFF8F8F8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(children: [
                                  Container(width: 36, height: 36,
                                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.back_hand, color: Colors.orange, size: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(r['medication_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary, fontSize: 14)),
                                    Text('Qty needed: ${r['quantity_needed'] ?? 'N/A'}', style: TextStyle(color: textSecond, fontSize: 12)),
                                    if ((r['message'] ?? '').toString().isNotEmpty)
                                      Text(r['message'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textSecond, fontSize: 11)),
                                  ])),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                    child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                                  ),
                                ]),
                              );
                            },
                          )),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, bool dark, {Widget? customIcon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: onTap != null ? Border.all(color: color.withValues(alpha: 0.25)) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: customIcon ?? Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                  Text(title, style: TextStyle(fontSize: 14, color: dark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, size: 14, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }



  Widget _buildDrugs(Color textPrimary, Color textSecond, bool dark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddDrugSheet(dark ? const Color(0xFF1E1E2E) : Colors.white, textPrimary, textSecond),
            icon: const Icon(Icons.add),
            label: const Text('Add Medication'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54), padding: const EdgeInsets.all(16)),
          ),
        ),
        Expanded(
          child: _medications.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.menu_book_outlined, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
                const SizedBox(height: 14),
                Text('No medications in dictionary', style: TextStyle(fontSize: 15, color: dark ? Colors.white38 : Colors.grey.shade400)),
              ]))
            : ListView.builder(
                itemCount: _medications.length,
                itemBuilder: (ctx, i) {
                  final m = _medications[i];
                  return Dismissible(
                    key: Key(m['id']?.toString() ?? i.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: dark ? const Color(0xFF1E1E2E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Delete Medication', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                          content: Text('Are you sure you want to delete "${m['name']}"?', style: TextStyle(color: textSecond)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: textSecond))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ) ?? false;
                    },
                    onDismissed: (_) => _deleteMedication(m['id'].toString()),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E1E2E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.medication_outlined, color: Colors.teal, size: 20),
                        ),
                        title: Text(m['name'], style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                        subtitle: m['generic_name'] != null ? Text(m['generic_name'], style: TextStyle(color: textSecond)) : null,
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildDonations(Color textPrimary, Color textSecond, bool dark) {
    final cardBg = dark ? const Color(0xFF1E1E2E) : Colors.white;
    if (_donations.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.favorite_outline, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
        const SizedBox(height: 14),
        Text('No donations yet', style: TextStyle(color: textSecond, fontSize: 15)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.blueAccent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _donations.length,
        itemBuilder: (_, i) {
          final d = _donations[i];
          final donorId = d['donor_id']?.toString() ?? '';
          final donorProfile = _users.firstWhere(
            (u) => u['id']?.toString() == donorId,
            orElse: () => {},
          );
          final donorName = donorProfile['full_name'] as String?
              ?? (donorId.isNotEmpty ? 'ID: ${donorId.substring(0, 8)}…' : 'Unknown');
          final status = (d['status'] ?? 'pending').toString();
          final statusColor = status == 'accepted'
              ? Colors.green : status == 'rejected'
              ? Colors.redAccent : Colors.orange;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: Key('donation_${d['id']}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(
                'Delete Donation?',
                'This will permanently remove this donation record.',
                cardBg, textPrimary, textSecond,
              ),
              onDismissed: (_) {
                setState(() => _donations.removeAt(i));
                _sb.from('donations').delete().eq('id', d['id'].toString())
                  .catchError((_) => _loadData());
              },
              background: _swipeDeleteBackground(),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withValues(alpha: 0.12),
                    child: const Icon(Icons.favorite, color: Colors.purple, size: 20),
                  ),
                  title: Text(d['medication_name'] ?? 'Unknown medication',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 2),
                    Text('By: $donorName', style: TextStyle(color: textSecond, fontSize: 12)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
                      ),
                      if ((d['quantity'] ?? '') != '') ...[ const SizedBox(width: 8),
                        Text('Qty: ${d['quantity']}', style: TextStyle(color: textSecond, fontSize: 12))],
                    ]),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequests(Color textPrimary, Color textSecond, bool dark) {
    final cardBg = dark ? const Color(0xFF1E1E2E) : Colors.white;
    if (_requests.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.back_hand_outlined, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
        const SizedBox(height: 14),
        Text('No requests yet', style: TextStyle(color: textSecond, fontSize: 15)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.blueAccent,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (_, i) {
          final r = _requests[i];
          final requesterId = r['requester_id']?.toString() ?? '';
          final requesterProfile = _users.firstWhere(
            (u) => u['id']?.toString() == requesterId,
            orElse: () => {},
          );
          final requesterName = requesterProfile['full_name'] as String?
              ?? (requesterId.isNotEmpty ? 'ID: ${requesterId.substring(0, 8)}…' : 'Unknown');
          final status = (r['status'] ?? 'open').toString();
          final statusColor = status == 'fulfilled'
              ? Colors.green : status == 'closed'
              ? Colors.grey : Colors.orange;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: Key('request_${r['id']}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(
                'Delete Request?',
                'This will permanently remove this medication request.',
                cardBg, textPrimary, textSecond,
              ),
              onDismissed: (_) {
                setState(() => _requests.removeAt(i));
                _sb.from('donation_requests').delete().eq('id', r['id'].toString())
                  .catchError((_) => _loadData());
              },
              background: _swipeDeleteBackground(),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.12),
                    child: const Icon(Icons.back_hand, color: Colors.orange, size: 20),
                  ),
                  title: Text(r['medication_name'] ?? 'Unknown medication',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 2),
                    Text('By: $requesterName', style: TextStyle(color: textSecond, fontSize: 12)),
                    if ((r['message'] ?? '').toString().isNotEmpty) ...[ const SizedBox(height: 2),
                      Text(r['message'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textSecond, fontSize: 12))],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
