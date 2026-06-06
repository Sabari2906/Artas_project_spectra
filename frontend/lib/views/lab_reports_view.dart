import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import '../main.dart';

// ============================================================
//  LAB REPORTS VIEW
// ============================================================
class LabReportsView extends StatefulWidget {
  final void Function(int, [String?])? onNavigate;
  final String? initialAppointmentId;
  final String? initialFilter;
  const LabReportsView({super.key, this.onNavigate, this.initialAppointmentId, this.initialFilter});
  @override
  State<LabReportsView> createState() => _LabReportsViewState();
}

class _LabReportsViewState extends State<LabReportsView> {
  List appointments = [];
  String? selectedApt;
  List results = [];
  bool loading = true;
  Map? evalResult;
  bool saving = false;
  final TextEditingController _notesCtrl = TextEditingController();
  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshSub = globalRefresh.stream.listen((_) {
      if (mounted) {
        _load();
        if (selectedApt != null && selectedApt!.isNotEmpty) {
          _loadResults(selectedApt!);
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/appointments'));
      if (res.statusCode == 200) {
        final List all = json.decode(res.body);
        setState(() {
          appointments = all
              .where(
                (a) =>
                    ['testing', 'cleared', 'not_cleared'].contains(a['status']),
              )
              .toList();
          loading = false;
          
          if (widget.initialAppointmentId != null) {
            final exists = appointments.any((a) => a['id'].toString() == widget.initialAppointmentId);
            if (exists) {
              _loadResults(widget.initialAppointmentId!);
            }
          } else if (widget.initialFilter != null) {
            final match = appointments.firstWhere(
              (a) => widget.initialFilter == 'testing' 
                  ? a['status'] == 'testing' 
                  : ['cleared', 'not_cleared'].contains(a['status']),
              orElse: () => null,
            );
            if (match != null) {
              _loadResults(match['id'].toString());
            }
          }
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadResults(String aptId) async {
    setState(() {
      selectedApt = aptId;
      evalResult = null;
    });
    if (aptId.isEmpty) {
      setState(() => results = []);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('$apiBase/appointments/$aptId/lab-results'),
      );
      if (res.statusCode == 200) {
        setState(() {
          results = json.decode(res.body);
          final apt = appointments.firstWhere((a) => a['id'].toString() == aptId, orElse: () => null);
          _notesCtrl.text = apt?['lab_notes'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _updateResultLocal(int id, String field, dynamic value) {
    setState(() {
      final idx = results.indexWhere((r) => r['id'] == id);
      if (idx != -1) {
        results[idx][field] = value;
      }
    });
  }

  Future<void> _saveResult(Map r) async {
    setState(() => saving = true);
    await http.put(
      Uri.parse('$apiBase/lab-results/${r['id']}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'value': r['value'], 'is_fit': r['is_fit']}),
    );
    setState(() => saving = false);
  }

  Future<void> _evaluate() async {
    for (final r in results) {
      await http.put(
        Uri.parse('$apiBase/lab-results/${r['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'value': r['value'], 'is_fit': r['is_fit']}),
      );
    }
    final res = await http.put(
      Uri.parse('$apiBase/appointments/$selectedApt/evaluate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'lab_notes': _notesCtrl.text}),
    );
    if (!mounted) return;
    final data = json.decode(res.body);
    if (data['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data['error'])));
      return;
    }
    setState(() {
      evalResult = data;
    });
    // load to update status in dropdown and refresh appointments local data
    await _load();
    if (data['status'] == 'cleared') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient cleared successfully! Redirecting to Ready for Procedure...'),
          backgroundColor: kSuccess,
        ),
      );
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onNavigate?.call(1, 'cleared');
        }
      });
    }
  }

  Future<void> _scheduleTreatment(int id) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      try {
        await http.put(
          Uri.parse('$apiBase/appointments/$id/reschedule'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'date': DateFormat('yyyy-MM-dd').format(picked)}),
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treatment highly successfully scheduled!')));
        _load();
      } catch (e) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 768;
      Map? apt;
      if (selectedApt != null && selectedApt!.isNotEmpty) {
        apt = appointments.firstWhere(
          (a) => a['id'].toString() == selectedApt,
          orElse: () => null,
        );
      }
      bool allAssessed =
          results.isNotEmpty && results.every((r) => r['is_fit'] != null);

      return SingleChildScrollView(
        child: Container(
          color: kBgDeep,
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Wrap(
              spacing: 16, runSpacing: 16,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lab Reports & Clearance',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Evaluate test results and grant surgical clearance',
                        style: GoogleFonts.inter(fontSize: 13, color: kTextMuted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Dropdown Cards
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Testing Appointments (Awaiting Lab Results)',
                              style: GoogleFonts.inter(color: kTextMuted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                            SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: kBgDeep, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: appointments.where((a) => a['status'] == 'testing').any((a) => a['id'].toString() == selectedApt) ? selectedApt : null,
                                  isExpanded: true,
                                  dropdownColor: kSurfaceAlt,
                                  hint: Text('— Select pending appt —', style: TextStyle(color: kTextMuted)),
                                  items: appointments.where((a) => a['status'] == 'testing').map<DropdownMenuItem<String>>((a) {
                                    return DropdownMenuItem<String>(
                                      value: a['id'].toString(),
                                      child: Text('${a['patient_name']} — ${DateFormat('MMM dd, yyyy').format(DateTime.parse(a['date']))}', style: TextStyle(color: kTextPrimary)),
                                    );
                                  }).toList(),
                                  onChanged: (v) => _loadResults(v ?? ''),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Evaluated Appointments (Cleared / Not Cleared)',
                              style: GoogleFonts.inter(color: kTextMuted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                            SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: kBgDeep, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: appointments.where((a) => ['cleared', 'not_cleared'].contains(a['status'])).any((a) => a['id'].toString() == selectedApt) ? selectedApt : null,
                                  isExpanded: true,
                                  dropdownColor: kSurfaceAlt,
                                  hint: Text('— Select evaluated appt —', style: TextStyle(color: kTextMuted)),
                                  items: appointments.where((a) => ['cleared', 'not_cleared'].contains(a['status'])).map<DropdownMenuItem<String>>((a) {
                                    return DropdownMenuItem<String>(
                                      value: a['id'].toString(),
                                      child: Text('${a['patient_name']} — ${DateFormat('MMM dd, yyyy').format(DateTime.parse(a['date']))} (${(a['status'] as String).replaceAll('_', ' ').toUpperCase()})', style: TextStyle(color: kTextSecondary)),
                                    );
                                  }).toList(),
                                  onChanged: (v) => _loadResults(v ?? ''),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Testing Appointments (Awaiting Lab Results)',
                                style: GoogleFonts.inter(color: kTextMuted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                              SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(color: kBgDeep, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: appointments.where((a) => a['status'] == 'testing').any((a) => a['id'].toString() == selectedApt) ? selectedApt : null,
                                    isExpanded: true,
                                    dropdownColor: kSurfaceAlt,
                                    hint: Text('— Select pending appt —', style: TextStyle(color: kTextMuted)),
                                    items: appointments.where((a) => a['status'] == 'testing').map<DropdownMenuItem<String>>((a) {
                                      return DropdownMenuItem<String>(
                                        value: a['id'].toString(),
                                        child: Text('${a['patient_name']} — ${DateFormat('MMM dd, yyyy').format(DateTime.parse(a['date']))}', style: TextStyle(color: kTextPrimary)),
                                      );
                                    }).toList(),
                                    onChanged: (v) => _loadResults(v ?? ''),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Evaluated Appointments (Cleared / Not Cleared)',
                                style: GoogleFonts.inter(color: kTextMuted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                              SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(color: kBgDeep, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: appointments.where((a) => ['cleared', 'not_cleared'].contains(a['status'])).any((a) => a['id'].toString() == selectedApt) ? selectedApt : null,
                                    isExpanded: true,
                                    dropdownColor: kSurfaceAlt,
                                    hint: Text('— Select evaluated appt —', style: TextStyle(color: kTextMuted)),
                                    items: appointments.where((a) => ['cleared', 'not_cleared'].contains(a['status'])).map<DropdownMenuItem<String>>((a) {
                                      return DropdownMenuItem<String>(
                                        value: a['id'].toString(),
                                        child: Text('${a['patient_name']} — ${DateFormat('MMM dd, yyyy').format(DateTime.parse(a['date']))} (${(a['status'] as String).replaceAll('_', ' ').toUpperCase()})', style: TextStyle(color: kTextSecondary)),
                                      );
                                    }).toList(),
                                    onChanged: (v) => _loadResults(v ?? ''),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            SizedBox(height: 24),

            // Main Content Area
            if (selectedApt != null && results.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.science, color: kInfo, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  '${apt?['patient_name']} — Test Results',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: kTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Treatment: ${apt?['treatment_name']} | Date: ${apt != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(apt['date'])) : ''}',
                              style: TextStyle(
                                color: kTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: kInfo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: kInfo.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            (apt?['status'] ?? '')
                                .toString()
                                .toUpperCase()
                                .replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: kInfo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Lab Grid Header
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'TEST NAME',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kTextMuted,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'NORMAL RANGE',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kTextMuted,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'FIT?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kTextMuted,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: kBorder, height: 24),

                    // Lab Grid Rows
                    ...results.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['test_name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    r['unit'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                ((double.tryParse(
                                                  r['normal_min']?.toString() ??
                                                      '0',
                                                ) ??
                                                0) >
                                            0 ||
                                        (double.tryParse(
                                                  r['normal_max']?.toString() ??
                                                      '0',
                                                ) ??
                                                0) >
                                            0)
                                    ? '${r['normal_min']} – ${r['normal_max']}'
                                    : 'Non-Reactive',
                                style: TextStyle(
                                  color: kTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  _buildToggleBtn(
                                    r,
                                    1,
                                    Icons.check,
                                    'Yes',
                                    const Color(0xFF10B981),
                                  ),
                                  SizedBox(width: 8),
                                  _buildToggleBtn(
                                    r,
                                    0,
                                    Icons.close,
                                    'No',
                                    kDanger,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                    
                    SizedBox(height: 24),
                    Text('Doctor\'s Comments / Lab Notes', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 12),
                    TextField(
                      controller: _notesCtrl,
                      minLines: 3,
                      maxLines: 8,
                      readOnly: apt?['status'] != 'testing',
                      style: GoogleFonts.inter(color: kTextPrimary, fontSize: 14, height: 1.5),
                      decoration: InputDecoration(
                        hintText: 'Enter clinical observations or comments here...',
                        hintStyle: GoogleFonts.inter(color: kTextMuted, fontSize: 14),
                        filled: true,
                        fillColor: kSurfaceAlt.withValues(alpha: 0.1),
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kAccent, width: 2)),
                      ),
                    ),
                    if (apt?['status'] == 'testing')
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: allAssessed
                                      ? kAccent
                                      : kSurfaceAlt,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.shield,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                label: Text(
                                  'Evaluate Eligibility',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: (allAssessed && !saving)
                                    ? _evaluate
                                    : null,
                              ),
                              if (!allAssessed)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'All tests must be assessed (Yes/No) before evaluation',
                                    style: TextStyle(
                                      color: kTextMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Eligibility Result
                    if (evalResult != null)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: evalResult!['status'] == 'cleared'
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : kDanger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: evalResult!['status'] == 'cleared'
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : kDanger.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              evalResult!['status'] == 'cleared'
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: evalResult!['status'] == 'cleared'
                                  ? const Color(0xFF10B981)
                                  : kDanger,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              evalResult!['status'] == 'cleared'
                                  ? '✓ PATIENT CLEARED'
                                  : '✗ NOT CLEARED',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: evalResult!['status'] == 'cleared'
                                    ? const Color(0xFF10B981)
                                    : kDanger,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${evalResult!['passed']}/${evalResult!['totalTests']} tests passed | ${evalResult!['failed']} failed',
                              style: TextStyle(color: kTextMuted),
                            ),
                            SizedBox(height: 8),
                            Text(
                              evalResult!['message'],
                              style: TextStyle(color: kTextPrimary),
                            ),
                            if (evalResult!['status'] == 'cleared') ...[
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kSurface,
                                  foregroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(Icons.calendar_month, size: 18),
                                label: Text(
                                  'Schedule Treatment Date',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _scheduleTreatment(int.parse(selectedApt!)),
                              ),
                            ],
                          ],
                        ),
                      ),

                    if ((apt?['status'] == 'cleared' ||
                            apt?['status'] == 'not_cleared') &&
                        evalResult == null)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: apt!['status'] == 'cleared'
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : kDanger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: apt['status'] == 'cleared'
                                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                : kDanger.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              apt['status'] == 'cleared'
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: apt['status'] == 'cleared'
                                  ? const Color(0xFF10B981)
                                  : kDanger,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              apt['status'] == 'cleared'
                                  ? '✓ CLEARED'
                                  : '✗ NOT CLEARED',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: apt['status'] == 'cleared'
                                    ? const Color(0xFF10B981)
                                    : kDanger,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              apt['status'] == 'cleared'
                                  ? 'Patient has been cleared for treatment.'
                                  : 'Patient did not pass all required tests.',
                              style: TextStyle(color: kTextMuted),
                            ),
                            if (apt['status'] == 'cleared') ...[
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kSurface,
                                  foregroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(Icons.calendar_month, size: 18),
                                label: Text(
                                  'Schedule Treatment Date',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _scheduleTreatment(apt!['id']),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            if (selectedApt != null && selectedApt!.isNotEmpty && results.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(64),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.science, color: kTextMuted, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'No Lab Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      'No test results found for this appointment.',
                      style: TextStyle(color: kTextSecondary),
                    ),
                  ],
                ),
              ),

            if (selectedApt == null || selectedApt!.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(64),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.science, color: kTextMuted, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Select an Appointment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      'Choose a patient appointment in the testing phase to view and manage lab results.',
                      style: TextStyle(color: kTextSecondary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ));
    });
  }

  Widget _buildToggleBtn(Map r, int val, IconData icon, String label, Color c) {
    bool active = r['is_fit'] == val;
    return InkWell(
      onTap: () {
        _updateResultLocal(r['id'], 'is_fit', val);
        _saveResult({...r, 'is_fit': val});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.1) : kBgDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? c : kBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? c : kTextMuted),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? c : kTextMuted,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



