import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../l10n/strings.dart';
import '../widgets/auth_widgets.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _drugs = [];
  bool _loading = true;
  static const _green = Color(0xFF2EB15B);
  final _sb = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetchRequests();
    _loadDrugs();
  }

  Future<void> _loadDrugs() async {
    final d = await AuthService.fetchDrugs();
    if (mounted) setState(() => _drugs = d);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _showRequestSheet(BuildContext context, dynamic app, bool dark, Color textPrimary) {
    final nameCtrl = TextEditingController();
    final qtyCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final msgCtrl  = TextEditingController();
    final cardBg     = dark ? const Color(0xFF1E1E2E) : Colors.white;
    final inputBg    = dark ? const Color(0xFF252540) : const Color(0xFFF5F5F5);
    final inputBorder = dark ? const Color(0xFF3A3A55) : Colors.grey.shade300;
    final hintCol    = dark ? Colors.white38 : Colors.grey.shade400;
    bool submitting  = false;

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
                Text('Request a Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(innerContext), child: Icon(Icons.close, color: dark ? Colors.white54 : Colors.grey.shade500)),
              ]),
              const SizedBox(height: 4),
              Text('Let the community know what you need', style: TextStyle(fontSize: 12, color: dark ? Colors.white54 : Colors.grey.shade500)),
              const SizedBox(height: 16),
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                  return _drugs.where((drug) => (drug['name'] ?? '').toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (drug) => drug['name'] ?? '',
                onSelected: (drug) {
                  nameCtrl.text = drug['name'] ?? '';
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  textEditingController.addListener(() => nameCtrl.text = textEditingController.text);
                  return _ReqInput(ctrl: textEditingController, hint: 'Search medication...', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, focusNode: focusNode);
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
              _ReqInput(ctrl: qtyCtrl,   hint: 'Quantity needed *', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, type: TextInputType.number),
              const SizedBox(height: 10),
              _ReqInput(ctrl: phoneCtrl, hint: 'Phone number (optional)', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, type: TextInputType.phone),
              const SizedBox(height: 10),
              _ReqInput(ctrl: msgCtrl,   hint: 'Message (optional)', dark: dark, inputBg: inputBg, border: inputBorder, hintCol: hintCol, maxLines: 2),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: submitting ? null : () async {
                    if (nameCtrl.text.trim().isEmpty || qtyCtrl.text.trim().isEmpty) return;
                    final qty = int.tryParse(qtyCtrl.text.trim());
                    if (qty == null || qty <= 0) return;
                    setSheetState(() => submitting = true);
                    try {
                      final user = _sb.auth.currentUser;
                      final meta = user?.userMetadata;
                      await _sb.from('donation_requests').insert({
                        'requester_id':   user?.id,
                        'requester_name': meta?['full_name'] ?? user?.email?.split('@')[0] ?? 'Anonymous',
                        'medication_name': nameCtrl.text.trim(),
                        'quantity_needed': qty,
                        'phone':   phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        'message': msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
                        'status':  'open',
                      });
                      if (innerContext.mounted) Navigator.pop(innerContext);
                      _fetchRequests();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Request posted! 🙏'),
                          backgroundColor: _green,
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
                      : const Text('Post Request', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchRequests() async {
    setState(() => _loading = true);
    try {
      final res = await _sb
          .from('donation_requests')
          .select()
          .eq('status', 'open')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _requests = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
              onPressed: () => _showRequestSheet(context, app, dark, textPrimary),
              backgroundColor: _green,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.requestsTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary)),
            const SizedBox(height: 4),
            Text(s.requestsSubtitle, style: TextStyle(fontSize: 13, color: textSecond)),
            const SizedBox(height: 16),
            TabBar(
              controller: _tab,
              labelColor: _green,
              unselectedLabelColor: textSecond,
              indicatorColor: _green,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: dark ? Colors.white12 : const Color(0xFFE0E0E0),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
              tabs: [Tab(text: s.browse), Tab(text: s.myRequests)],
            ),
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _tab, children: [
            // ── Browse tab ──────────────────────────────
            _loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : _requests.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.back_hand_outlined, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 14),
                    Text('No open requests yet', style: TextStyle(color: textSecond, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text('Be the first to post one!', style: TextStyle(color: textSecond, fontSize: 13)),
                  ]))
                : RefreshIndicator(
                    onRefresh: _fetchRequests,
                    color: _green,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _RequestCard(data: _requests[i], dark: dark),
                    ),
                  ),
            // ── My Requests tab ─────────────────────────
            app.isLoggedIn
              ? (app.isUser
                  ? _MyRequestsTab(dark: dark)
                  : Center(child: Text('Only simple users can make requests.', style: TextStyle(color: textSecond, fontSize: 15))))
              : SignInRequired(dark: dark, s: s),
          ]),
        ),
      ])),
    );
  }
}

// ── My Requests (logged in users) ─────────────────────────
class _MyRequestsTab extends StatefulWidget {
  final bool dark;
  const _MyRequestsTab({required this.dark});
  @override
  State<_MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<_MyRequestsTab> {
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
      final res = await _sb.from('donation_requests').select()
          .eq('requester_id', user.id).order('created_at', ascending: false);
      if (mounted) setState(() { _items = List<Map<String, dynamic>>.from(res); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final textSecond = dark ? Colors.white60 : const Color(0xFF888888);
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF2EB15B)));
    if (_items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.back_hand_outlined, size: 56, color: dark ? Colors.white24 : Colors.grey.shade300),
      const SizedBox(height: 14),
      Text('No requests yet', style: TextStyle(color: textSecond, fontSize: 15)),
    ]));
    }
    return RefreshIndicator(
      onRefresh: _load, color: const Color(0xFF2EB15B),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _RequestCard(data: _items[i], dark: dark),
      ),
    );
  }
}

// ── Request card ───────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool dark;
  static const _green = Color(0xFF2EB15B);
  const _RequestCard({required this.data, required this.dark});

  @override
  Widget build(BuildContext context) {
    final cardBg  = dark ? const Color(0xFF1E1E2E) : Colors.white;
    final divider = dark ? Colors.white12 : Colors.grey.shade100;
    final txtMain = dark ? Colors.white : const Color(0xFF1A1A1A);
    final txtDet  = dark ? Colors.white70 : const Color(0xFF555555);
    final status  = data['status'] ?? 'open';

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['medication_name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: txtMain)),
              const SizedBox(height: 3),
              Text('Needs: ${data['quantity_needed'] ?? ''}', style: TextStyle(fontSize: 12, color: txtDet.withValues(alpha: 0.7))),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(status[0].toUpperCase() + status.substring(1),
                style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        Divider(height: 1, color: divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(children: [
            _Row(icon: Icons.person_outline,   text: data['requester_name'] ?? '',  color: txtDet),
            if (data['phone'] != null)   ...[const SizedBox(height: 7), _Row(icon: Icons.phone_outlined,      text: data['phone'],   color: txtDet)],
            if (data['message'] != null) ...[const SizedBox(height: 7), _Row(icon: Icons.chat_bubble_outline, text: data['message'], color: txtDet)],
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
    Icon(icon, size: 15, color: color.withValues(alpha: 0.7)),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
  ]);
}

class _ReqInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool dark;
  final Color inputBg, border, hintCol;
  final TextInputType? type;
  final int maxLines;
  final FocusNode? focusNode;
  const _ReqInput({required this.ctrl, required this.hint, required this.dark,
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2EB15B), width: 1.5)),
    ),
  );
}
