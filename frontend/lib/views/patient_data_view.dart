import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../main.dart';
import 'package:intl/intl.dart';

class PatientDataView extends StatefulWidget {
  final String? initialFilter;
  final String? initialAppointmentId;
  final void Function(int, [String?])? onNavigate;
  const PatientDataView({super.key, this.initialFilter, this.initialAppointmentId, this.onNavigate});
  @override
  State<PatientDataView> createState() => _PatientDataViewState();
}

class _PatientDataViewState extends State<PatientDataView> {
  List _cards = [];
  bool _loading = true;
  String _search = '';
  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshSub = globalRefresh.stream.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$apiBase/patient-cards'));
      if (res.statusCode == 200) {
        var allCards = json.decode(res.body) as List;
        // Deduplicate by patient_id (PID) - keep only first occurrence
        final Map<int, dynamic> seenPids = {};
        final deduplicatedCards = [];
        for (var card in allCards) {
          final pid = card['patient_id'] as int?;
          if (pid != null && !seenPids.containsKey(pid)) {
            seenPids[pid] = true;
            deduplicatedCards.add(card);
          }
        }
        setState(() { _cards = deduplicatedCards; _loading = false; });
        if (widget.initialAppointmentId != null) {
          final target = deduplicatedCards.firstWhere(
            (c) => c['appointment_id']?.toString() == widget.initialAppointmentId,
            orElse: () => null,
          );
          if (target != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _openDetail(target);
            });
          }
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List get _filtered {
    List list = _cards;
    if (widget.initialFilter != null && widget.initialFilter != 'all') {
      list = list.where((c) => (c['appointment_status'] ?? '').toString().toLowerCase() == widget.initialFilter!.toLowerCase()).toList();
    }
    if (_search.isEmpty) return list;
    final q = _search.toLowerCase();
    return list.where((c) =>
      (c['patient_name'] ?? '').toLowerCase().contains(q) ||
      (c['treatment_name'] ?? '').toLowerCase().contains(q) ||
      (c['patient_phone'] ?? '').toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 768;
        return Container(
          color: kBgDeep,
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 400,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Patient Data', style: GoogleFonts.outfit(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: kTextPrimary, letterSpacing: -0.5, height: 1.2)),
                SizedBox(height: 4),
                Text('Complete patient profiles — auto-created on appointment approval',
                  style: GoogleFonts.inter(fontSize: 13, color: kTextMuted, height: 1.5)),
              ]),
            ),
          ],
        ),
        SizedBox(height: 24),
        // Search
        SizedBox(
          width: isMobile ? double.infinity : 380,
          child: TextField(
            style: GoogleFonts.inter(color: kTextPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name, treatment, phone…',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(Icons.search_rounded, size: 20, color: kTextMuted),
              ),
              prefixIconConstraints: BoxConstraints(minHeight: 20, minWidth: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        SizedBox(height: 24),
        if (_loading)
          Expanded(child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5)))
        else if (_filtered.isEmpty)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: Icon(Icons.person_off_rounded, size: 48, color: kTextMuted.withValues(alpha: 0.5)),
            ),
            SizedBox(height: 20),
            Text('No patient cards yet', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary)),
            SizedBox(height: 8),
            Text('Approve an appointment to auto-generate a card.',
              style: GoogleFonts.inter(fontSize: 13, color: kTextMuted)),
          ])))
        else
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisExtent: 210,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
              ),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) => _PatientCard(
                card: _filtered[i],
                onTap: () => _openDetail(_filtered[i]),
              ),
            ),
          ),
      ]),
    );
    });
  }

  void _openDetail(Map card) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PatientDetailPage(
        cardId: card['id'] as int,
        appointmentId: card['appointment_id'] as int,
        patientId: card['patient_id'] as int,
        onNavigate: widget.onNavigate,
        onSaved: _load),
    ));
  }
}

// ── Patient Card Widget ─────────────────────────────────────
class _PatientCard extends StatefulWidget {
  final Map card;
  final VoidCallback onTap;
  const _PatientCard({required this.card, required this.onTap});
  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final status = (c['appointment_status'] ?? '').toString();
    final Color statusColor = _statusColor(status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: _hovered ? (Matrix4.identity()..translate(0.0, -2.0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? kAccent.withValues(alpha: 0.5) : kBorder,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
              ? [BoxShadow(color: kAccent.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6)),
                 BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [kAccent.withValues(alpha: 0.2), kAccent.withValues(alpha: 0.08)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAccent.withValues(alpha: 0.15)),
                ),
                child: Center(child: Text(
                  (c['patient_name'] ?? '?')[0].toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: kAccent),
                )),
              ),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['patient_name'] ?? '—',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700,
                    color: kTextPrimary, height: 1.3),
                  overflow: TextOverflow.ellipsis),
                SizedBox(height: 2),
                Text(
                  [
                    if (c['patient_uid'] != null && c['patient_uid'].toString().isNotEmpty) c['patient_uid'],
                    if (c['patient_phone'] != null && c['patient_phone'].toString().isNotEmpty) c['patient_phone']
                  ].join(' • '),
                  style: GoogleFonts.inter(fontSize: 11, color: kTextMuted, letterSpacing: 0.2),
                ),
              ])),
            ]),
            SizedBox(height: 16),
            _infoRow(Icons.medical_services_rounded, c['treatment_name'] ?? '—'),
            SizedBox(height: 8),
            _infoRow(Icons.calendar_today_rounded, c['appointment_date'] ?? '—'),
            const Spacer(),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(status.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
              ),
              SizedBox(width: 8),
              Row(
                children: ((c['images'] as List?) ?? []).take(4).map((img) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: kBorder, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          img['image_data'],
                          width: 22, height: 22, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 22, height: 22, color: kSurfaceAlt,
                            child: Icon(Icons.broken_image_rounded, size: 12, color: kTextMuted),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              Icon(Icons.photo_library_rounded, size: 14, color: kTextMuted.withValues(alpha: 0.6)),
              SizedBox(width: 4),
              Text('${(c['images'] as List?)?.length ?? 0}',
                style: GoogleFonts.inter(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [
    Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kBgDeep,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 12, color: kTextMuted),
    ),
    SizedBox(width: 8),
    Expanded(child: Text(text,
      style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary, height: 1.4),
      overflow: TextOverflow.ellipsis)),
  ]);

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed': return kAccent;
      case 'cleared': return kSuccess;
      case 'completed': return const Color(0xFF22C55E);
      case 'testing': return kInfo;
      case 'not_cleared': return kDanger;
      case 'canceled': return kDanger;
      default: return kWarning;
    }
  }
}

// ── Patient Detail Page ─────────────────────────────────────
class _PatientDetailPage extends StatefulWidget {
  final int cardId;
  final int appointmentId;
  final int patientId;
  final VoidCallback onSaved;
  final void Function(int, [String?])? onNavigate;
  const _PatientDetailPage({
    required this.cardId,
    required this.appointmentId,
    required this.patientId,
    required this.onSaved,
    this.onNavigate,
  });
  @override
  State<_PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<_PatientDetailPage> with SingleTickerProviderStateMixin {
  Map? _card;
  bool _loading = true;
  bool _saving = false;
  late TabController _tab;

  // Lab results for this patient's appointment
  List _labResults = [];

  // Prescription for this patient's appointment
  bool _labSaving = false;
  bool _prescSaving = false;
  final _treatCtrl    = TextEditingController();
  final _medCtrl      = TextEditingController();
  final _prescNotes   = TextEditingController();
  final _labNotesCtrl = TextEditingController();

  // Reports for this patient
  List _patientReports = [];

  bool _isEditingInfo = false;
  bool _isEditingLab = false;
  bool _isEditingPresc = false;
  final bool _isEditingReport = false;
  final _reportSummaryCtrl = TextEditingController();

  // Form fields
  final _ageCtrl        = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _addressCtrl    = TextEditingController();
  final _allergyCtrl    = TextEditingController();
  final _historyCtrl    = TextEditingController();
  final _emergencyCtrl  = TextEditingController();
  final _notesCtrl      = TextEditingController();
  final _patientUidCtrl = TextEditingController();
  String _gender = '';
  String _blood  = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
    _loadLabResults();
    _loadPrescription();
    _loadReports();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [_ageCtrl, _emailCtrl, _addressCtrl, _allergyCtrl,
        _historyCtrl, _emergencyCtrl, _notesCtrl, _patientUidCtrl,
        _treatCtrl, _medCtrl, _prescNotes, _labNotesCtrl, _reportSummaryCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('$apiBase/patient-cards/${widget.cardId}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map;
        setState(() {
          _card = data;
          _ageCtrl.text       = data['age'] ?? '';
          _emailCtrl.text     = data['email'] ?? '';
          _addressCtrl.text   = data['address'] ?? '';
          _allergyCtrl.text   = data['allergies'] ?? '';
          _historyCtrl.text   = data['medical_history'] ?? '';
          _emergencyCtrl.text = data['emergency_contact'] ?? '';
          _notesCtrl.text     = data['notes'] ?? '';
          _patientUidCtrl.text = data['patient_uid'] ?? '';
          _gender = data['gender'] ?? '';
          _blood  = data['blood_group'] ?? '';
          _isEditingInfo = (data['age'] == null || data['age'].toString().isEmpty);
          _loading = false;
        });
      }
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadLabResults() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/appointments/${widget.appointmentId}/lab-results'));
      if (res.statusCode == 200 && mounted) {
        final body = json.decode(res.body);
        setState(() {
          _labResults = List<Map<String, dynamic>>.from(body['results'] ?? body);
          _labNotesCtrl.text = body['lab_notes'] ?? '';
          _isEditingLab = _labResults.isEmpty || _labResults.every((r) => r['is_fit'] == null);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLabResults() async {
    setState(() => _labSaving = true);
    final resultsToSave = _labResults.map((r) => {
      'test_id': r['test_id'],
      'is_fit': r['is_fit']
    }).toList();
    
    await http.post(
      Uri.parse('$apiBase/appointments/${widget.appointmentId}/lab-results'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'results': resultsToSave,
        'lab_notes': _labNotesCtrl.text,
      }),
    );
    
    setState(() => _labSaving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lab Reports saved successfully!'), backgroundColor: kSuccess));

    // Check if ALL lab results are now assessed (fit or unfit)
    final allAssessed = _labResults.isNotEmpty && _labResults.every((r) => r['is_fit'] != null);
    if (!allAssessed) return;

    // Show "Proceed to treatment?" confirmation dialog
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle_rounded, color: kSuccess, size: 28),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('All Tests Assessed', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 18))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('All lab results have been evaluated.', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 14)),
          SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBgDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              Icon(Icons.science_rounded, color: kInfo, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Fit: ${_labResults.where((r) => r['is_fit'] == 1).length}  •  Not Fit: ${_labResults.where((r) => r['is_fit'] == 0).length}  •  Total: ${_labResults.length}',
                style: GoogleFonts.inter(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              )),
            ]),
          ),
          SizedBox(height: 16),
          Text('Would you like to proceed to treatment evaluation?', style: GoogleFonts.inter(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not Now', style: GoogleFonts.inter(color: kTextMuted, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kSuccess,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text('Proceed to Treatment', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    // Call the evaluate endpoint
    final evalRes = await http.put(
      Uri.parse('$apiBase/appointments/${widget.appointmentId}/evaluate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'lab_notes': _labNotesCtrl.text}),
    );
    if (!mounted) return;
    final evalData = json.decode(evalRes.body);
    if (evalData['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(evalData['error']), backgroundColor: kDanger),
      );
      return;
    }

    final isCleared = evalData['status'] == 'cleared';

    if (isCleared) {
      // Show treatment date picker
      if (!mounted) return;
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        helpText: 'SELECT TREATMENT DATE',
      );
      if (pickedDate != null && mounted) {
        await http.put(
          Uri.parse('$apiBase/appointments/${widget.appointmentId}/reschedule'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'date': DateFormat('yyyy-MM-dd').format(pickedDate)}),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Patient CLEARED! Testing completed.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // Navigate back and go to Appointments tab (cleared filter)
      if (mounted) {
        Navigator.pop(context);
        widget.onNavigate?.call(1, 'cleared');
      }
    } else {
      // Not cleared
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(Icons.cancel, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Patient NOT CLEARED — ${evalData['failed']} test(s) failed.', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          ]),
          backgroundColor: kDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
      await _loadLabResults();
    }
  }

  Future<void> _loadPrescription() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/appointments/${widget.appointmentId}/prescription'));
      if (res.statusCode == 200 && mounted) {
        final d = json.decode(res.body) as Map;
        setState(() {
          _treatCtrl.text  = d['treatment_details'] ?? '';
          _medCtrl.text    = d['medicines'] ?? '';
          _prescNotes.text = d['comments'] ?? '';
          _isEditingPresc = _treatCtrl.text.isEmpty && _medCtrl.text.isEmpty && _prescNotes.text.isEmpty;
        });
      } else if (res.statusCode == 404 && mounted) {
        setState(() {
          _isEditingPresc = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePrescription() async {
    setState(() => _prescSaving = true);
    final res = await http.post(
      Uri.parse('$apiBase/appointments/${widget.appointmentId}/prescription'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'treatment_details': _treatCtrl.text, 'medicines': _medCtrl.text, 'comments': _prescNotes.text}),
    );
    setState(() => _prescSaving = false);
    if (!mounted) return;
    final d = json.decode(res.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(d['error'] ?? 'Prescription saved successfully!'),
      backgroundColor: d['error'] != null ? kDanger : kSuccess));
    _loadPrescription();
  }

  Future<void> _loadReports() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/reports'));
      if (res.statusCode == 200 && mounted) {
        final List all = json.decode(res.body);
        setState(() {
          _patientReports = all.where((r) => r['patient_id'] == widget.patientId).toList();
          final summaryReport = _patientReports.where((r) => r['report_name'] == 'Consolidated Treatment Summary').firstOrNull;
          if (summaryReport != null && !_isEditingReport) {
            _reportSummaryCtrl.text = summaryReport['notes'] ?? '';
          }
        });
      }
    } catch (_) {}
  }


  Future<void> _save() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Save', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: kTextPrimary)),
        content: Text('Are you sure you want to save the changes to the patient card?', style: GoogleFonts.inter(color: kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: kTextMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text('Save')
          ),
        ],
      )
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    final res = await http.put(
      Uri.parse('$apiBase/patient-cards/${widget.cardId}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'patient_uid': _patientUidCtrl.text,
        'age': _ageCtrl.text, 'gender': _gender, 'email': _emailCtrl.text,
        'address': _addressCtrl.text, 'blood_group': _blood,
        'allergies': _allergyCtrl.text, 'medical_history': _historyCtrl.text,
        'emergency_contact': _emergencyCtrl.text, 'notes': _notesCtrl.text,
      }),
    );
    
    setState(() => _saving = false);

    if (res.statusCode == 400) {
      final errorData = json.decode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorData['error'] ?? 'Error updating card'), backgroundColor: kDanger));
      }
      return;
    }

    setState(() {
      _isEditingInfo = false;
    });
    await _load();
    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Patient Info saved successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
          backgroundColor: kSuccess,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height / 2,
            left: MediaQuery.of(context).size.width / 4,
            right: MediaQuery.of(context).size.width / 4,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )
      );
    }
  }

  Future<void> _addImage(String type) async {
    // Choose upload method
    final choice = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      title: Text('Add ${type[0].toUpperCase()}${type.substring(1)} Photo', style: TextStyle(color: kTextPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ElevatedButton.icon(
          icon: Icon(Icons.upload_file_rounded, size: 18),
          label: Text('Upload from Device'),
          style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, 'local')),
        SizedBox(height: 12),
        OutlinedButton.icon(
          icon: Icon(Icons.link_rounded, size: 18),
          label: Text('Enter Image URL'),
          style: OutlinedButton.styleFrom(foregroundColor: kAccent, side: BorderSide(color: kAccent.withValues(alpha: 0.5))),
          onPressed: () => Navigator.pop(ctx, 'url')),
        SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text('Cancel')),
      ]),
    ));
    if (choice == null) return;
    if (choice == 'local') {
      final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
      uploadInput.click();
      await uploadInput.onChange.first;
      if (uploadInput.files == null || uploadInput.files!.isEmpty) return;
      final reader = html.FileReader();
      reader.readAsDataUrl(uploadInput.files!.first);
      await reader.onLoad.first;
      final dataUrl = reader.result as String;
      await _showLabelDialog(dataUrl, type);
    } else {
      final urlCtrl = TextEditingController();
      final labelCtrl = TextEditingController();
      final annotCtrl = TextEditingController();
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text('Enter Image URL', style: TextStyle(color: kTextPrimary)),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: urlCtrl, style: TextStyle(color: kTextPrimary),
            decoration: InputDecoration(labelText: 'Image URL (https://…)')),
          SizedBox(height: 12),
          TextField(controller: labelCtrl, style: TextStyle(color: kTextPrimary),
            decoration: InputDecoration(labelText: 'Label (optional)')),
          SizedBox(height: 12),
          TextField(controller: annotCtrl, style: TextStyle(color: kTextPrimary), maxLines: 2,
            decoration: InputDecoration(labelText: 'Annotation / Notes')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Add')),
        ],
      ));
      if (ok == true && urlCtrl.text.isNotEmpty) {
        final label = [labelCtrl.text, annotCtrl.text].where((s) => s.isNotEmpty).join(' | ');
        final res = await http.post(Uri.parse('$apiBase/patient-cards/${widget.cardId}/images'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'image_data': urlCtrl.text, 'image_type': type, 'label': label}));
        if (res.statusCode != 200) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add image. It may be too large or an invalid URL.'), backgroundColor: kDanger));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image saved successfully!'), backgroundColor: kSuccess));
        }
        _load();
      }
    }
  }

  Future<void> _showLabelDialog(String dataUrl, String type) async {
    final labelCtrl = TextEditingController();
    final annotCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      title: Text('Label & Annotation', style: TextStyle(color: kTextPrimary)),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: labelCtrl, style: TextStyle(color: kTextPrimary),
          decoration: InputDecoration(labelText: 'Label (optional)')),
        SizedBox(height: 12),
        TextField(controller: annotCtrl, style: TextStyle(color: kTextPrimary), maxLines: 2,
          decoration: InputDecoration(labelText: 'Annotation / Notes')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Upload')),
      ],
    ));
    if (ok == true) {
      final label = [labelCtrl.text, annotCtrl.text].where((s) => s.isNotEmpty).join(' | ');
      final res = await http.post(Uri.parse('$apiBase/patient-cards/${widget.cardId}/images'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'image_data': dataUrl, 'image_type': type, 'label': label}));
      if (res.statusCode != 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image. File may be too large.'), backgroundColor: kDanger));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image saved successfully!'), backgroundColor: kSuccess));
      }
      _load();
    }
  }

  Future<void> _deleteImage(int imgId) async {
    await http.delete(Uri.parse('$apiBase/patient-cards/${widget.cardId}/images/$imgId'));
    _load();
  }

  Widget _prescField(String label, String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool isEmpty = value.text.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: kTextPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            SizedBox(height: 8),
            TextField(
              controller: ctrl,
              minLines: maxLines,
              maxLines: maxLines == 1 ? 1 : null,
              style: GoogleFonts.inter(color: kTextPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(color: kTextMuted.withValues(alpha: 0.6), fontSize: 14, fontStyle: FontStyle.italic),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                filled: true,
                fillColor: isEmpty 
                    ? (ThemeManager.isDark.value ? const Color(0xFF1E2530) : const Color(0xFFF1F5F9))
                    : (ThemeManager.isDark.value ? const Color(0xFF0D1117) : const Color(0xFFE2E8F0)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isEmpty 
                        ? (ThemeManager.isDark.value ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1))
                        : kBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: kAccent, width: 1.5),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: kBgDeep,
      appBar: AppBar(title: Text('Patient Details')),
      body: Center(child: CircularProgressIndicator(color: kAccent)));

    final card = _card!;
    final images = (card['images'] as List?) ?? [];
    final beforeImages = images.where((i) => (i['image_type']?.toString().toLowerCase() ?? '') == 'before').toList();
    final afterImages  = images.where((i) => (i['image_type']?.toString().toLowerCase() ?? '') == 'after').toList();

    return Scaffold(
      backgroundColor: kBgDeep,
      appBar: AppBar(
        title: Text(card['patient_name'] ?? 'Patient Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: kTextPrimary)),
        backgroundColor: kBgDark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: kTextPrimary),
          onPressed: () => Navigator.pop(context)),
        actions: [
          if (_saving || _labSaving || _prescSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: kAccent, strokeWidth: 2),
                ),
              ),
            )
          else ...[
            if (_tab.index == 0 && _isEditingInfo)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: Text('Save Info', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _save,
                  ),
                ),
              )
            else if (_tab.index == 2 && _isEditingLab && _labResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: Text('Save Lab', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      await _saveLabResults();
                      setState(() {
                        _isEditingLab = false;
                      });
                    },
                  ),
                ),
              )
            else if (_tab.index == 3 && _isEditingPresc)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: Text('Save Prescription', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () async {
                      await _savePrescription();
                      setState(() {
                        _isEditingPresc = false;
                      });
                    },
                  ),
                ),
              ),
          ],
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: kAccent,
          unselectedLabelColor: kTextMuted,
          indicatorColor: kAccent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
          tabs: [
            Tab(icon: Icon(Icons.person_rounded, size: 18), text: 'Patient Info'),
            Tab(icon: Icon(Icons.compare_rounded, size: 18), text: 'Before / After'),
            Tab(icon: Icon(Icons.science_rounded, size: 18), text: 'Lab Reports'),
            Tab(icon: Icon(Icons.medication_rounded, size: 18), text: 'Prescriptions'),
            Tab(icon: Icon(Icons.summarize_rounded, size: 18), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        // ── Tab 1: Patient Info ──
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kBgDeep,
                        border: Border.all(color: kAccent.withValues(alpha: 0.4), width: 2),
                        boxShadow: [
                          BoxShadow(color: kAccent.withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 4)
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (_card?['patient_name'] ?? '?').toString().isNotEmpty ? (_card?['patient_name'] ?? '?')[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: kAccent),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Personal Information', style: GoogleFonts.outfit(
                            fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary)),
                          SizedBox(height: 4),
                          Text('Manage patient details and medical profile',
                            style: GoogleFonts.inter(fontSize: 13, color: kTextMuted)),
                        ],
                      ),
                    ),
                    if (!_isEditingInfo)
                      _EditButtonHover(onTap: () => setState(() => _isEditingInfo = true)),
                  ],
                ),
                SizedBox(height: 32),
                if (_isEditingInfo) ...[
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _field('Age', _ageCtrl, keyboardType: TextInputType.number)),
                      SizedBox(width: 16),
                      Expanded(child: _dropdown('Gender', ['', 'Male', 'Female', 'Other'], _gender,
                        (v) => setState(() => _gender = v ?? ''))),
                    ]),
                  ),
                  SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _field('Email', _emailCtrl)),
                      SizedBox(width: 16),
                      Expanded(child: _dropdown('Blood Group', ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                        _blood, (v) => setState(() => _blood = v ?? ''))),
                    ]),
                  ),
                  SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _field('Emergency Contact', _emergencyCtrl)),
                      SizedBox(width: 16),
                      Expanded(child: _field('Patient ID', _patientUidCtrl)),
                    ]),
                  ),
                  SizedBox(height: 16),
                  _field('Address', _addressCtrl, maxLines: 2),
                  SizedBox(height: 16),
                  _field('Medical History', _historyCtrl, maxLines: 3),
                ] else ...[
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _infoDisplay('Age', _ageCtrl.text)),
                      SizedBox(width: 16),
                      Expanded(child: _infoDisplay('Gender', _gender)),
                    ]),
                  ),
                  SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _infoDisplay('Email', _emailCtrl.text)),
                      SizedBox(width: 16),
                      Expanded(child: _infoDisplay('Blood Group', _blood)),
                    ]),
                  ),
                  SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _infoDisplay('Emergency Contact', _emergencyCtrl.text)),
                      SizedBox(width: 16),
                      Expanded(child: _infoDisplay('Patient ID', (_card?['patient_uid'] ?? '').toString())),
                    ]),
                  ),
                  SizedBox(height: 16),
                  _infoDisplay('Address', _addressCtrl.text),
                  SizedBox(height: 16),
                  _infoDisplay('Medical History', _historyCtrl.text),
                ],
              ]),
            ),
          ]),
        ),

        // ── Tab 2: Before / After ──
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _imageSection('Before Photos', beforeImages, 'before'),
            SizedBox(height: 24),
            _imageSection('After Photos', afterImages, 'after'),
          ]),
        ),

        // ── Tab 3: Lab Reports ──
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lab Reports', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
                    SizedBox(height: 4),
                    Text('Evaluate and record lab results for this patient\'s appointment', style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
                  ],
                ),
                if (!_isEditingLab && _labResults.isNotEmpty)
                  _EditButtonHover(onTap: () => setState(() => _isEditingLab = true)),
              ],
            ),
            SizedBox(height: 16),
            if (_labResults.isEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
                child: Column(children: [
                  Icon(Icons.science_outlined, size: 40, color: kTextMuted),
                  SizedBox(height: 8),
                  Text('No lab results found for this appointment', style: TextStyle(color: kTextMuted)),
                ]),
              )
            else
              Container(
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._labResults.asMap().entries.map((entry) {
                      final i = entry.key;
                      final r = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r['test_name'] ?? '', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600)),
                            Text(r['unit'] ?? '', style: TextStyle(color: kTextMuted, fontSize: 11)),
                          ])),
                          Expanded(flex: 2, child: Text(
                            '${r['normal_min'] ?? ''} – ${r['normal_max'] ?? ''}',
                            style: TextStyle(color: kTextSecondary, fontSize: 12))),
                          
                          // Toggle buttons in edit mode, read-only badges in saved mode
                          if (_isEditingLab)
                            SegmentedButton<int?>(
                              emptySelectionAllowed: true,
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(value: 1, label: Text('FIT ✓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                ButtonSegment(value: 0, label: Text('NOT FIT ✗', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              ],
                              selected: { r['is_fit'] },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return r['is_fit'] == 1 ? kSuccess.withValues(alpha: 0.15) : kDanger.withValues(alpha: 0.15);
                                  }
                                  return Colors.transparent;
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return r['is_fit'] == 1 ? kSuccess : kDanger;
                                  }
                                  return kTextMuted;
                                }),
                              ),
                              onSelectionChanged: (set) {
                                setState(() => _labResults[i]['is_fit'] = set.isEmpty ? null : set.first);
                              },
                            )
                          else
                            _buildReadOnlyBadge(r['is_fit']),
                        ]),
                      );
                    }).toList(),
                    SizedBox(height: 24),
                    if (_isEditingLab) ...[
                      Text('Comments / Admin Notes', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 8),
                      TextField(
                        controller: _labNotesCtrl,
                        maxLines: 3,
                        style: TextStyle(color: kTextPrimary),
                        decoration: InputDecoration(
                          hintText: 'Enter optional admin notes here...',
                          filled: true,
                          fillColor: kBgDeep,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
                        ),
                      ),
                    ] else ...[
                      _infoDisplay('Comments / Admin Notes', _labNotesCtrl.text),
                    ],
                  ],
                ),
              ),
          ]),
        ),

        // ── Tab 4: Prescriptions ──
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prescriptions', style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
                    SizedBox(height: 4),
                    Text('Create or update this patient\'s prescription',
                      style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
                  ],
                ),
                if (!_isEditingPresc)
                  _EditButtonHover(onTap: () => setState(() => _isEditingPresc = true)),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
              child: _isEditingPresc
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _prescField('Treatment Details',
                      'Treatment performed, procedure notes…', _treatCtrl, maxLines: 4),
                    SizedBox(height: 16),
                    _prescField('Prescribed Medicines',
                      'Medicine name, dosage, frequency…', _medCtrl, maxLines: 4),
                    SizedBox(height: 16),
                    _prescField('Comments / Notes',
                      'Follow-up instructions, recommendations…', _prescNotes, maxLines: 3),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _infoDisplay('Treatment Details', _treatCtrl.text),
                    SizedBox(height: 16),
                    _infoDisplay('Prescribed Medicines', _medCtrl.text),
                    SizedBox(height: 16),
                    _infoDisplay('Comments / Notes', _prescNotes.text),
                  ]),
            ),
          ]),
        ),

        // ── Tab 5: Reports ──
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hair Transplant Discharge Summary', style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
                      SizedBox(height: 4),
                      Text('Generate and manage standard discharge summary PDFs for hair transplant patients.',
                        style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.add_rounded, size: 16),
                  label: Text('Generate Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _showDischargeSummaryDialog,
                ),
              ]
            ),
            SizedBox(height: 24),
            
            // List of existing reports
            ..._patientReports.where((r) => r['report_name'] == 'Hair Transplant Discharge Summary').map((report) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_rounded, color: kAccent, size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discharge Summary', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextPrimary)),
                          SizedBox(height: 2),
                          Text('Patient ID: ${_card?['patient_uid'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
                          Text('Generated on: ${report['uploaded_at'] ?? '-'}', style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
                        ]
                      )
                    ),
                    OutlinedButton.icon(
                      icon: Icon(Icons.download_rounded, size: 16),
                      label: Text('Download PDF'),
                      style: OutlinedButton.styleFrom(foregroundColor: kAccent, side: BorderSide(color: kBorder)),
                      onPressed: () {
                        try {
                          final data = json.decode(report['notes']);
                          final medsRaw = data['medications'] ?? [];
                          final List<dynamic> parsedMeds = medsRaw is List ? medsRaw : [];
                          _generateDischargePdf(
                            doctor: data['doctor'] ?? '',
                            diagnosis: data['diagnosis'] ?? '',
                            treatmentType: data['treatmentType'] ?? '',
                            donorArea: data['donorArea'] ?? '',
                            grafts: data['grafts'] ?? '',
                            sites: data['sites'] ?? '',
                            anesthesia: data['anesthesia'] ?? '',
                            medications: parsedMeds,
                          );
                        } catch(e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF'), backgroundColor: kDanger));
                        }
                      },
                    )
                  ]
                )
              );
            }).toList(),
            if (_patientReports.where((r) => r['report_name'] == 'Hair Transplant Discharge Summary').isEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
                child: Column(children: [
                  Icon(Icons.folder_open_rounded, size: 40, color: kTextMuted),
                  SizedBox(height: 8),
                  Text('No discharge summaries generated yet', style: TextStyle(color: kTextMuted)),
                ]),
              )
          ]),
        ),
      ]),
    );
  }

  void _showDischargeSummaryDialog() {
    final doctorCtrl = TextEditingController();
    final diagnosisCtrl = TextEditingController();
    final donorCtrl = TextEditingController();
    final graftsCtrl = TextEditingController();
    final sitesCtrl = TextEditingController();
    final anesthesiaCtrl = TextEditingController();
    String treatmentType = '';
    bool saving = false;

    List<Map<String, TextEditingController>> medications = [
      {
        'medicine': TextEditingController(),
        'dosage': TextEditingController(),
        'duration': TextEditingController(),
        'remarks': TextEditingController(),
      }
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Discharge Summary Details', style: GoogleFonts.outfit(color: kTextPrimary, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Procedure Info', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kAccent)),
                  SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _field('Consultant Doctor', doctorCtrl)),
                    SizedBox(width: 12),
                    Expanded(child: _field('Diagnosis', diagnosisCtrl)),
                  ]),
                  SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _dropdown('Type of Treatment', ['', 'FUE', 'FUT', 'DHI'], treatmentType, (v) => ss(() => treatmentType = v ?? ''))),
                    SizedBox(width: 12),
                    Expanded(child: _field('Donor Area', donorCtrl)),
                  ]),
                  SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _field('Number of Grafts', graftsCtrl, keyboardType: TextInputType.number)),
                    SizedBox(width: 12),
                    Expanded(child: _field('Implantation Sites', sitesCtrl)),
                  ]),
                  SizedBox(height: 12),
                  _field('Anesthesia', anesthesiaCtrl),
                  SizedBox(height: 24),
                  Text('Discharge Medications', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kAccent)),
                  SizedBox(height: 8),
                  ...medications.asMap().entries.map((entry) {
                    final index = entry.key;
                    final med = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: _field('Medicine', med['medicine']!)),
                          SizedBox(width: 8),
                          Expanded(flex: 2, child: _field('Dosage', med['dosage']!)),
                          SizedBox(width: 8),
                          Expanded(flex: 2, child: _field('Duration', med['duration']!)),
                          SizedBox(width: 8),
                          Expanded(flex: 2, child: _field('Remarks', med['remarks']!)),
                          SizedBox(width: 4),
                          Container(
                            margin: const EdgeInsets.only(top: 24),
                            child: IconButton(
                              icon: Icon(Icons.remove_circle_outline, color: kDanger, size: 20),
                              onPressed: medications.length > 1 ? () {
                                ss(() {
                                  medications.removeAt(index);
                                });
                              } : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  TextButton.icon(
                    icon: Icon(Icons.add_rounded, size: 16),
                    label: Text('Add Medication'),
                    onPressed: () {
                      ss(() {
                        medications.add({
                          'medicine': TextEditingController(),
                          'dosage': TextEditingController(),
                          'duration': TextEditingController(),
                          'remarks': TextEditingController(),
                        });
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: kTextMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white),
              onPressed: saving ? null : () async {
                ss(() => saving = true);
                final data = {
                  'doctor': doctorCtrl.text,
                  'diagnosis': diagnosisCtrl.text,
                  'treatmentType': treatmentType,
                  'donorArea': donorCtrl.text,
                  'grafts': graftsCtrl.text,
                  'sites': sitesCtrl.text,
                  'anesthesia': anesthesiaCtrl.text,
                  'medications': medications.map((m) => {
                    'medicine': m['medicine']!.text,
                    'dosage': m['dosage']!.text,
                    'duration': m['duration']!.text,
                    'remarks': m['remarks']!.text,
                  }).where((m) => m['medicine']!.isNotEmpty).toList(),
                };
                
                await http.post(Uri.parse('$apiBase/reports'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'patient_id': widget.patientId, 'report_name': 'Hair Transplant Discharge Summary', 'notes': json.encode(data)})
                );
                
                await _loadReports();
                if (mounted) Navigator.pop(ctx);
              },
              child: saving 
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : Text('Save & Generate Report')
            ),
          ],
        )
      )
    );
  }

  Future<void> _generateDischargePdf({
    required String doctor,
    required String diagnosis,
    required String treatmentType,
    required String donorArea,
    required String grafts,
    required String sites,
    required String anesthesia,
    required List<dynamic> medications,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Text('Hair Transplant Discharge Summary', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 30),
            
            // Patient Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Patient Name: ${_card?['patient_name'] ?? '-'}'),
                    pw.Text('Age/Gender: ${_card?['age'] ?? '-'}/${_card?['gender'] ?? '-'}'),
                    pw.Text('Patient ID: ${_card?['patient_uid'] ?? '-'}'),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date of Procedure: ${_card?['appointment_date'] ?? '-'}'),
                  ]
                ),
              ]
            ),
            pw.SizedBox(height: 15),
            pw.Text('Consultant Doctor: $doctor'),
            pw.Text('Diagnosis: $diagnosis'),
            pw.SizedBox(height: 25),
            
            // Clinical Summary
            pw.Text('Clinical Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            
            pw.Text('Procedure Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('- Type of Treatment: $treatmentType'),
            pw.Text('- Donor Area: $donorArea'),
            pw.Text('- Number of Grafts Harvested: $grafts follicular units'),
            pw.Text('- Implantation Sites: $sites'),
            pw.Text('- Anesthesia: $anesthesia'),
            pw.SizedBox(height: 15),
            
            pw.Text('Condition at Discharge', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('- Patient stable, afebrile'),
            pw.Text('- Donor site dressed, no active bleeding'),
            pw.SizedBox(height: 15),
            
            // Medications
            pw.Text('Discharge Medications', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            medications.isEmpty 
              ? pw.Text('No medications prescribed.')
              : pw.Table.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  cellAlignment: pw.Alignment.centerLeft,
                  headers: ['Medicine', 'Dosage', 'Duration', 'Remarks'],
                  data: medications.map((m) => [
                    m['medicine']?.toString() ?? '', 
                    m['dosage']?.toString() ?? '', 
                    m['duration']?.toString() ?? '', 
                    m['remarks']?.toString() ?? ''
                  ]).toList(),
                ),
            pw.SizedBox(height: 15),
            
            // Instructions
            pw.Text('Post Procedure Instructions', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('- Avoid touching or scratching the transplanted area'),
            pw.Text('- Sleep with head elevated for 3 nights to reduce swelling'),
            pw.SizedBox(height: 15),
            
            // Follow Up
            pw.Text('Follow Up Visit', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('- Follow Up Visit Date: After 3 days of procedure'),
            pw.Text('- Purpose of Visit: Suture removal, graft evaluation, and progress check.'),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Discharge_Summary_${_card?['patient_name'] ?? 'Patient'}.pdf'
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (context, value, _) {
        final bool isEmpty = value.text.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            TextField(
              controller: ctrl,
              keyboardType: keyboardType,
              minLines: maxLines,
              maxLines: maxLines == 1 ? 1 : null,
              style: GoogleFonts.inter(color: kTextPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter $label...',
                hintStyle: GoogleFonts.inter(color: kTextMuted.withValues(alpha: 0.6), fontSize: 13, fontStyle: FontStyle.italic),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: maxLines == 1 ? 10 : 12),
                filled: true,
                fillColor: isEmpty 
                    ? (ThemeManager.isDark.value ? const Color(0xFF1E2530) : const Color(0xFFF1F5F9))
                    : (ThemeManager.isDark.value ? const Color(0xFF0D1117) : const Color(0xFFE2E8F0)),
                hoverColor: kSurfaceAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isEmpty 
                        ? (ThemeManager.isDark.value ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1))
                        : kBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: kAccent, width: 1.5),
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _infoDisplay(String label, String value) {
    final bool isEmpty = value.isEmpty || value == '—';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEmpty 
            ? (ThemeManager.isDark.value ? const Color(0x0AFFFFFF) : const Color(0x05000000))
            : (ThemeManager.isDark.value ? const Color(0xFF161B24) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEmpty 
              ? (ThemeManager.isDark.value ? const Color(0x11FFFFFF) : const Color(0xFFE2E8F0))
              : (ThemeManager.isDark.value ? kAccent.withValues(alpha: 0.25) : const Color(0xFFCBD5E1)),
          width: 1.5,
        ),
        boxShadow: isEmpty ? [] : [
          BoxShadow(color: kAccent.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.inter(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w500)),
              if (!isEmpty)
                Icon(Icons.lock_outline_rounded, size: 12, color: kTextMuted.withValues(alpha: 0.6)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            isEmpty ? 'Not Provided' : value,
            style: GoogleFonts.inter(
              color: isEmpty 
                  ? kTextMuted 
                  : (ThemeManager.isDark.value ? Colors.white : const Color(0xFF0F172A)),
              fontSize: 15,
              fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    final bool isEmpty = value.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value.isEmpty ? '' : value,
          dropdownColor: kSurfaceAlt,
          style: GoogleFonts.inter(color: kTextPrimary, fontSize: 13),
          icon: Icon(Icons.arrow_drop_down, color: kTextMuted, size: 20),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: isEmpty 
                ? (ThemeManager.isDark.value ? const Color(0xFF1E2530) : const Color(0xFFF1F5F9))
                : (ThemeManager.isDark.value ? const Color(0xFF0D1117) : const Color(0xFFE2E8F0)),
            hoverColor: kSurfaceAlt,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: isEmpty 
                    ? (ThemeManager.isDark.value ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1))
                    : kBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: kAccent, width: 1.5),
            ),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.isEmpty ? 'Select' : e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildReadOnlyBadge(int? isFit) {
    final Color badgeColor = isFit == 1 ? kSuccess : (isFit == 0 ? kDanger : kTextMuted);
    final String badgeText = isFit == 1 ? 'FIT' : (isFit == 0 ? 'NOT FIT' : 'PENDING');
    final IconData badgeIcon = isFit == 1 ? Icons.check_circle_outline_rounded : (isFit == 0 ? Icons.cancel_outlined : Icons.help_outline_rounded);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(badgeText, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
        ],
      ),
    );
  }

  Widget _imageSection(String title, List images, String type) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              type == 'before' ? Icons.photo_camera_rounded : Icons.auto_awesome_rounded,
              size: 18, color: kAccent),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
            Text('${images.length} photo${images.length != 1 ? 's' : ''} uploaded',
              style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
          ])),
          OutlinedButton.icon(
            icon: Icon(Icons.add_photo_alternate_rounded, size: 16),
            label: Text('Add Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAccent,
              side: BorderSide(color: kAccent.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _addImage(type),
          ),
        ]),
        SizedBox(height: 20),
        if (images.isEmpty)
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: kBgDeep.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(style: BorderStyle.solid, color: kBorder),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorder),
                ),
                child: Icon(Icons.add_photo_alternate_outlined, size: 32, color: kTextMuted.withValues(alpha: 0.5)),
              ),
              SizedBox(height: 12),
              Text('No $title yet', style: GoogleFonts.inter(color: kTextMuted, fontSize: 14, fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text('Tap "Add Photo" to upload', style: GoogleFonts.inter(color: kTextSubtle, fontSize: 12)),
            ]),
          )
        else
          Wrap(spacing: 14, runSpacing: 14, children: images.map<Widget>((img) {
            return Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    img['image_data'],
                    width: 160, height: 160, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 160, height: 160,
                      color: kSurfaceAlt,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.broken_image_rounded, color: kTextMuted, size: 32),
                        SizedBox(height: 4),
                        Text('Error', style: GoogleFonts.inter(color: kTextMuted, fontSize: 11)),
                      ])),
                  ),
                ),
              ),
              Positioned(top: 4, right: 4,
                child: GestureDetector(
                  onTap: () => _deleteImage(img['id']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: kDanger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: kDanger.withValues(alpha: 0.4), blurRadius: 8)]),
                    padding: const EdgeInsets.all(5),
                    child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
                  ),
                ),
              ),
              if ((img['label'] ?? '').isNotEmpty)
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)]),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(img['label'], textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ),
            ]);
          }).toList()),
      ]),
    );
  }
}

class _EditButtonHover extends StatefulWidget {
  final VoidCallback onTap;
  const _EditButtonHover({required this.onTap});
  @override
  State<_EditButtonHover> createState() => _EditButtonHoverState();
}

class _EditButtonHoverState extends State<_EditButtonHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? kAccent.withValues(alpha: 0.15) : kAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? kAccent.withValues(alpha: 0.5) : kAccent.withValues(alpha: 0.2),
            ),
            boxShadow: _hovered
              ? [BoxShadow(color: kAccent.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)]
              : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, size: 14, color: _hovered ? Colors.white : kAccent),
              SizedBox(width: 6),
              Text('Edit', style: GoogleFonts.inter(
                color: _hovered ? Colors.white : kAccent,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
