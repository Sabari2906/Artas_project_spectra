import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import '../main.dart';

// ============================================================
//  APPOINTMENTS VIEW
// ============================================================
class AppointmentsView extends StatefulWidget {
  final void Function(int, [String?])? onNavigate;
  final String? initialFilter;
  const AppointmentsView({super.key, this.onNavigate, this.initialFilter});
  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  List appointments = [];
  List patients = [];
  List treatments = [];
  List inventory = [];
  bool loading = true;
  String activeFilter = 'all';
  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
    activeFilter = widget.initialFilter ?? 'all';
    _loadAll();
    _refreshSub = globalRefresh.stream.listen((_) {
      if (mounted) _loadAll();
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppointmentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter &&
        widget.initialFilter != null) {
      setState(() {
        activeFilter = widget.initialFilter!;
      });
    }
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$apiBase/appointments')),
        http.get(Uri.parse('$apiBase/patients')),
        http.get(Uri.parse('$apiBase/treatments')),
        http.get(Uri.parse('$apiBase/inventory')),
      ]);
      setState(() {
        appointments = json.decode(results[0].body);
        patients = json.decode(results[1].body);
        treatments = json.decode(results[2].body);
        inventory = json.decode(results[3].body);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  List get filteredAppointments {
    if (activeFilter == 'all') return appointments;
    return appointments.where((a) => a['status'] == activeFilter).toList();
  }

  Future<void> _completeAppointment(Map apt) async {
    final int id = apt['id'] as int;
    final List defaultAccs = apt['accessories'] ?? [];
    
    List manualItems = defaultAccs.map((acc) => {
      'inventory_id': acc['inventory_id'],
      'item_name': acc['item_name'],
      'quantity_used': acc['quantity_required'],
    }).toList();

    String mode = 'automatic';

    final confirm = await showDialog<Map?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: kSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Complete Treatment & Deduct Stock', style: TextStyle(color: kTextPrimary)),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark appointment for ${apt['patient_name']} as completed and select deduction mode.',
                      style: TextStyle(color: kTextSecondary, fontSize: 13),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => mode = 'automatic'),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: mode == 'automatic' ? kAccent.withValues(alpha: 0.15) : Colors.transparent,
                                border: Border.all(color: mode == 'automatic' ? kAccent : kBorder),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Automatic Deduction',
                                  style: TextStyle(
                                    color: mode == 'automatic' ? kAccent : kTextSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => mode = 'manual'),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: mode == 'manual' ? kAccent.withValues(alpha: 0.15) : Colors.transparent,
                                border: Border.all(color: mode == 'manual' ? kAccent : kBorder),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Manual Deduction',
                                  style: TextStyle(
                                    color: mode == 'manual' ? kAccent : kTextSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    if (mode == 'automatic') ...[
                      Text(
                        'Default items that will be deducted:',
                        style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      defaultAccs.isEmpty
                          ? Text('No default accessories linked to this treatment.', style: TextStyle(color: kTextMuted, fontSize: 13))
                          : Container(
                              decoration: BoxDecoration(
                                color: kBgDeep,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kBorder),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: defaultAccs.length,
                                separatorBuilder: (_, __) => Divider(color: kBorder, height: 1),
                                itemBuilder: (ctx, i) {
                                  final acc = defaultAccs[i];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(acc['item_name'], style: TextStyle(color: kTextPrimary, fontSize: 13)),
                                        Text('Qty: ${acc['quantity_required']}', style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Accessories Used:',
                            style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            icon: Icon(Icons.add, size: 16),
                            label: Text('Add Item'),
                            onPressed: () {
                              int? tempSelectedId;
                              showDialog(
                                context: context,
                                builder: (subCtx) => StatefulBuilder(
                                  builder: (subCtx, setSubState) => AlertDialog(
                                    title: Text('Select Accessory to Add', style: TextStyle(color: kTextPrimary, fontSize: 15)),
                                    content: DropdownButtonFormField<int>(
                                      dropdownColor: kSurfaceAlt,
                                      decoration: InputDecoration(labelText: 'Accessory'),
                                      items: inventory.where((inv) {
                                        return !manualItems.any((mi) => mi['inventory_id'] == inv['id']);
                                      }).map<DropdownMenuItem<int>>((inv) => DropdownMenuItem(
                                        value: inv['id'] as int,
                                        child: Text('${inv['item_name']} (Stock: ${inv['quantity']})'),
                                      )).toList(),
                                      onChanged: (val) => setSubState(() => tempSelectedId = val),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(subCtx), child: Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: tempSelectedId == null ? null : () {
                                          final invItem = inventory.firstWhere((inv) => inv['id'] == tempSelectedId);
                                          setDialogState(() {
                                            manualItems.add({
                                              'inventory_id': invItem['id'],
                                              'item_name': invItem['item_name'],
                                              'quantity_used': 1,
                                            });
                                          });
                                          Navigator.pop(subCtx);
                                        },
                                        child: Text('Add'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      manualItems.isEmpty
                          ? Text('No accessories selected. Add items to deduct.', style: TextStyle(color: kTextMuted, fontSize: 13))
                          : Container(
                              decoration: BoxDecoration(
                                color: kBgDeep,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kBorder),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: manualItems.length,
                                separatorBuilder: (_, __) => Divider(color: kBorder, height: 1),
                                itemBuilder: (ctx, i) {
                                  final item = manualItems[i];
                                  final nameController = TextEditingController(text: '${item['quantity_used']}');
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(item['item_name'], style: TextStyle(color: kTextPrimary, fontSize: 13)),
                                        ),
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            controller: nameController,
                                            keyboardType: TextInputType.number,
                                            style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            onChanged: (val) {
                                              item['quantity_used'] = int.tryParse(val) ?? 0;
                                            },
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.delete_outline, color: kDanger, size: 18),
                                          onPressed: () {
                                            setDialogState(() {
                                              manualItems.removeAt(i);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx, {
                    'deduction_mode': mode,
                    'items': manualItems,
                  });
                },
                child: Text('Complete & Deduct'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == null) return;

    try {
      final res = await http.put(
        Uri.parse('$apiBase/appointments/$id/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(confirm),
      );
      if (!mounted) return;
      final body = json.decode(res.body);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message']), backgroundColor: kSuccess),
        );
        _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${body['error']}'), backgroundColor: kDanger),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showRestockUnusedDialog(Map apt) async {
    final int id = apt['id'] as int;
    
    setState(() => loading = true);
    List usageLogs = [];
    try {
      final res = await http.get(Uri.parse('$apiBase/appointments/$id/usage-logs'));
      if (res.statusCode == 200) {
        usageLogs = json.decode(res.body);
      }
    } catch (_) {}
    setState(() => loading = false);

    if (usageLogs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No accessories were logged as used for this appointment.'), backgroundColor: kDanger),
      );
      return;
    }

    final List restockItems = usageLogs.map((log) => {
      'inventory_id': log['inventory_id'],
      'item_name': log['item_name'],
      'max_quantity': log['quantity_used'],
      'quantity_to_restock': 0,
    }).toList();

    final confirm = await showDialog<List?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: kSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Restock Unused Accessories', style: TextStyle(color: kTextPrimary)),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specify the quantities of unused accessories that should be returned to inventory stock.',
                    style: TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: kBgDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: restockItems.length,
                      separatorBuilder: (_, __) => Divider(color: kBorder, height: 1),
                      itemBuilder: (ctx, i) {
                        final item = restockItems[i];
                        final int val = item['quantity_to_restock'];
                        final int max = item['max_quantity'];
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['item_name'], style: TextStyle(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 2),
                                    Text('Deducted: $max used', style: TextStyle(color: kTextMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, color: val > 0 ? kAccent : kTextMuted, size: 20),
                                    onPressed: val > 0 ? () => setDialogState(() => item['quantity_to_restock'] = val - 1) : null,
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Center(
                                      child: Text(
                                        '$val',
                                        style: TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline, color: val < max ? kAccent : kTextMuted, size: 20),
                                    onPressed: val < max ? () => setDialogState(() => item['quantity_to_restock'] = val + 1) : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text('Cancel')),
              ElevatedButton(
                onPressed: restockItems.any((item) => item['quantity_to_restock'] > 0)
                    ? () => Navigator.pop(ctx, restockItems.where((item) => item['quantity_to_restock'] > 0).toList())
                    : null,
                child: Text('Confirm Restock'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm == null) return;

    try {
      final res = await http.post(
        Uri.parse('$apiBase/appointments/$id/restock-unused'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'items': confirm,
          'reason': 'Restocked unused accessories after procedure',
          'user_id': 'admin'
        }),
      );
      if (!mounted) return;
      final body = json.decode(res.body);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message']), backgroundColor: kSuccess),
        );
        _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${body['error']}'), backgroundColor: kDanger),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveAppointment(int id) async {
    try {
      await http.put(Uri.parse('$apiBase/appointments/$id/approve'));
      if (!mounted) return;
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _consultAppointment(Map apt) {
    String selectedTreatmentType = apt['treatment_type'] ?? 'fully_robotic';
    int? selectedTreatmentId = apt['treatment_id'];

    // Ensure the ID still exists in the local treatments list
    if (!treatments.any((t) => t['id'] == selectedTreatmentId)) {
      selectedTreatmentId = treatments.isNotEmpty
          ? treatments.first['id'] as int
          : null;
    }

    String doctorNotes = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final matchedTreatments = treatments
              .where((t) => t['id'] == selectedTreatmentId)
              .toList();
          double? price;
          if (matchedTreatments.isNotEmpty) {
            price = double.tryParse(
              matchedTreatments.first['price'].toString(),
            );
          }

          return AlertDialog(
            backgroundColor: kSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Icon(Icons.medical_services, color: kAccent, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Doctor Consultation',
                        style: TextStyle(
                          color: kTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: kTextMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'Patient: '),
                        TextSpan(
                          text: '${apt['patient_name']}',
                          style: TextStyle(
                            color: kTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Assigned Treatment',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: kBgDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedTreatmentId,
                        isExpanded: true,
                        dropdownColor: kSurfaceAlt,
                        style: TextStyle(color: kTextPrimary),
                        items: treatments
                            .map<DropdownMenuItem<int>>(
                              (t) => DropdownMenuItem(
                                value: t['id'] as int,
                                child: Text(t['name']),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            selectedTreatmentId = v;
                            final t = treatments.firstWhere(
                              (x) => x['id'] == v,
                              orElse: () => {},
                            );
                            selectedTreatmentType =
                                t['type'] ?? 'fully_robotic';
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Treatment Type',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: kBgDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTreatmentType,
                        isExpanded: true,
                        dropdownColor: kSurfaceAlt,
                        style: TextStyle(color: kTextPrimary),
                        items: [
                          DropdownMenuItem(
                            value: 'fully_robotic',
                            child: Text('Fully Robotic'),
                          ),
                          DropdownMenuItem(
                            value: 'hybrid',
                            child: Text('Hybrid (Robotic + Manual)'),
                          ),
                          DropdownMenuItem(
                            value: 'manual',
                            child: Text('Manual'),
                          ),
                        ],
                        onChanged: (v) => setDialogState(
                          () => selectedTreatmentType = v ?? 'fully_robotic',
                        ),
                      ),
                    ),
                  ),
                  if (price != null && price > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kSurfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Price Range: ',
                            style: TextStyle(color: kTextMuted, fontSize: 13),
                          ),
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: kTextPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),
                  Text(
                    'Doctor Notes',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Recommendations, observations...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    style: TextStyle(color: kTextPrimary),
                    maxLines: 3,
                    onChanged: (v) => doctorNotes = v,
                  ),
                ],
              )),
            ),
            actionsPadding: const EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: 24,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kHighlight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await http.put(
                    Uri.parse(
                      '$apiBase/appointments/${apt['id']}/start-testing',
                    ),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'treatment_id': selectedTreatmentId,
                      'treatment_type': selectedTreatmentType,
                      'doctor_notes': doctorNotes,
                    }),
                  );
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _loadAll();
                },
                child: Text(
                  'Send for Tests',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancelAppointment(int id) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cancel Appointment',
          style: TextStyle(color: kTextPrimary),
        ),
        content: Text(
          'Are you sure you want to cancel this appointment?',
          style: TextStyle(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Appointment', style: TextStyle(color: kDanger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    try {
      await http.put(Uri.parse('$apiBase/appointments/$id/cancel'));
      if (!mounted) return;
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Treatment date successfully scheduled!'), backgroundColor: kSuccess),
        );
        _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: kDanger));
      }
    }
  }

  void _showAddDialog() {
    int? selectedPatient;
    int? selectedTreatment;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('New Appointment', style: TextStyle(color: kTextPrimary)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: 'Patient'),
                  dropdownColor: kSurfaceAlt,
                  items: patients
                      .map<DropdownMenuItem<int>>(
                        (p) => DropdownMenuItem(
                          value: p['id'] as int,
                          child: Text('${p['name']} (${p['phone']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedPatient = v),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: 'Treatment'),
                  dropdownColor: kSurfaceAlt,
                  items: treatments
                      .map<DropdownMenuItem<int>>(
                        (t) => DropdownMenuItem(
                          value: t['id'] as int,
                          child: Text(t['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedTreatment = v),
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: 'Date'),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(selectedDate),
                      style: TextStyle(color: kTextPrimary),
                    ),
                  ),
                ),
              ],
            )),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedPatient == null || selectedTreatment == null) {
                  return;
                }
                await http.post(
                  Uri.parse('$apiBase/appointments'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'patient_id': selectedPatient,
                    'treatment_id': selectedTreatment,
                    'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                  }),
                );
                Navigator.pop(ctx);
                _loadAll();
              },
              child: Text('Create'),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: kAccent));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 16 : 24,
          ),
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
                    width: isMobile ? double.infinity : 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appointments',
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
                          'Manage and monitor all clinic bookings',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: kTextMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activeFilter,
                        dropdownColor: kSurfaceAlt,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: kTextSecondary),
                        style: GoogleFonts.inter(fontSize: 14, color: kTextPrimary, fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Appointments')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                          DropdownMenuItem(value: 'cleared', child: Text('Ready for Procedure')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'canceled', child: Text('Canceled')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => activeFilter = val);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.add_rounded, size: 18),
                        label: Text('New'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _showAddDialog,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: filteredAppointments.isEmpty
                      ? Center(
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
                                  Icons.event_busy_rounded,
                                  size: 36,
                                  color: kTextMuted.withValues(alpha: 0.5),
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No appointments found',
                                style: GoogleFonts.outfit(
                                  color: kTextPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Try a different filter or create a new appointment',
                                style: GoogleFonts.inter(
                                  color: kTextMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 32,
                                  horizontalMargin: 24,
                                  dataRowMinHeight: 64,
                                  dataRowMaxHeight: double.infinity,
                                  headingRowColor: WidgetStateProperty.all(
                                  kSurfaceAlt.withValues(alpha: 0.1),
                                ),
                                dataRowColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.hovered)
                                      ? kSurfaceAlt.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'DATE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'PATIENT ID',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'NAME',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'TREATMENT TYPE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'STATUS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'TREATMENT DATE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'STOCK',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'ACTIONS',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: kTextMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: filteredAppointments.map<DataRow>((apt) {
                                  final status = apt['status'] as String;
                                  final type =
                                      apt['treatment_type']; // string or null
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(DateTime.parse(apt['date'])),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          apt['patient_uid'] ?? '—',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: apt['patient_uid'] != null
                                                ? kTextPrimary
                                                : kTextMuted,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              apt['patient_name'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: kTextPrimary,
                                              ),
                                            ),
                                            Text(
                                              apt['patient_phone'],
                                              style: TextStyle(
                                                color: kTextMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (status == 'pending')
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: 4.0,
                                                ),
                                                child: Text(
                                                  'Source: AI Chatbot',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: kAccent,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        type != null &&
                                                type.toString().isNotEmpty
                                            ? Text(
                                                type
                                                    .toString()
                                                    .replaceAll('_', ' ')
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: kTextPrimary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : Text(
                                                '—',
                                                style: TextStyle(
                                                  color: kTextMuted,
                                                ),
                                              ),
                                      ),
                                      DataCell(_statusBadge(apt)),
                                      DataCell(
                                        Text(
                                          apt['treatment_date'] ?? '—',
                                          style: TextStyle(color: kTextPrimary),
                                        ),
                                      ),
                                      DataCell(_inventoryBadge(apt)),
                                      DataCell(
                                        Wrap(
                                          spacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            if (status == 'pending')
                                              Tooltip(
                                                message: 'Approve',
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: kSuccess,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    minimumSize: Size.zero,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                  ),
                                                  icon: Icon(
                                                    Icons.check_circle_outline,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  label: Text(
                                                    'Approve',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      _approveAppointment(
                                                        apt['id'],
                                                      ),
                                                ),
                                              ),
                                            if (status == 'confirmed')
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: kInfo,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                ),
                                                icon: Icon(
                                                  Icons.medical_services,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                label: Text(
                                                  'Consult',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _consultAppointment(apt),
                                              ),
                                            if (status == 'cleared') ...[
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: kSuccess,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                ),
                                                icon: Icon(
                                                  Icons.calendar_month,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                label: Text(
                                                  apt['treatment_date'] == null
                                                      ? 'Schedule Date'
                                                      : 'Reschedule',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _scheduleTreatment(apt['id']),
                                              ),
                                              SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: kAccent,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size.zero,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                ),
                                                icon: Icon(
                                                  Icons.check_circle,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                label: Text(
                                                  'Complete & Deduct',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _completeAppointment(apt),
                                              ),
                                            ],
                                            if (status == 'completed')
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: kSuccess.withValues(alpha: 0.15),
                                                  foregroundColor: kSuccess,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    side: BorderSide(
                                                      color: kSuccess.withValues(alpha: 0.3),
                                                    ),
                                                  ),
                                                ),
                                                icon: Icon(
                                                  Icons.settings_backup_restore_rounded,
                                                  size: 14,
                                                ),
                                                label: Text(
                                                  'Restock Unused',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _showRestockUnusedDialog(apt),
                                              ),
                                            if (status == 'pending' ||
                                                status == 'confirmed') ...[
                                              SizedBox(width: 8),
                                              InkWell(
                                                onTap: () => _cancelAppointment(
                                                  apt['id'],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: kDanger.withValues(
                                                      alpha: 0.1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: kDanger,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _statusBadge(Map apt) {
    final status = apt['status'] as String;
    bool isTesting = status == 'testing';

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        if (isTesting) ...[
          SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 10, color: kTextPrimary),
        ],
      ],
    );

    return InkWell(
      onTap: isTesting ? () => widget.onNavigate?.call(2, apt['id'].toString()) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kSurfaceAlt.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: content,
      ),
    );
  }

  Widget _inventoryBadge(Map apt) {
    if (apt['status'] == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'DEDUCTED',
          style: TextStyle(
            fontSize: 10,
            color: kTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    if (apt['status'] == 'canceled') return SizedBox();
    if (apt['stockStatus'] == 'Ready') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAccent.withValues(alpha: 0.1)),
        ),
        child: Text(
          'READY',
          style: TextStyle(
            fontSize: 10,
            color: kAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Tooltip(
      message: (apt['lowItems'] as List).join(', '),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kDanger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kDanger.withValues(alpha: 0.1)),
        ),
        child: Text(
          'LOW STOCK',
          style: TextStyle(
            fontSize: 10,
            color: kDanger,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
