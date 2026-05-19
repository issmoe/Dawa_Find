import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../widgets/pharmacy_logo.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _requests  = [];
  bool _loading = true;

  static const _green  = Color(0xFF2EB15B);
  static const _purple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final d = await AuthService.myDonations();
    final r = await AuthService.myRequests();
    if (mounted) setState(() { _donations = d; _requests = r; _loading = false; });
  }

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
        content: Text('Are you sure you want to sign out?', style: TextStyle(color: textSecond)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textSecond)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2EB15B),
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
    final app  = AppStateScope.of(context);
    final dark = app.isDark;
    final scaffoldBg  = dark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardBg      = dark ? const Color(0xFF1E1E2E) : Colors.white;
    final textPrimary = dark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecond  = dark ? Colors.white60 : const Color(0xFF888888);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.person, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.userName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
              Text(app.userEmail, style: TextStyle(fontSize: 12, color: textSecond)),
            ])),
            // Edit Profile button
            GestureDetector(
              onTap: () => _showEditProfileSheet(context, dark, cardBg, textPrimary),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: dark ? Colors.white12 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit, size: 18, color: textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            // Sign out button
            GestureDetector(
              onTap: _signOut,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: dark ? Colors.red.shade900.withValues(alpha: 0.4) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dark ? Colors.red.shade700 : Colors.red.shade200),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.logout, size: 15, color: dark ? Colors.red.shade300 : Colors.red.shade600),
                  const SizedBox(width: 6),
                  Text('Sign Out', style: TextStyle(fontSize: 13, color: dark ? Colors.red.shade300 : Colors.red.shade600, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Stats row ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            _StatCard(label: 'My Donations', value: _donations.length.toString(), color: _purple, icon: Icons.medication, dark: dark),
            const SizedBox(width: 12),
            _StatCard(label: 'My Requests', value: _requests.length.toString(), color: _green, icon: Icons.back_hand_outlined, dark: dark),
          ]),
        ),

        // ── Tabs ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: TabBar(
            controller: _tab,
            labelColor: _green,
            unselectedLabelColor: textSecond,
            indicatorColor: _green,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: dark ? Colors.white12 : const Color(0xFFE0E0E0),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [Tab(text: 'My Donations'), Tab(text: 'My Requests')],
          ),
        ),

        // ── Tab content ──────────────────────────────────
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : TabBarView(controller: _tab, children: [
                // Donations tab
                _donations.isEmpty
                  ? _EmptyState(icon: Icons.medication_outlined, text: 'No donations yet', dark: dark)
                  : RefreshIndicator(
                      onRefresh: _loadData, color: _green,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _donations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _DonationTile(
                          data: _donations[i], 
                          cardBg: cardBg, 
                          textPrimary: textPrimary, 
                          textSecond: textSecond,
                          onDelete: () => _confirmDelete('donation', _donations[i]['id'].toString(), context, dark, cardBg, textPrimary),
                          onEdit: () => _showEditDonationSheet(context, _donations[i], dark, cardBg, textPrimary),
                        ),
                      ),
                    ),
                // Requests tab
                _requests.isEmpty
                  ? _EmptyState(icon: Icons.back_hand_outlined, text: 'No requests yet', dark: dark)
                  : RefreshIndicator(
                      onRefresh: _loadData, color: _green,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _RequestTile(
                          data: _requests[i], 
                          cardBg: cardBg, 
                          textPrimary: textPrimary, 
                          textSecond: textSecond,
                          onDelete: () => _confirmDelete('request', _requests[i]['id'].toString(), context, dark, cardBg, textPrimary),
                          onEdit: () => _showEditRequestSheet(context, _requests[i], dark, cardBg, textPrimary),
                        ),
                      ),
                    ),
              ]),
        ),
      ])),
    );
  }

  Future<void> _confirmDelete(String type, String id, BuildContext ctx, bool dark, Color cardBg, Color textPrimary) async {
    final textSecond = dark ? Colors.white70 : const Color(0xFF555555);
    final isDonation = type == 'donation';
    
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${isDonation ? 'Donation' : 'Request'}', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this ${isDonation ? 'donation' : 'request'}?', style: TextStyle(color: textSecond)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: textSecond))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = isDonation ? await AuthService.deleteDonation(id) : await AuthService.deleteRequest(id);
      if (success && mounted && ctx.mounted) {
        _loadData();
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('${isDonation ? 'Donation' : 'Request'} deleted.'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showEditDonationSheet(BuildContext ctx, Map<String, dynamic> data, bool dark, Color cardBg, Color textPrimary) {
    final nameCtrl = TextEditingController(text: data['medication_name']);
    final qtyCtrl = TextEditingController(text: data['quantity']?.toString());
    
    // Parse expiry date if exists (YYYY-MM-DD -> YYYY-MM)
    final expRaw = data['expiry_date'] as String?;
    final expStr = (expRaw != null && expRaw.length >= 7) ? expRaw.substring(0, 7) : '';
    final expCtrl = TextEditingController(text: expStr);
    
    final notesCtrl = TextEditingController(text: data['notes']);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit Donation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 16),
            _SheetField(ctrl: nameCtrl, hint: 'Medication Name', dark: dark),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _SheetField(ctrl: qtyCtrl, hint: 'Quantity (e.g., 20)', dark: dark, type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _SheetField(ctrl: expCtrl, hint: 'Expiry (YYYY-MM)', dark: dark)),
            ]),
            const SizedBox(height: 12),
            _SheetField(ctrl: notesCtrl, hint: 'Notes (optional)', dark: dark),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty) return;
                  final qty = int.tryParse(qtyCtrl.text.trim());
                  if (qty == null || qty <= 0) return;
                  
                  Navigator.pop(ctx);
                  
                  final expText = expCtrl.text.trim();
                  String? formattedExp;
                  if (expText.isNotEmpty) {
                    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(expText)) return; // Basic validation
                    formattedExp = '$expText-01';
                  }

                  final success = await AuthService.updateDonation(
                    id: data['id'].toString(),
                    medicationName: nameCtrl.text.trim(),
                    quantity: qty,
                    expiryDate: formattedExp,
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  
                  if (success && mounted && ctx.mounted) {
                    _loadData();
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Donation updated.'), backgroundColor: _green, behavior: SnackBarBehavior.floating));
                  }
                },
                child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditRequestSheet(BuildContext ctx, Map<String, dynamic> data, bool dark, Color cardBg, Color textPrimary) {
    final nameCtrl = TextEditingController(text: data['medication_name']);
    final qtyCtrl = TextEditingController(text: data['quantity_needed']?.toString());

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 16),
            _SheetField(ctrl: nameCtrl, hint: 'Medication Name', dark: dark),
            const SizedBox(height: 12),
            _SheetField(ctrl: qtyCtrl, hint: 'Quantity Needed', dark: dark, type: TextInputType.number),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty) return;
                  final qty = int.tryParse(qtyCtrl.text.trim());
                  if (qty == null || qty <= 0) return;
                  
                  Navigator.pop(ctx);

                  final success = await AuthService.updateRequest(
                    id: data['id'].toString(),
                    medicationName: nameCtrl.text.trim(),
                    quantityNeeded: qty,
                  );
                  
                  if (success && mounted && ctx.mounted) {
                    _loadData();
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Request updated.'), backgroundColor: _green, behavior: SnackBarBehavior.floating));
                  }
                },
                child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext ctx, bool dark, Color cardBg, Color textPrimary) {
    final user = Supabase.instance.client.auth.currentUser;
    final nameCtrl = TextEditingController(text: user?.userMetadata?['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: user?.userMetadata?['phone'] ?? '');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 16),
            _SheetField(ctrl: nameCtrl, hint: 'Full Name', dark: dark),
            const SizedBox(height: 12),
            _SheetField(ctrl: phoneCtrl, hint: 'Phone Number', dark: dark, type: TextInputType.phone),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2EB15B), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  
                  final res = await AuthService.updateUserProfile(
                    fullName: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  );
                  
                  if (ctx.mounted) {
                    if (res.success) {
                      AppStateScope.of(ctx).updateUserName(res.name!);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: const Text('Profile updated successfully!'),
                        backgroundColor: const Color(0xFF2EB15B),
                        behavior: SnackBarBehavior.floating,
                      ));
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(res.error ?? 'Update failed'),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
                child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  final bool dark;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon, required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1E1E2E) : Colors.white;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14),
          boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: dark ? Colors.white54 : Colors.grey)),
          ]),
        ]),
      ),
    );
  }
}

// ── Donation tile ──────────────────────────────────────────
class _DonationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color cardBg, textPrimary, textSecond;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const _DonationTile({required this.data, required this.cardBg, required this.textPrimary, required this.textSecond, this.onDelete, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'accepted':
        statusColor = const Color(0xFF2EB15B);
        statusLabel = 'Accepted';
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pending';
    }

    final pharmacy = data['pharmacies'] as Map<String, dynamic>?;
    final pharmName = pharmacy?['name'];
    final pharmPhone = pharmacy?['phone'];

    final isPending = status == 'pending';

    Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.medication, color: Color(0xFF7C3AED), size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['medication_name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
              const SizedBox(height: 3),
              Text('Qty: ${data['quantity']} • Exp: ${data['expiry_date'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: textSecond)),
            ])),
            if (isPending && onEdit != null)
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), color: textSecond, onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
            ),
          ]),
          if (status == 'accepted' && pharmName != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              PharmacyLogo(size: 16, bgColor: textSecond, symbolColor: Colors.white),
              const SizedBox(width: 6),
              Expanded(child: Text(pharmName, style: TextStyle(fontSize: 13, color: textSecond))),
            ]),
            if (pharmPhone != null && pharmPhone.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.phone_outlined, size: 14, color: textSecond),
                const SizedBox(width: 6),
                Expanded(child: Text(pharmPhone.toString(), style: TextStyle(fontSize: 13, color: textSecond))),
              ]),
            ],
          ]
        ],
      ),
    );

    if (isPending && onDelete != null) {
      return Dismissible(
        key: ValueKey(data['id']),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onDelete!();
          return false; // Let the state update handle the removal
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        child: content,
      );
    }
    return content;
  }
}

// ── Request tile ───────────────────────────────────────────
class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color cardBg, textPrimary, textSecond;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  const _RequestTile({required this.data, required this.cardBg, required this.textPrimary, required this.textSecond, this.onDelete, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'open';
    final statusColor = status == 'open' ? const Color(0xFF2EB15B) : Colors.grey;
    final isOpen = status == 'open';

    Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFF2EB15B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.back_hand_outlined, color: Color(0xFF2EB15B), size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['medication_name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 3),
          Text('Needs: ${data['quantity_needed']}', style: TextStyle(fontSize: 12, color: textSecond)),
        ])),
        if (isOpen && onEdit != null)
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), color: textSecond, onPressed: onEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
        ),
      ]),
    );

    if (isOpen && onDelete != null) {
      return Dismissible(
        key: ValueKey(data['id']),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onDelete!();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
        child: content,
      );
    }
    return content;
  }
}

// ── Empty state ────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool dark;
  const _EmptyState({required this.icon, required this.text, required this.dark});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
      const SizedBox(height: 14),
      Text(text, style: TextStyle(fontSize: 15, color: dark ? Colors.white38 : Colors.grey.shade400)),
    ]),
  );
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool dark;
  final TextInputType? type;
  const _SheetField({required this.ctrl, required this.hint, required this.dark, this.type});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: type,
    style: TextStyle(color: dark ? Colors.white : const Color(0xFF1A1A1A), fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: dark ? const Color(0xFF1E2E45) : const Color(0xFFF5F5F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: dark ? const Color(0xFF2A3E5C) : Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: dark ? const Color(0xFF2A3E5C) : Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2EB15B), width: 1.5)),
    ),
  );
}
