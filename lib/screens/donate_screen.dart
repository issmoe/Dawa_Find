import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../l10n/strings.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/pharmacy_logo.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});
  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _drugs = [];
  List<Map<String, dynamic>> _relationPoints = [];
  bool _loading = true;
  static const _purple = Color(0xFF7C3AED);
  final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetchDonations();
    _loadDrugs();
    _loadRelationPoints();
  }

  Future<void> _loadDrugs() async {
    final d = await AuthService.fetchDrugs();
    if (mounted) setState(() => _drugs = d);
  }

  Future<void> _loadRelationPoints() async {
    final pts = await AuthService.fetchRelationPoints();
    if (mounted) setState(() => _relationPoints = pts);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _showDonateSheet(BuildContext context, dynamic app, bool dark, Color textPrimary) {
    final nameCtrl    = TextEditingController();
    final genericCtrl = TextEditingController();
    final qtyCtrl     = TextEditingController();
    final expCtrl     = TextEditingController();
    final notesCtrl   = TextEditingController();
    final cardBg = dark ? const Color(0xFF1E1E2E) : Colors.white;
    final inputBg = dark ? const Color(0xFF252540) : const Color(0xFFF5F5F5);
    final inputBorder = dark ? const Color(0xFF3A3A55) : Colors.grey.shade300;
    final hintCol = dark ? Colors.white38 : Colors.grey.shade400;
    String? selectedPharmacyId;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(innerContext).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Donate a Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(innerContext), child: Icon(Icons.close, color: dark ? Colors.white54 : Colors.grey.shade500)),
              ]),
              const SizedBox(height: 4),
              Text('Help others by donating unused medications', style: TextStyle(fontSize: 12, color: dark ? Colors.white54 : Colors.grey.shade500)),
              const SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                  return _drugs.where((drug) => (drug['name'] ?? '').toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (drug) => drug['name'] ?? '',
                onSelected: (drug) {
                  nameCtrl.text = drug['name'] ?? '';
                  genericCtrl.text = drug['generic_name'] ?? '';
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  // Sync with nameCtrl
                  textEditingController.addListener(() => nameCtrl.text = textEditingController.text);
                  return _SheetInput(ctrl: textEditingController, hint: 'Search medication...', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, focusNode: focusNode);
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(10),
                      color: dark ? const Color(0xFF1E2E45) : Colors.white,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 80),
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
              const SizedBox(height: 10),
              _SheetInput(ctrl: genericCtrl, hint: 'Generic name',         dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _SheetInput(ctrl: qtyCtrl, hint: 'Quantity *', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, type: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _SheetInput(ctrl: expCtrl, hint: 'Expiry (YYYY-MM) *', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, type: TextInputType.datetime)),
              ]),
              const SizedBox(height: 10),
              _SheetInput(ctrl: notesCtrl, hint: 'Notes (optional)', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, maxLines: 2),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedPharmacyId,
                hint: Text('Select Nearest Relation Point *', style: TextStyle(color: hintCol, fontSize: 13)),
                dropdownColor: inputBg,
                style: TextStyle(color: dark ? Colors.white : const Color(0xFF1A1A1A), fontSize: 14),
                decoration: InputDecoration(
                  filled: true, fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: inputBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: inputBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _purple, width: 1.5)),
                ),
                items: _relationPoints.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['id'].toString(),
                    child: Text('${p['name']} - ${p['city'] ?? ''}'),
                  );
                }).toList(),
                onChanged: (val) {
                  setSheetState(() => selectedPharmacyId = val);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: submitting ? null : () async {
                    if (nameCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty || selectedPharmacyId == null) {
                      ScaffoldMessenger.of(innerContext).showSnackBar(SnackBar(
                        content: const Text('Please fill all required fields and select a relation point.'),
                        backgroundColor: Colors.red.shade600,
                      ));
                      return;
                    }
                    final qty = int.tryParse(qtyCtrl.text.trim());
                    if (qty == null || qty <= 0) return;

                    // ── Expiry date validation ───────────────────────────
                    final expText = expCtrl.text.trim();
                    if (expText.isEmpty) {
                      ScaffoldMessenger.of(innerContext).showSnackBar(SnackBar(
                        content: const Text('Please enter the expiry date (YYYY-MM).'),
                        backgroundColor: Colors.red.shade600,
                      ));
                      return;
                    }
                    final expRegex = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');
                    if (!expRegex.hasMatch(expText)) {
                      ScaffoldMessenger.of(innerContext).showSnackBar(SnackBar(
                        content: const Text('Invalid date format. Use YYYY-MM (e.g. 2026-08).'),
                        backgroundColor: Colors.red.shade600,
                      ));
                      return;
                    }
                    final parts = expText.split('-');
                    final expDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
                    final now = DateTime.now();
                    final thisMonth = DateTime(now.year, now.month);
                    if (expDate.isBefore(thisMonth)) {
                      ScaffoldMessenger.of(innerContext).showSnackBar(SnackBar(
                        content: const Text('Expiry date must be in the future. Expired medications cannot be donated.'),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    // ────────────────────────────────────────────────────
                    setSheetState(() => submitting = true);
                    try {
                      final user = _sb.auth.currentUser;
                      await _sb.from('donations').insert({
                        'donor_id':        user?.id,
                        'medication_name': nameCtrl.text.trim(),
                        'generic_name':    genericCtrl.text.trim(),
                        'quantity':        qty,
                        'expiry_date':     expCtrl.text.trim().isEmpty ? null : '${expCtrl.text.trim()}-01',
                        'notes':           notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        'status':          'pending',
                        'pharmacy_id':     selectedPharmacyId,
                      });
                      if (innerContext.mounted) Navigator.pop(innerContext);
                      _fetchDonations();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Donation submitted! Thank you 💚'),
                          backgroundColor: _purple,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    } catch (e) {
                      setSheetState(() => submitting = false);
                      if (innerContext.mounted) {
                        ScaffoldMessenger.of(innerContext).showSnackBar(SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red.shade600,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                  child: submitting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Donation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchDonations() async {    setState(() => _loading = true);
    try {
      final res = await _sb
          .from('donations')
          .select('*, pharmacies!donations_reviewed_by_fkey(name, phone)')
          .eq('status', 'accepted')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _donations = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (e) {
      debugPrint('Error fetching donations with join, trying without join: $e');
      try {
        final resFallback = await _sb
            .from('donations')
            .select('*')
            .eq('status', 'accepted')
            .order('created_at', ascending: false);
        if (mounted) setState(() { _donations = List<Map<String, dynamic>>.from(resFallback); _loading = false; });
      } catch (fallbackError) {
        debugPrint('Fallback error: $fallbackError');
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app  = AppStateScope.of(context);
    final s    = AppStrings.of(app.lang);
    final dark = app.isDark;
    final scaffoldBg  = dark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final textPrimary = dark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecond  = dark ? Colors.white60 : const Color(0xFF888888);

    return Scaffold(
      backgroundColor: scaffoldBg,
      floatingActionButton: (app.isLoggedIn && app.isUser)
          ? FloatingActionButton.extended(
              onPressed: () => _showDonateSheet(context, app, dark, textPrimary),
              backgroundColor: _purple,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Donate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.donateTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 4),
            Text(s.donateSubtitle, style: TextStyle(fontSize: 13, color: textSecond)),
            const SizedBox(height: 16),
            TabBar(
              controller: _tab,
              labelColor: _purple,
              unselectedLabelColor: textSecond,
              indicatorColor: _purple,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: dark ? Colors.white12 : const Color(0xFFE0E0E0),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: [Tab(text: s.browse), Tab(text: s.myDonations)],
            ),
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            // ── Browse tab ──────────────────────────────
            _loading
              ? const Center(child: CircularProgressIndicator(color: _purple))
              : _donations.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite_outline, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 14),
                    Text('No donations available yet', style: TextStyle(color: textSecond, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('Donate a medication to help someone!', style: TextStyle(color: textSecond, fontSize: 13)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _fetchDonations,
                    color: _purple,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _donations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _DonationCard(data: _donations[i], dark: dark),
                    ),
                  ),
            // ── My Donations tab ────────────────────────
            app.isLoggedIn
              ? (app.isUser 
                  ? _MyDonationsTab(dark: dark)
                  : Center(child: Text('Only simple users can make donations.', style: TextStyle(color: textSecond, fontSize: 15))))
              : SignInRequired(dark: dark, s: s),
          ]),
        ),
      ])),
    );
  }
}

// ── My Donations (logged in users) ────────────────────────
class _MyDonationsTab extends StatefulWidget {
  final bool dark;
  const _MyDonationsTab({required this.dark});
  @override
  State<_MyDonationsTab> createState() => _MyDonationsTabState();
}

class _MyDonationsTabState extends State<_MyDonationsTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final _sb = Supabase.instance.client;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = _sb.auth.currentUser;
    if (user == null) { setState(() => _loading = false); return; }
    try {
      final res = await _sb.from('donations').select('*, pharmacies!donations_reviewed_by_fkey(name, phone)')
          .eq('donor_id', user.id).order('created_at', ascending: false);
      if (mounted) setState(() { _items = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (e) { 
      try {
        final resFallback = await _sb.from('donations').select('*')
            .eq('donor_id', user.id).order('created_at', ascending: false);
        if (mounted) setState(() { _items = List<Map<String, dynamic>>.from(resFallback); _loading = false; });
      } catch (fallbackError) {
        if (mounted) setState(() => _loading = false); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final textSecond = dark ? Colors.white60 : const Color(0xFF888888);
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
    if (_items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.medication_outlined, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
      const SizedBox(height: 14),
      Text('No donations yet', style: TextStyle(color: textSecond, fontSize: 15)),
    ]));
    }
    return RefreshIndicator(
      onRefresh: _load, color: const Color(0xFF7C3AED),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _DonationCard(data: _items[i], dark: dark, showStatus: true),
      ),
    );
  }
}

// ── Donation card ──────────────────────────────────────────
class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool dark;
  static const _purple = Color(0xFF7C3AED);
  const _DonationCard({required this.data, required this.dark, this.showStatus = false});
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final cardBg  = dark ? const Color(0xFF1E1E2E) : Colors.white;
    final divider = dark ? Colors.white12 : Colors.grey.shade100;
    final txtMain = dark ? Colors.white : const Color(0xFF1A1A1A);
    final txtSub  = dark ? Colors.white60 : const Color(0xFF888888);
    final txtDet  = dark ? Colors.white70 : const Color(0xFF555555);

    // Format expiry
    final expRaw = data['expiry_date'] as String?;
    final expLabel = expRaw != null && expRaw.length >= 7 ? 'Exp ${expRaw.substring(0, 7)}' : '';

    // Quantity label
    final qty = data['quantity'];
    final qtyLabel = qty != null ? '$qty tablet${qty == 1 ? '' : 's'}' : '';
    final status = data['status'] ?? 'pending';

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: _purple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.medication, color: _purple, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['medication_name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: txtMain)),
              const SizedBox(height: 2),
              Text(data['generic_name'] ?? '', style: TextStyle(fontSize: 12, color: txtSub)),
            ])),
            if (qtyLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(qtyLabel, style: const TextStyle(fontSize: 12, color: _purple, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        if (showStatus) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: _StatusBadge(status: status),
          ),
        ],
        Divider(height: 1, color: divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(children: [
            if (expLabel.isNotEmpty) _Row(icon: Icons.calendar_month_outlined, text: expLabel, color: txtDet),
            if (data['notes'] != null) ...[const SizedBox(height: 7), _Row(icon: Icons.info_outline, text: data['notes'], color: txtDet)],
            if (status == 'accepted' && data['pharmacies'] != null) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: divider),
              const SizedBox(height: 12),
              if (data['pharmacies']['name'] != null)
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  PharmacyLogo(size: 16, bgColor: txtDet, symbolColor: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data['pharmacies']['name'], style: TextStyle(fontSize: 13, color: txtDet))),
                ]),
              if (data['pharmacies']['phone'] != null && data['pharmacies']['phone'].toString().isNotEmpty) ...[
                const SizedBox(height: 7),
                Row(children: [
                  Icon(Icons.phone_outlined, size: 14, color: txtDet),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data['pharmacies']['phone'].toString(), style: TextStyle(fontSize: 13, color: txtDet))),
                ]),
              ],
            ]
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _Row({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
  ]);
}


class _SheetInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool dark;
  final Color inputBg, border, hintCol;
  final TextInputType? type;
  final int maxLines;
  final FocusNode? focusNode;
  const _SheetInput({required this.ctrl, required this.hint, required this.dark,
    required this.inputBg, required this.border, required this.hintCol,
    this.type, this.maxLines = 1, this.focusNode});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    focusNode: focusNode,
    keyboardType: type,
    maxLines: maxLines,
    style: TextStyle(color: dark ? Colors.white : const Color(0xFF1A1A1A), fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintCol, fontSize: 13),
      filled: true, fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'accepted':
        bgColor = const Color(0xFF2EB15B).withValues(alpha: 0.1);
        textColor = const Color(0xFF2EB15B);
        label = 'Accepted';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        bgColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red.shade600;
        label = 'Rejected';
        icon = Icons.cancel_outlined;
        break;
      default:
        bgColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        label = 'Pending Review';
        icon = Icons.pending_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: textColor),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
