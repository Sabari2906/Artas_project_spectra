import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import '../main.dart';

// ============================================================
//  USAGE LOGS VIEW (Compliance & Audit)
// ============================================================
class UsageLogsView extends StatefulWidget {
  const UsageLogsView({super.key});
  @override
  State<UsageLogsView> createState() => _UsageLogsViewState();
}

class _UsageLogsViewState extends State<UsageLogsView> {
  List logs = [];
  bool loading = true;
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
      final res = await http.get(Uri.parse('$apiBase/inventory/logs'));
      if (res.statusCode == 200) {
        setState(() {
          logs = json.decode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _showRestockDialog(int inventoryId, String itemName, int maxQty, {int? appointmentId}) async {
    int restockQty = maxQty; // default to full amount

    final confirm = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.undo_rounded, color: kSuccess, size: 20),
              const SizedBox(width: 10),
              Text(
                'Restock Item',
                style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(itemName,
                style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
              const SizedBox(height: 4),
              Text(
                'Originally deducted: $maxQty units',
                style: GoogleFonts.inter(fontSize: 12, color: kTextMuted)),
              const SizedBox(height: 20),
              Text('Units to restock:',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: kBgDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: restockQty > 1 ? kAccent : kTextMuted,
                      onPressed: restockQty > 1
                          ? () => setDialogState(() => restockQty--)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$restockQty',
                      style: GoogleFonts.outfit(
                        fontSize: 28, fontWeight: FontWeight.w800, color: kTextPrimary),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: restockQty < maxQty ? kAccent : kTextMuted,
                      onPressed: restockQty < maxQty
                          ? () => setDialogState(() => restockQty++)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (restockQty < maxQty)
                Center(
                  child: Text(
                    '${maxQty - restockQty} unit(s) will remain as used in logs',
                    style: GoogleFonts.inter(fontSize: 11, color: kWarning),
                  ),
                ),
              if (restockQty == maxQty)
                Center(
                  child: Text(
                    'This item will be removed from usage logs',
                    style: GoogleFonts.inter(fontSize: 11, color: kSuccess),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                style: GoogleFonts.inter(color: kTextMuted)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kSuccess,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              label: Text(
                'Restock $restockQty Unit${restockQty > 1 ? 's' : ''}',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () => Navigator.pop(ctx, restockQty),
            ),
          ],
        ),
      ),
    );

    if (confirm == null || confirm <= 0) return;

    try {
      final res = await http.put(
        Uri.parse('$apiBase/inventory/$inventoryId/restock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'quantity': confirm,
          if (appointmentId != null) 'appointment_id': appointmentId,
        }),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$confirm unit${confirm > 1 ? 's' : ''} of "$itemName" returned to inventory'),
              backgroundColor: kSuccess,
            ),
          );
        }
        _load(); // refresh usage logs — rows with 0 remaining will disappear
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restock failed'), backgroundColor: kDanger));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
      }
    }
  }


  List<Map<String, dynamic>> _getGroupedLogs() {
    Map<String, Map<String, dynamic>> grouped = {};
    for (var log in logs) {
      String key = log['appointment_id'].toString();
      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'patient_name': log['patient_name'] ?? 'Unknown',
          'treatment_type': log['treatment_type'] ?? '—',
          'date': log['date'],
          'items': [],
        };
      }
      grouped[key]!['items'].add({
        'item_name': log['item_name'],
        'quantity_used': log['quantity_used'],
        'inventory_id': log['inventory_id'],
        'appointment_id': log['appointment_id'],
      });
    }
    return grouped.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 400,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usage Logs',
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
                          'Compliance & audit trail — tracks all inventory deductions after treatment completion.',
                          style: GoogleFonts.inter(fontSize: 13, color: kTextMuted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        'No usage logs yet. Complete an appointment to generate logs.',
                        style: TextStyle(color: kTextMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _getGroupedLogs().length,
                      itemBuilder: (ctx, i) {
                        final g = _getGroupedLogs()[i];
                        final dateStr = DateFormat(
                          'MMM dd, yyyy HH:mm',
                        ).format(DateTime.parse(g['date']));

                        return Card(
                          color: kSurfaceAlt.withValues(alpha: 0.1),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: kBorder),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              iconColor: kAccent,
                              collapsedIconColor: kTextMuted,
                              title: Text(
                                'Patient: ${g['patient_name']}',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: RichText(
                                text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Treatment Type: ',
                                        style: TextStyle(color: kTextMuted),
                                      ),
                                    TextSpan(
                                      text:
                                          '${(g['treatment_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase()}   •   $dateStr',
                                      style: TextStyle(
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: kBgDeep,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Items Used For Treatment:',
                                        style: TextStyle(
                                          color: kAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      ...g['items']
                                          .map<Widget>(
                                            (item) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.arrow_right,
                                                    color: kTextMuted,
                                                    size: 16,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      item['item_name'],
                                                      style: TextStyle(
                                                        color: kTextPrimary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: kWarning
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${item['quantity_used']} units',
                                                      style: TextStyle(
                                                        color: kWarning,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Tooltip(
                                                    message: 'Restock to inventory',
                                                    child: IconButton(
                                                      icon: Icon(Icons.undo_rounded, size: 16, color: kSuccess),
                                                      onPressed: () => _showRestockDialog(
                                                        item['inventory_id'] ?? 0,
                                                        item['item_name'],
                                                        item['quantity_used'] as int,
                                                        appointmentId: item['appointment_id'] as int?,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
    });
  }
}



