import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../main.dart';

// ============================================================
//  MEDICAL REPORTS VIEW
// ============================================================
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});
  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  List reports = [];
  List patients = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$apiBase/reports')),
        http.get(Uri.parse('$apiBase/patients')),
      ]);
      setState(() {
        reports = json.decode(results[0].body);
        patients = json.decode(results[1].body);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _showGenerateLetterDialog() {
    int? selectedPatient;
    final doctorNameCtrl = TextEditingController();
    final diagnosisCtrl = TextEditingController();
    final recommendationsCtrl = TextEditingController();
    final daysOffCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Generate Medical Letter', style: TextStyle(color: kTextPrimary)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(labelText: 'Patient'),
                    dropdownColor: kSurfaceAlt,
                    items: patients.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(value: p['id'] as int, child: Text('${p['name']} (${p['phone']})'))).toList(),
                    onChanged: (v) => setDialogState(() => selectedPatient = v),
                  ),
                  SizedBox(height: 16),
                  TextField(controller: doctorNameCtrl, style: TextStyle(color: kTextPrimary), decoration: InputDecoration(labelText: 'Attending Doctor Name', hintText: 'Dr. Smith')),
                  SizedBox(height: 16),
                  TextField(controller: diagnosisCtrl, style: TextStyle(color: kTextPrimary), decoration: InputDecoration(labelText: 'Primary Diagnosis / Condition', hintText: 'e.g. Post Hair Transplant Recovery')),
                  SizedBox(height: 16),
                  TextField(controller: recommendationsCtrl, maxLines: 3, style: TextStyle(color: kTextPrimary), decoration: InputDecoration(labelText: 'Medical Recommendations / Notes', hintText: 'Avoid strenuous activity...')),
                  SizedBox(height: 16),
                  TextField(controller: daysOffCtrl, keyboardType: TextInputType.number, style: TextStyle(color: kTextPrimary), decoration: InputDecoration(labelText: 'Recommended Days Off Work', hintText: '3')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.picture_as_pdf, size: 16),
              label: Text('Generate & Download'),
              onPressed: () async {
                if (selectedPatient == null || doctorNameCtrl.text.isEmpty) return;
                
                final patient = patients.firstWhere((p) => p['id'] == selectedPatient);
                final patientName = patient['name'];
                
                final pdf = pw.Document();
                // Load some color constants
                final accentColor = PdfColor.fromInt(0xFF8B5CF6);

                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    margin: const pw.EdgeInsets.all(40),
                    build: (pw.Context context) {
                      return pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Spectra Artas Treatment', 
                                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: accentColor)),
                                  pw.Text('Advanced Hair Restoration & Robotic Surgery', 
                                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                                ],
                              ),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text('No:43,Industrial estate,', style: const pw.TextStyle(fontSize: 9)),
                                  pw.Text('Perungudi', style: const pw.TextStyle(fontSize: 9)),
                                  pw.Text('Chennai-600096', style: const pw.TextStyle(fontSize: 9)),
                                  pw.Text('www.spectramedicals.com', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 10),
                          pw.Divider(thickness: 2, color: accentColor),
                          pw.SizedBox(height: 30),

                          // Document Title
                          pw.Center(
                            child: pw.Text('MEDICAL CERTIFICATE', 
                              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline))
                          ),
                          pw.SizedBox(height: 40),

                          // Date and Salutation
                          pw.Text('Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}'),
                          pw.SizedBox(height: 20),
                          pw.Text('TO WHOM IT MAY CONCERN,', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 20),

                          // Main Body
                          pw.Paragraph(
                            text: 'This is to formally certify that Mr./Ms. $patientName was under the clinical care and evaluation at ARTAS Clinic.',
                            style: const pw.TextStyle(lineSpacing: 1.5),
                          ),
                          
                          pw.SizedBox(height: 10),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              border: pw.Border.all(color: PdfColors.grey300),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.RichText(
                                  text: pw.TextSpan(
                                    style: const pw.TextStyle(fontSize: 11),
                                    children: [
                                      pw.TextSpan(text: 'Diagnosis / Condition: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                      pw.TextSpan(text: diagnosisCtrl.text),
                                    ],
                                  ),
                                ),
                                pw.SizedBox(height: 8),
                                pw.RichText(
                                  text: pw.TextSpan(
                                    style: const pw.TextStyle(fontSize: 11),
                                    children: [
                                      pw.TextSpan(text: 'Recommendations: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                                      pw.TextSpan(text: recommendationsCtrl.text),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          pw.SizedBox(height: 20),
                          if (daysOffCtrl.text.isNotEmpty)
                            pw.Paragraph(
                              text: 'Based on the clinical evaluation, it is recommended that the patient be excused from work/strenuous activity for a period of ${daysOffCtrl.text} day(s) starting from today to ensure optimal recovery.',
                              style: const pw.TextStyle(lineSpacing: 1.5),
                            ),

                          pw.SizedBox(height: 40),
                          pw.Text('Sincerely,'),
                          pw.SizedBox(height: 40),
                          
                          // Signature block
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)))),
                              pw.SizedBox(height: 4),
                              pw.Text(doctorNameCtrl.text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.Text('Attending Physician', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                              pw.Text('ARTAS Clinic - Department of Surgery', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                            ],
                          ),

                          pw.Spacer(),
                          // Footer
                          pw.Divider(color: PdfColors.grey300),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('This is a computer-generated document and is valid for medical insurance and workplace claims.', 
                                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                );

                await Printing.sharePdf(
                  bytes: await pdf.save(),
                  filename: 'ARTAS_Medical_Letter_${patientName.replaceAll(' ', '_')}.pdf',
                );

                // Option to save to database record
                await http.post(
                  Uri.parse('$apiBase/reports'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'patient_id': selectedPatient,
                    'report_name': 'Automated Medical Letter',
                    'notes': 'Doctor: ${doctorNameCtrl.text}\nDiagnosis: ${diagnosisCtrl.text}',
                  }),
                );
                
                if (mounted) {
                  Navigator.pop(ctx);
                  _load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReport(Map r) async {
    final patientName = r['patient_name'] ?? 'Patient';
    final notes = r['notes'] ?? '';
    
    // Attempt basic parsing of stored doctor/diagnosis
    String docName = 'Dr. Staff';
    String diag = 'Regular Clinical Evaluation';
    try {
      if (notes.contains('Doctor:')) {
        docName = notes.split('Doctor:')[1].split('\n')[0].trim();
      }
      if (notes.contains('Diagnosis:')) {
        diag = notes.split('Diagnosis:')[1].split('\n')[0].trim();
      }
    } catch (_) {}

    final pdf = pw.Document();
    final accentColor = PdfColor.fromInt(0xFF8B5CF6);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ARTAS CLINIC', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: accentColor)),
                      pw.Text('Advanced Hair Restoration & Robotic Surgery', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('123 Medical Boulevard,', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Care City, CA 90210', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Contact: +1 (555) 012-3456', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('www.artasclinic.com', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: accentColor),
              pw.SizedBox(height: 30),
              pw.Center(
                child: pw.Text('MEDICAL CERTIFICATE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline))
              ),
              pw.SizedBox(height: 40),
              pw.Text('Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.parse(r['uploaded_at']))}'),
              pw.SizedBox(height: 20),
              pw.Text('TO WHOM IT MAY CONCERN,', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Paragraph(
                text: 'This is to formally certify that Mr./Ms. $patientName was under the clinical care and evaluation at ARTAS Clinic.',
                style: const pw.TextStyle(lineSpacing: 1.5),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(text: pw.TextSpan(style: const pw.TextStyle(fontSize: 11), children: [
                      pw.TextSpan(text: 'Diagnosis / Condition: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(text: diag),
                    ])),
                    pw.SizedBox(height: 8),
                    pw.RichText(text: pw.TextSpan(style: const pw.TextStyle(fontSize: 11), children: [
                      pw.TextSpan(text: 'Full Clinical Notes: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(text: notes),
                    ])),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Text('Sincerely,'),
              pw.SizedBox(height: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)))),
                  pw.SizedBox(height: 4),
                  pw.Text(docName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Attending Physician', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('ARTAS Clinic - Department of Surgery', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('This is a computer-generated document and is valid for medical insurance and workplace claims.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'ARTAS_Report_${patientName.replaceAll(' ', '_')}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5));
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Reports',
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
                      'Secure report management. Generate standard letters for patients directly to PDF.',
                      style: GoogleFonts.inter(fontSize: 13, color: kTextMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: Tooltip(
                      message: "Sync latest reports",
                      child: IconButton(
                        icon: Icon(Icons.refresh_rounded, color: kAccent, size: 20),
                        onPressed: _load,
                        splashRadius: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.edit_document, size: 18),
                    label: Text('Generate Medical Letter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _showGenerateLetterDialog,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          Expanded(
            child: reports.isEmpty
                ? Center(
                    child: Container(
                      width: 420,
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: kSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kBorder),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: kBgDeep,
                              shape: BoxShape.circle,
                              border: Border.all(color: kBorder),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              size: 40,
                              color: kTextMuted.withValues(alpha: 0.5),
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'No reports uploaded',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Click "Generate Medical Letter" to create one automatically.',
                            style: GoogleFonts.inter(color: kTextMuted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          kSurfaceAlt.withValues(alpha: 0.1),
                        ),
                        columns: [
                          DataColumn(
                            label: Text(
                              'DATE',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'REPORT NAME',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'PATIENT',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'NOTES',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'ACTIONS',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kTextMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                        rows: reports.map<DataRow>((r) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(DateTime.parse(r['uploaded_at'])),
                                  style: TextStyle(color: kTextSecondary),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    Icon(
                                      Icons.description,
                                      size: 16,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      r['report_name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  r['patient_name'] ?? '-',
                                  style: TextStyle(color: kTextSecondary),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 200,
                                  child: Text(
                                    r['notes'] ?? '',
                                    style: TextStyle(color: kTextMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Download PDF',
                                      icon: Icon(Icons.download_rounded, color: kAccent, size: 20),
                                      onPressed: () => _downloadReport(r),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}



