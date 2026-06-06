import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import '../main.dart';

// ============================================================
//  PRESCRIPTIONS VIEW
// ============================================================
class PrescriptionsView extends StatefulWidget {
  const PrescriptionsView({super.key});
  @override
  State<PrescriptionsView> createState() => _PrescriptionsViewState();
}

class _PrescriptionsViewState extends State<PrescriptionsView> {
  List completedApts = [];
  List prescriptions = [];
  String? selectedApt;
  bool loading = true;
  String msg = '';
  Map? viewSlip;

  final treatCtrl = TextEditingController();
  final medCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
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
    try {
      final resApt = await http.get(Uri.parse('$apiBase/appointments'));
      final resP = await http.get(Uri.parse('$apiBase/prescriptions'));

      if (resApt.statusCode == 200 && resP.statusCode == 200) {
        final List allApts = json.decode(resApt.body);
        setState(() {
          completedApts = allApts
              .where((a) => a['status'] == 'completed' || a['status'] == 'cleared')
              .toList();
          prescriptions = json.decode(resP.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _savePrescription() async {
    if (selectedApt == null || selectedApt!.isEmpty) return;

    final res = await http.post(
      Uri.parse('$apiBase/appointments/$selectedApt/prescription'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'treatment_details': treatCtrl.text,
        'medicines': medCtrl.text,
        'comments': notesCtrl.text,
      }),
    );

    final data = json.decode(res.body);
    if (data['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data['error'])));
      return;
    }

    setState(() {
      msg = 'Prescription saved successfully!';
      treatCtrl.clear();
      medCtrl.clear();
      notesCtrl.clear();
      selectedApt = null;
    });

    _load();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => msg = '');
    });
  }

  Future<void> _viewPrescription(int aptId) async {
    final res = await http.get(
      Uri.parse('$apiBase/appointments/$aptId/prescription'),
    );
    final data = json.decode(res.body);
    if (data['error'] != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data['error'])));
      return;
    }
    setState(() => viewSlip = data);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 768;
      return Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
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
                                  'Prescriptions & Summary',
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
                                  'Issue and review patient prescription slips',
                                  style: GoogleFonts.inter(fontSize: 13, color: kTextMuted, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      Wrap(
                        spacing: 24, runSpacing: 24,
                        children: [
                          SizedBox(
                            width: isMobile ? double.infinity : (constraints.maxWidth - 64 - 24) / 2,
                            child:
                        // Left: Issue Prescription
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: kHighlight.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        color: kHighlight,
                                        size: 18,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Issue Prescription',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                if (msg.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: kSuccess.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: kSuccess.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.check_circle_rounded, size: 18, color: kSuccess),
                                      SizedBox(width: 10),
                                      Text(
                                        msg,
                                        style: GoogleFonts.inter(
                                          color: kSuccess,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ]),
                                  ),

                                  Text(
                                    'Eligible Appointment (Cleared / Completed)',
                                    style: GoogleFonts.inter(
                                      color: kTextPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kBgDeep,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedApt == ''
                                          ? null
                                          : selectedApt,
                                      isExpanded: true,
                                      dropdownColor: kSurfaceAlt,
                                      hint: Text(
                                        '— Select appointment —',
                                        style: TextStyle(color: kTextMuted),
                                      ),
                                      items: completedApts
                                          .map<DropdownMenuItem<String>>((a) {
                                            return DropdownMenuItem<String>(
                                              value: a['id'].toString(),
                                              child: Text(
                                                '${a['patient_name']} — ${DateFormat('MMM dd, yyyy').format(DateTime.parse(a['date']))}',
                                                style: TextStyle(
                                                  color: kTextPrimary,
                                                ),
                                              ),
                                            );
                                          })
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          selectedApt = v;
                                          final apt = completedApts.firstWhere(
                                            (a) => a['id'].toString() == v,
                                            orElse: () => null,
                                          );
                                          if (apt != null) {
                                            String type =
                                                (apt['treatment_type'] ?? '')
                                                    .toString()
                                                    .replaceAll('_', ' ');
                                            treatCtrl.text =
                                                '${apt['treatment_name']}${type.isNotEmpty ? " ($type)" : ""}';
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),

                                Text(
                                  'Treatment Details',
                                  style: GoogleFonts.inter(
                                    color: kTextPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                TextField(
                                  controller: treatCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Treatment performed, details...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  style: TextStyle(color: kTextPrimary),
                                ),
                                SizedBox(height: 16),

                                Text(
                                  'Prescribed Medicines',
                                  style: GoogleFonts.inter(
                                    color: kTextPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                TextField(
                                  controller: medCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Medicine name, dosage, frequency...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  style: TextStyle(color: kTextPrimary),
                                ),
                                SizedBox(height: 16),

                                Text(
                                  'Additional Comments',
                                  style: GoogleFonts.inter(
                                    color: kTextPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                TextField(
                                  controller: notesCtrl,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Follow-up instructions, recommendations...',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.all(12),
                                  ),
                                  style: TextStyle(color: kTextPrimary),
                                ),
                                SizedBox(height: 24),

                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kHighlight,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 24,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.receipt_long_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Save Prescription',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed:
                                      (selectedApt == null ||
                                          selectedApt!.isEmpty)
                                      ? null
                                      : _savePrescription,
                                ),
                              ],
                            ),
                          ),
                          ),
                          SizedBox(
                            width: isMobile ? double.infinity : (constraints.maxWidth - 64 - 24) / 2,
                            child:
                        // Right: Issued Prescriptions
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.list_alt_rounded, size: 18, color: kAccent),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Issued Prescriptions',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                ]),
                                SizedBox(height: 16),
                                if (prescriptions.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: kBgDeep,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: kBorder),
                                          ),
                                          child: Icon(
                                            Icons.receipt_long_rounded,
                                            size: 32,
                                            color: kTextMuted.withValues(alpha: 0.5),
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No prescriptions yet',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Issue a prescription to see it here',
                                          style: GoogleFonts.inter(fontSize: 12, color: kTextMuted),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: prescriptions.length,
                                    separatorBuilder: (ctx, i) =>
                                        SizedBox(height: 12),
                                    itemBuilder: (ctx, i) {
                                      final p = prescriptions[i];
                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: kSurfaceAlt,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(color: kBorder),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p['patient_name'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: kTextPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  '${p['treatment_name']} • ${DateFormat('MMM dd, yyyy').format(DateTime.parse(p['appointment_date']))}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: kTextSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: kBorder,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              icon: Icon(
                                                Icons.remove_red_eye,
                                                size: 14,
                                                color: kTextPrimary,
                                              ),
                                              label: Text(
                                                'View',
                                                style: TextStyle(
                                                  color: kTextPrimary,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _viewPrescription(
                                                    p['appointment_id'],
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (viewSlip != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => viewSlip = null),
              child: Container(
                color: Colors.black.withValues(alpha: 0.1),
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {}, // consume tap
                  child: Container(
                    width: 600,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Summary Slip',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: kTextPrimary,
                          ),
                        ),
                        Text(
                          'Artas Hair Restoration Clinic',
                          style: TextStyle(color: kTextMuted, fontSize: 13),
                        ),
                        Divider(color: kBorder, height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Patient Name',
                                    style: TextStyle(
                                      color: kTextMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    viewSlip!['patient_name'],
                                    style: TextStyle(color: kTextPrimary),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Phone',
                                    style: TextStyle(
                                      color: kTextMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    viewSlip!['patient_phone'],
                                    style: TextStyle(color: kTextPrimary),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: TextStyle(
                                      color: kTextMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(
                                      DateTime.parse(
                                        viewSlip!['appointment_date'],
                                      ),
                                    ),
                                    style: TextStyle(color: kTextPrimary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Treatment Details',
                          style: TextStyle(
                            color: kTextMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          viewSlip!['treatment_details'],
                          style: TextStyle(color: kTextPrimary),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Prescribed Medicines',
                          style: TextStyle(
                            color: kTextMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          viewSlip!['medicines'] ?? 'none',
                          style: TextStyle(color: kTextPrimary),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Comments / Notes',
                          style: TextStyle(
                            color: kTextMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          viewSlip!['comments'] ?? 'none',
                          style: TextStyle(color: kTextPrimary),
                        ),
                        SizedBox(height: 32),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kHighlight,
                            ),
                            icon: Icon(
                              Icons.print,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: Text(
                              'Print Slip',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    });
  }
}



