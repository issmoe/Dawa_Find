import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../widgets/pharmacy_logo.dart';

class PharmacyDashboard extends StatefulWidget {
  const PharmacyDashboard({super.key});
  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _drugs = [];
  List<Map<String, dynamic>> _allDonations = [];
  int _donationsSubTab = 0; // 0: Pending, 1: History
  bool _loading = true;
  bool _loadingDonations = true;
  static const _green = Color(0xFF2EB15B);
  static const _purple = Color(0xFF7C3AED);
  late TabController _tabCtrl;
  String? _pharmacyId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadStock();
    _loadDrugs();
    _loadDonations();
    _loadPharmacyId();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadPharmacyId() async {
    _pharmacyId = await AuthService.getMyPharmacyId();
  }

  Future<void> _loadDrugs() async {
    final d = await AuthService.fetchDrugs();
    if (mounted) setState(() => _drugs = d);
  }

  Future<void> _loadStock() async {
    setState(() => _loading = true);
    final s = await AuthService.myPharmacyStock();
    if (mounted) setState(() { _stock = s; _loading = false; });
  }

  Future<void> _loadDonations() async {
    setState(() => _loadingDonations = true);
    final d = await AuthService.fetchPharmacyDonations();
    if (mounted) setState(() { _allDonations = d; _loadingDonations = false; });
  }

  Future<void> _reviewDonation(String donationId, String status) async {
    final success = await AuthService.updateDonationStatus(
      donationId: donationId,
      status: status,
      reviewedByPharmacyId: _pharmacyId,
    );
    if (success && mounted) {
      _loadDonations();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'accepted' ? 'Donation accepted ✓' : 'Donation rejected ✗'),
        backgroundColor: status == 'accepted' ? _green : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
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
            Container(width: 48, height: 48,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
              child: const PharmacyLogo(size: 48, bgColor: Color(0xFF2EB15B))),
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

        // ── Stats ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(children: [
            _StatCard(label: 'Total Items', value: _stock.length.toString(), color: _green, icon: Icons.inventory_2_outlined, dark: dark),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Pending',
              value: _allDonations.where((d) => d['status'] == 'pending').length.toString(),
              color: _purple,
              icon: Icons.pending_actions,
              dark: dark,
            ),
          ]),
        ),

        // ── Tabs ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: _green,
            unselectedLabelColor: textSecond,
            indicatorColor: _green,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: dark ? Colors.white12 : const Color(0xFFE0E0E0),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            tabs: const [Tab(text: 'Stock'), Tab(text: 'Donations')],
          ),
        ),

        // ── Tab content ──────────────────────────────────
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
            // ── Stock tab ───────────────────────────────
            _buildStockTab(dark, cardBg, textPrimary, textSecond),
            // ── Donations tab ───────────────────────────
            _buildDonationsTab(dark, cardBg, textPrimary, textSecond),
          ]),
        ),
      ])),
    );
  }

  Widget _buildStockTab(bool dark, Color cardBg, Color textPrimary, Color textSecond) {
    return Column(children: [
      // Add button
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(children: [
          Text('Medication Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showAddStockSheet(context, dark, cardBg, textPrimary),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Add', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _stock.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2_outlined, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
                const SizedBox(height: 14),
                Text('No stock added yet', style: TextStyle(fontSize: 15, color: dark ? Colors.white38 : Colors.grey.shade400)),
              ]))
            : RefreshIndicator(
                onRefresh: _loadStock, color: _green,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _stock.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item    = _stock[i];
                    final inStock = item['in_stock'] == true;
                    return Dismissible(
                      key: Key(item['id']?.toString() ?? i.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                      ),
                      onDismissed: (_) async {
                        final itemId = item['id'];
                        setState(() => _stock.removeAt(i));
                        try {
                          await Supabase.instance.client
                              .from('pharmacy_stock')
                              .delete()
                              .eq('id', itemId);
                        } catch (_) { _loadStock(); }
                      },
                      child: GestureDetector(
                      onTap: () => _showEditStockSheet(context, item, dark, cardBg, textPrimary),
                      child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
                        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                      child: Row(children: [
                        Container(width: 42, height: 42,
                          decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.medication, color: _green, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['medication_name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                          const SizedBox(height: 3),
                          Text('Qty: ${item['quantity']} • Exp: ${item['expiry_date'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: textSecond)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (inStock ? _green : Colors.grey).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(inStock ? 'In Stock' : 'Out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: inStock ? _green : Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.edit_outlined, size: 16, color: textSecond),
                      ]),
                    )));
                  },
                ),
              ),
      ),
    ]);
  }

  Widget _buildDonationsTab(bool dark, Color cardBg, Color textPrimary, Color textSecond) {
    if (_loadingDonations) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    
    final pending = _allDonations.where((d) => d['status'] == 'pending').toList();
    final history = _allDonations.where((d) => d['status'] != 'pending').toList();
    final currentList = _donationsSubTab == 0 ? pending : history;

    return Column(
      children: [
        // Segmented Sub-Tab
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _donationsSubTab = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _donationsSubTab == 0 ? _purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        'Pending (${pending.length})',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _donationsSubTab == 0 ? Colors.white : textSecond,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _donationsSubTab = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _donationsSubTab == 1 ? _purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        'History (${history.length})',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: _donationsSubTab == 1 ? Colors.white : textSecond,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        
        // List View
        Expanded(
          child: currentList.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.volunteer_activism_outlined, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 14),
                  Text(_donationsSubTab == 0 ? 'No pending donations' : 'No donation history', style: TextStyle(fontSize: 15, color: dark ? Colors.white38 : Colors.grey.shade400)),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadDonations, color: _purple,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final item = currentList[i];
                      final expRaw = item['expiry_date'] as String?;
                      final expLabel = expRaw != null && expRaw.length >= 7 ? 'Exp ${expRaw.substring(0, 7)}' : '';

                      final donorId = item['donor_id']?.toString() ?? '';
                      final donorProfile = item['profiles'] as Map<String, dynamic>?;
                      final donorName = donorProfile?['full_name'] as String? ?? (donorId.isNotEmpty ? 'ID: ${donorId.substring(0, 8)}…' : 'Anonymous');
                      final donorPhone = donorProfile?['phone'] as String?;
                      final donorDonationCount = donorProfile?['donation_count'] as int? ?? 1;
                      final status = item['status'] as String? ?? 'pending';

                      return Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _purple.withValues(alpha: 0.2)),
                          boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(width: 44, height: 44,
                                decoration: BoxDecoration(color: _purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.medication, color: _purple, size: 22)),
                              const SizedBox(width: 12),
                              Expanded(child: Builder(builder: (_) {
                                final donMedName = (item['medication_name'] ?? '').toString();
                                final donDictMatch = _drugs.cast<Map<String, dynamic>?>().firstWhere(
                                  (d) {
                                    final dName = (d?['name'] ?? '').toString().toLowerCase().trim();
                                    return dName == donMedName.toLowerCase().trim() ||
                                           donMedName.toLowerCase().trim().contains(dName) ||
                                           dName.contains(donMedName.toLowerCase().trim());
                                  },
                                  orElse: () => null,
                                );
                                // Always use dictionary's generic name as source of truth
                                String donGeneric = donDictMatch?['generic_name']?.toString() ?? '';
                                if (donGeneric.isEmpty) {
                                  final stockGen = item['generic_name']?.toString() ?? '';
                                  if (stockGen.isNotEmpty && stockGen.toLowerCase().trim() != donMedName.toLowerCase().trim()) {
                                    donGeneric = stockGen;
                                  }
                                }
                                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(donMedName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
                                  if (donGeneric.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(donGeneric, style: TextStyle(fontSize: 12, color: textSecond)),
                                  ],
                                ]);
                              })),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: status == 'pending' ? Colors.orange.withValues(alpha: 0.1) : (status == 'accepted' ? _green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(20)
                                ),
                                child: Text(status.toUpperCase(), style: TextStyle(
                                  fontSize: 11, 
                                  color: status == 'pending' ? Colors.orange : (status == 'accepted' ? _green : Colors.red), 
                                  fontWeight: FontWeight.w600
                                )),
                              ),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _DonDetailRow(icon: Icons.person_outline, text: 'From: $donorName', dark: dark),
                              const SizedBox(height: 5),
                              if (donorPhone != null && donorPhone.trim().isNotEmpty) ...[
                                _DonDetailRow(icon: Icons.phone_outlined, text: donorPhone, dark: dark),
                                const SizedBox(height: 5),
                              ],
                              _DonDetailRow(icon: Icons.history_outlined, text: 'Total donations by user: $donorDonationCount', dark: dark),
                              const SizedBox(height: 5),
                              if (item['quantity'] != null && (item['quantity'] as int) > 0) ...[
                                _DonDetailRow(icon: Icons.inventory_2_outlined, text: '${item['quantity']} tablet(s)', dark: dark),
                                const SizedBox(height: 5),
                              ],
                              if (expLabel.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                _DonDetailRow(icon: Icons.calendar_month_outlined, text: expLabel, dark: dark),
                              ],
                              if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                _DonDetailRow(icon: Icons.notes_outlined, text: item['notes'], dark: dark),
                              ],
                            ]),
                          ),
                          if (status == 'pending') ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              child: Row(children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _reviewDonation(item['id'].toString(), 'rejected'),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade600,
                                      side: BorderSide(color: Colors.red.shade300),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _reviewDonation(item['id'].toString(), 'accepted'),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ] else ...[
                            const SizedBox(height: 14),
                          ],
                        ]),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showAddStockSheet(BuildContext ctx, bool dark, Color cardBg, Color textPrimary) {
    String selectedMedication = '';
    final genericCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final expCtrl = TextEditingController();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 16),
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                return _drugs.where((drug) => (drug['name'] ?? '').toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              displayStringForOption: (drug) => drug['name'] ?? '',
              onSelected: (drug) {
                selectedMedication = drug['name'] ?? '';
                genericCtrl.text = drug['generic_name'] ?? '';
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                // Capture manual entry if not selected from list
                textEditingController.addListener(() {
                  selectedMedication = textEditingController.text;
                });
                return _SheetField(
                  ctrl: textEditingController,
                  hint: 'Search medication...',
                  dark: dark,
                  focusNode: focusNode,
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(10),
                    color: dark ? const Color(0xFF1E2E45) : Colors.white,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 40),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option['name'] ?? '', style: TextStyle(color: dark ? Colors.white : Colors.black)),
                            subtitle: Text(option['generic_name'] ?? '', style: TextStyle(color: dark ? Colors.white54 : Colors.grey, fontSize: 12)),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _SheetField(ctrl: genericCtrl, hint: 'Generic name',     dark: dark),
            const SizedBox(height: 12),
            _SheetField(ctrl: qtyCtrl,     hint: 'Quantity',         dark: dark, type: TextInputType.number),
            const SizedBox(height: 12),
            _SheetField(ctrl: expCtrl,     hint: 'Expiry (YYYY-MM-DD)', dark: dark),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (selectedMedication.trim().isEmpty || qtyCtrl.text.trim().isEmpty) return;
                  final qty = int.tryParse(qtyCtrl.text.trim());
                  if (qty == null || qty <= 0) return;

                  Navigator.pop(ctx);

                  // Fetch pharmacy id for this user
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) return;
                  try {
                    final pharmacy = await Supabase.instance.client
                        .from('pharmacies')
                        .select('id')
                        .eq('user_id', user.id)
                        .maybeSingle();
                    if (pharmacy == null) return;

                    await Supabase.instance.client.from('pharmacy_stock').insert({
                      'pharmacy_id':     pharmacy['id'],
                      'medication_name': selectedMedication.trim(),
                      'generic_name':    genericCtrl.text.trim(),
                      'quantity':        qty,
                      'expiry_date':     expCtrl.text.trim().isEmpty ? null : expCtrl.text.trim(),
                      'in_stock':        true,
                    });
                    _loadStock();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('${selectedMedication.trim()} added to stock!'),
                        backgroundColor: _green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Failed to add: $e'),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
                child: const Text('Add to Stock', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showEditStockSheet(BuildContext ctx, Map<String, dynamic> item, bool dark, Color cardBg, Color textPrimary) {
    final qtyCtrl = TextEditingController(text: item['quantity']?.toString() ?? '');
    final expCtrl = TextEditingController(text: item['expiry_date']?.toString() ?? '');
    bool inStock = item['in_stock'] == true;
    final textSecond = dark ? Colors.white70 : const Color(0xFF555555);

    // Look up the correct generic name from the medications dictionary
    final medName = (item['medication_name'] ?? '').toString().toLowerCase().trim();
    final dictMatch = _drugs.cast<Map<String, dynamic>?>().firstWhere(
      (d) {
        final dName = (d?['name'] ?? '').toString().toLowerCase().trim();
        return dName == medName ||
               medName.contains(dName) ||
               dName.contains(medName);
      },
      orElse: () => null,
    );
    // Always use dictionary's generic name as source of truth
    String genericName = dictMatch?['generic_name']?.toString() ?? '';
    // Only fall back to stock's value if not found in dictionary and it's actually different
    if (genericName.isEmpty) {
      final stockGeneric = item['generic_name']?.toString() ?? '';
      if (stockGeneric.isNotEmpty && stockGeneric.toLowerCase().trim() != medName) {
        genericName = stockGeneric;
      }
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined, color: _green, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Edit Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                  Text(item['medication_name'] ?? '', style: TextStyle(fontSize: 13, color: textSecond)),
                ])),
              ]),
              const SizedBox(height: 20),
              if (genericName.isNotEmpty) ...[
                Text('Generic Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
                const SizedBox(height: 4),
                Text(genericName, style: TextStyle(fontSize: 14, color: textPrimary)),
                const SizedBox(height: 16),
              ],
              Text('Quantity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
              const SizedBox(height: 6),
              _SheetField(ctrl: qtyCtrl, hint: 'Quantity', dark: dark, type: TextInputType.number),
              const SizedBox(height: 16),
              Text('Expiry Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
              const SizedBox(height: 6),
              _SheetField(ctrl: expCtrl, hint: 'YYYY-MM-DD', dark: dark),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: (inStock ? _green : Colors.grey).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(inStock ? Icons.check_circle : Icons.cancel, color: inStock ? _green : Colors.grey, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Availability', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                  Text(inStock ? 'Currently in stock' : 'Out of stock', style: TextStyle(fontSize: 11, color: textSecond)),
                ])),
                Switch(
                  value: inStock,
                  activeColor: _green,
                  onChanged: (val) => setSheet(() => inStock = val),
                ),
              ]),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    final qty = int.tryParse(qtyCtrl.text.trim());
                    if (qty == null || qty < 0) return;

                    Navigator.pop(ctx);

                    try {
                      final updates = <String, dynamic>{
                        'quantity': qty,
                        'in_stock': inStock,
                      };
                      if (expCtrl.text.trim().isNotEmpty) {
                        updates['expiry_date'] = expCtrl.text.trim();
                      }
                      // If quantity is 0, auto-set out of stock
                      if (qty == 0) updates['in_stock'] = false;

                      await Supabase.instance.client
                          .from('pharmacy_stock')
                          .update(updates)
                          .eq('id', item['id']);
                      _loadStock();
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text('${item['medication_name']} updated!'),
                          backgroundColor: _green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text('Failed to update: $e'),
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
      ),
    );
  }
  void _showEditProfileSheet(BuildContext ctx, bool dark, Color cardBg, Color textPrimary) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Fetch pharmacy details
    final row = await Supabase.instance.client
        .from('pharmacies')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (!ctx.mounted) return;

    final nameCtrl    = TextEditingController(text: row?['name'] ?? user.userMetadata?['full_name'] ?? '');
    final phoneCtrl   = TextEditingController(text: row?['phone'] ?? '');
    final addressCtrl = TextEditingController(text: row?['address'] ?? '');
    final cityCtrl    = TextEditingController(text: row?['city'] ?? '');
    final hoursCtrl   = TextEditingController(text: row?['opening_hours'] ?? '');
    bool isDonationPoint = row?['is_donation_point'] == true;
    final textSecond = dark ? Colors.white60 : const Color(0xFF888888);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row with close button
              Row(children: [
                Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext),
                  child: Icon(Icons.close, color: textSecond),
                ),
              ]),
              const SizedBox(height: 16),

              // Name
              Text('Pharmacy Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
              const SizedBox(height: 6),
              _SheetField(ctrl: nameCtrl, hint: 'Pharmacy Name', dark: dark),
              const SizedBox(height: 12),

              // Phone
              Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
              const SizedBox(height: 6),
              _SheetField(ctrl: phoneCtrl, hint: '+213 6xx xxx xxx', dark: dark, type: TextInputType.phone),
              const SizedBox(height: 12),

              // Address
              Text('Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
              const SizedBox(height: 6),
              _SheetField(ctrl: addressCtrl, hint: 'Street address', dark: dark),
              const SizedBox(height: 12),

              // City
              Text('City', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
              const SizedBox(height: 6),
              _SheetField(ctrl: cityCtrl, hint: 'City', dark: dark),
              const SizedBox(height: 12),

              // Opening Hours
              Text('Opening Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecond)),
              const SizedBox(height: 6),
              _SheetField(ctrl: hoursCtrl, hint: 'e.g. Mon–Sat 08:00–20:00', dark: dark),
              const SizedBox(height: 16),

              // Collection Point toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1E2E45) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDonationPoint ? _green.withValues(alpha: 0.5) : Colors.transparent),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDonationPoint ? _green.withValues(alpha: 0.15) : (dark ? Colors.white12 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.volunteer_activism,
                      size: 18,
                      color: isDonationPoint ? _green : textSecond),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Collection Point', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                    Text('Allow donations to be dropped off here', style: TextStyle(fontSize: 11, color: textSecond)),
                  ])),
                  Switch(
                    value: isDonationPoint,
                    onChanged: (val) => setSheetState(() => isDonationPoint = val),
                    activeThumbColor: _green,
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(sheetContext);

                    final res = await AuthService.updatePharmacyProfile(
                      pharmacyName:    nameCtrl.text.trim(),
                      phone:           phoneCtrl.text.trim(),
                      address:         addressCtrl.text.trim(),
                      city:            cityCtrl.text.trim(),
                      openingHours:    hoursCtrl.text.trim().isEmpty ? null : hoursCtrl.text.trim(),
                      isDonationPoint: isDonationPoint,
                    );

                    if (ctx.mounted) {
                      if (res.success) {
                        AppStateScope.of(ctx).updateUserName(res.name!);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text('Profile updated successfully!'),
                          backgroundColor: _green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    );
  }
}

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

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool dark;
  final TextInputType? type;
  final FocusNode? focusNode;
  const _SheetField({required this.ctrl, required this.hint, required this.dark, this.type, this.focusNode});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    focusNode: focusNode,
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

class _DonDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool dark;
  const _DonDetailRow({required this.icon, required this.text, required this.dark});

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white70 : const Color(0xFF555555);
    return Row(children: [
      Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
    ]);
  }
}
