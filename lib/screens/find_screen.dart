import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../l10n/strings.dart';
import '../widgets/pharmacy_logo.dart';

class FindScreen extends StatefulWidget {
  const FindScreen({super.key});
  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  final List<String> _meds = [];
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  final _sb    = Supabase.instance.client;

  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _searched  = false;
  List<Map<String, dynamic>> _drugs = [];
  TextEditingController? _autoCompleteCtrl;

  static const _green = Color(0xFF2EB15B);
  static const _langs = ['EN', 'FR', 'AR'];

  @override
  void initState() {
    super.initState();
    _loadDrugs();
  }

  Future<void> _loadDrugs() async {
    final d = await AuthService.fetchDrugs();
    if (mounted) setState(() => _drugs = d);
  }

  void _add() {
    final t = _autoCompleteCtrl?.text.trim() ?? _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() { _meds.add(t); _searched = false; _results = []; });
    _autoCompleteCtrl?.clear();
    _ctrl.clear();
    _focus.requestFocus();
  }

  Future<void> _search(AppStrings s) async {
    if (_meds.isEmpty) { _snack(s.addMedEmpty); return; }
    setState(() { _searching = true; _results = []; _searched = false; });

    try {
      // For each medication, find pharmacies that have it in stock
      // Then intersect — only pharmacies that have ALL meds
      final lowerMeds = _meds.map((m) => m.toLowerCase()).toList();

      // Fetch only stock rows whose medication_name matches any of the searched meds
      // Using ilike for case-insensitive partial match on the server side
      final orFilter = lowerMeds
          .map((m) => 'medication_name.ilike.%$m%,generic_name.ilike.%$m%')
          .join(',');

      // Fetch all in-stock rows matching any of the meds (case-insensitive)
      final rows = await _sb
          .from('pharmacy_stock')
          .select('*, pharmacies(id, name, address, city, phone, opening_hours)')
          .eq('in_stock', true)
          .gt('quantity', 0)
          .or(orFilter);

      final allRows = List<Map<String, dynamic>>.from(rows);

      // Group by pharmacy id
      final Map<String, Map<String, dynamic>> pharmacyMap = {};
      final Map<String, Set<String>> pharmacyMedMatches = {};

      for (final row in allRows) {
        final pharmacy = row['pharmacies'] as Map<String, dynamic>?;
        if (pharmacy == null) continue;
        final pharmId = pharmacy['id']?.toString() ?? '';
        final medName = (row['medication_name'] ?? '').toString().toLowerCase();
        final genericName = (row['generic_name'] ?? '').toString().toLowerCase();

        // Check if this stock item matches any searched med
        for (final searchMed in lowerMeds) {
          if (medName.contains(searchMed) || genericName.contains(searchMed) ||
              searchMed.contains(medName) || searchMed.contains(genericName)) {
            pharmacyMap[pharmId] = pharmacy;
            pharmacyMedMatches.putIfAbsent(pharmId, () => {}).add(searchMed);
          }
        }
      }

      // Build results: pharmacy + which meds matched + which are missing
      final List<Map<String, dynamic>> results = [];
      for (final entry in pharmacyMap.entries) {
        final matched  = entry.value;
        final hits     = pharmacyMedMatches[entry.key] ?? {};
        final missing  = lowerMeds.where((m) => !hits.contains(m)).toList();
        results.add({
          ...matched,
          'matched_meds': hits.length,
          'total_meds': lowerMeds.length,
          'missing_meds': missing,
          'has_all': missing.isEmpty,
        });
      }

      // Sort: full matches first, then by number of matches descending
      results.sort((a, b) {
        if (a['has_all'] && !b['has_all']) return -1;
        if (!a['has_all'] && b['has_all']) return 1;
        return (b['matched_meds'] as int).compareTo(a['matched_meds'] as int);
      });

      if (mounted) setState(() { _results = results; _searching = false; _searched = true; });
    } catch (e) {
      if (mounted) setState(() { _searching = false; _searched = true; });
      _snack('Search failed. Please try again.');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  @override
  Widget build(BuildContext context) {
    final app  = AppStateScope.of(context);
    final s    = AppStrings.of(app.lang);
    final dark = app.isDark;

    // ── Colour tokens ──────────────────────────────────────
    final bg           = dark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5F5);
    final cardBg       = dark ? const Color(0xFF252540) : Colors.white;
    final inputBg      = dark ? const Color(0xFF1E1E35) : Colors.white;
    final inputBorder  = dark ? const Color(0xFF3A3A55) : const Color(0xFFE0E0E0);
    final textPrimary  = dark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecond   = dark ? Colors.white60 : const Color(0xFF666666);
    final pillBg       = dark ? const Color(0xFF252540) : const Color(0xFFF0F0F0);
    final searchBtnBg  = _searching ? _green : (dark ? const Color(0xFF2EB15B) : _green);
    final howCardBg    = dark ? const Color(0xFF252540) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Top bar ──────────────────────────────────
            Row(children: [
              // Language selector
              Container(
                decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.all(3),
                child: Row(mainAxisSize: MainAxisSize.min, children: _langs.map((l) {
                  final sel = l == app.lang;
                  return GestureDetector(
                    onTap: () => app.setLang(l),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? _green : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(l, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : (dark ? Colors.white54 : Colors.black54),
                      )),
                    ),
                  );
                }).toList()),
              ),
              const Spacer(),
              // Dark mode toggle
              GestureDetector(
                onTap: () => app.toggleTheme(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(20)),
                  child: Icon(
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    size: 18, color: textPrimary,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 28),

            // ── Title ────────────────────────────────────
            Text(s.findTitle, style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w800,
              color: textPrimary, height: 1.15, letterSpacing: -0.5,
            )),
            const SizedBox(height: 10),
            Text(s.findSubtitle, style: TextStyle(fontSize: 13.5, color: textSecond, height: 1.5)),
            const SizedBox(height: 24),

            // ── Search card ──────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                // Chips
                if (_meds.isNotEmpty) ...[
                  Wrap(spacing: 8, runSpacing: 8,
                    children: _meds.asMap().entries.map((e) =>
                      _MedChip(label: e.value, onRemove: () => setState(() { _meds.removeAt(e.key); _searched = false; _results = []; }))
                    ).toList(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() { _meds.clear(); _results = []; _searched = false; }),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                // Input row
                Row(children: [
                  Expanded(
                    child: Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                        return _drugs.where((drug) => (drug['name'] ?? '').toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      displayStringForOption: (drug) => drug['name'] ?? '',
                      onSelected: (drug) {
                        _autoCompleteCtrl?.text = drug['name'] ?? '';
                        _add();
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        _autoCompleteCtrl = textEditingController;
                        return TextField(
                          controller: textEditingController, focusNode: focusNode,
                          onSubmitted: (_) => _add(),
                          style: TextStyle(fontSize: 14, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: s.addMedHint,
                            hintStyle: TextStyle(color: textSecond, fontSize: 14),
                            filled: true, fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 1.8)),
                          ),
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
                              constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width - 40 - 58),
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
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _add,
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                // Search button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _searching ? null : () => _search(s),
                    icon: _searching
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 18),
                    label: Text(
                      _searching ? s.searching(_meds.length) : s.searchBtn,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: searchBtnBg,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _green.withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ── Results ──────────────────────────────────
            if (_searched) ...[
              if (_results.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Icon(Icons.search_off, size: 48, color: dark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No pharmacies found with these medications.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecond, fontSize: 14)),
                  ]),
                )
              else ...[
                Row(children: [
                  Text('${_results.length} pharmacy${_results.length == 1 ? '' : 'ies'} found',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
                  const Spacer(),
                  Text('${_results.where((r) => r['has_all'] == true).length} full match${_results.where((r) => r['has_all'] == true).length == 1 ? '' : 'es'}',
                    style: TextStyle(fontSize: 12, color: textSecond)),
                ]),
                const SizedBox(height: 12),
                ..._results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PharmacyResultCard(data: r, dark: dark, totalMeds: _meds.length),
                )),
              ],
            ] else if (!_searching) ...[
              // ── How it works ─────────────────────────────
              Text(s.howItWorks, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: textSecond)),
              const SizedBox(height: 16),
              _HowItem(icon: Icons.description_outlined, text: s.step1, cardBg: howCardBg, dark: dark),
              const SizedBox(height: 12),
              _HowItem(icon: Icons.search,               text: s.step2, cardBg: howCardBg, dark: dark),
              const SizedBox(height: 12),
              _HowItem(icon: Icons.location_on_outlined, text: s.step3, cardBg: howCardBg, dark: dark),
            ],
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }
}

class _MedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _MedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF2EB15B).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF2EB15B).withValues(alpha: 0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF2EB15B), fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 14, color: Color(0xFF2EB15B))),
    ]),
  );
}

class _HowItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color cardBg;
  final bool dark;
  const _HowItem({required this.icon, required this.text, required this.cardBg, required this.dark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: const Color(0xFF2EB15B).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF2EB15B), size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: dark ? Colors.white : const Color(0xFF1A1A1A), fontWeight: FontWeight.w500, height: 1.4))),
    ]),
  );
}

// ── Pharmacy result card ──────────────────────────────────
class _PharmacyResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool dark;
  final int totalMeds;
  static const _green  = Color(0xFF2EB15B);
  static const _orange = Color(0xFFF59E0B);

  const _PharmacyResultCard({required this.data, required this.dark, required this.totalMeds});

  @override
  Widget build(BuildContext context) {
    final cardBg   = dark ? const Color(0xFF252540) : Colors.white;
    final txtMain  = dark ? Colors.white : const Color(0xFF1A1A1A);
    final txtSub   = dark ? Colors.white60 : const Color(0xFF888888);
    final txtDet   = dark ? Colors.white70 : const Color(0xFF555555);
    final divider  = dark ? Colors.white12 : Colors.grey.shade100;

    final hasAll    = data['has_all'] == true;
    final matched   = data['matched_meds'] as int;
    final missing   = List<String>.from(data['missing_meds'] ?? []);
    final accentCol = hasAll ? _green : _orange;
    final fraction  = totalMeds > 0 ? matched / totalMeds : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentCol.withValues(alpha: hasAll ? 0.4 : 0.2), width: hasAll ? 1.5 : 1),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(children: [
            PharmacyLogo(
              size: 46,
              bgColor: accentCol,
              borderRadius: 12,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: txtMain)),
              const SizedBox(height: 2),
              Text(data['city'] ?? '', style: TextStyle(fontSize: 12, color: txtSub)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: accentCol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(hasAll ? '✓ Full match' : '$matched/$totalMeds meds',
                style: TextStyle(fontSize: 12, color: accentCol, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // Match progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: accentCol.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(accentCol),
              minHeight: 5,
            ),
          ),
        ),

        Divider(height: 20, indent: 14, endIndent: 14, color: divider),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((data['address'] ?? '').isNotEmpty)
              _InfoRow(icon: Icons.location_on_outlined, text: data['address'], color: txtDet),
            if ((data['phone'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.phone_outlined, text: data['phone'], color: txtDet),
            ],
            if ((data['opening_hours'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.access_time_outlined, text: data['opening_hours'], color: txtDet),
            ],
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _orange.withValues(alpha: 0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, size: 14, color: _orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Missing: ${missing.join(', ')}',
                    style: const TextStyle(fontSize: 12, color: _orange, height: 1.4))),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _InfoRow({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
  ]);
}
