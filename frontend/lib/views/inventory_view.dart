import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../main.dart';

class _DateDDMMYYYY extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) return oldValue;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('-');
      buf.write(digits[i]);
    }
    final result = buf.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  List _inventory = [];
  List _treatments = [];
  List _accessories = [];
  bool _loading = true;
  StreamSubscription? _refreshSub;

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$apiBase/inventory')),
        http.get(Uri.parse('$apiBase/treatments')),
        http.get(Uri.parse('$apiBase/treatment-accessories')),
      ]);
      setState(() {
        _inventory   = json.decode(results[0].body);
        _treatments  = json.decode(results[1].body);
        _accessories = json.decode(results[2].body);
        _loading     = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  InputDecoration _dialogField(String label, {String? hint, Widget? prefix}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: GoogleFonts.inter(fontSize: 13.0, color: kTextMuted, fontWeight: FontWeight.w500),
    hintStyle: GoogleFonts.inter(fontSize: 13.0, color: kTextMuted.withValues(alpha: 0.6)),
    prefixIcon: prefix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
    filled: true,
    fillColor: kSurfaceAlt.withValues(alpha: 0.08),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: kBorder, width: 1.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: kAccent, width: 2.0),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide(color: kDanger, width: 1.5),
    ),
  );

  Future<void> _showAddItemDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final thrCtrl = TextEditingController(text: '5');
    final batchCtrl = TextEditingController();
    final expCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(Icons.inventory_2_rounded, color: kAccent, size: 22.0),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add New Accessory',
                            style: GoogleFonts.outfit(
                              fontSize: 20.0,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary,
                              letterSpacing: -0.3,
                            )),
                          const SizedBox(height: 2.0),
                          Text('Fill in the details below to add a new item',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: kTextMuted,
                            )),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: Icon(Icons.close_rounded, color: kTextMuted, size: 20.0),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),
                Divider(color: kBorder, height: 1),
                const SizedBox(height: 24.0),

                // Item Name
                Text('Item Name *',
                  style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 8.0),
                TextField(
                  controller: nameCtrl,
                  style: GoogleFonts.inter(fontSize: 14.0, color: kTextPrimary),
                  decoration: _dialogField('', hint: 'e.g. Gloves, Syringes, Cotton Pads',
                    prefix: Icon(Icons.label_outline_rounded, color: kTextMuted, size: 18.0)),
                ),
                const SizedBox(height: 18.0),

                // Qty + Threshold row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quantity *',
                            style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600, color: kTextPrimary)),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 14.0, color: kTextPrimary, fontWeight: FontWeight.w600),
                            decoration: _dialogField('', hint: '0',
                              prefix: Icon(Icons.inventory_rounded, color: kTextMuted, size: 18.0)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Low Stock Alert',
                            style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600, color: kTextPrimary)),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: thrCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 14.0, color: kTextPrimary),
                            decoration: _dialogField('', hint: '5',
                              prefix: Icon(Icons.warning_amber_rounded, color: kTextMuted, size: 18.0)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18.0),

                // Batch + Expiry row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Batch Number',
                            style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600, color: kTextPrimary)),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: batchCtrl,
                            style: GoogleFonts.inter(fontSize: 14.0, color: kTextPrimary),
                            decoration: _dialogField('', hint: 'e.g. BT-2024-001',
                              prefix: Icon(Icons.qr_code_rounded, color: kTextMuted, size: 18.0)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expiry Date',
                            style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w600, color: kTextPrimary)),
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: expCtrl,
                            inputFormatters: [_DateDDMMYYYY()],
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 14.0, color: kTextPrimary),
                            decoration: _dialogField('', hint: 'DD-MM-YYYY',
                              prefix: Icon(Icons.calendar_today_rounded, color: kTextMuted, size: 18.0)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28.0),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          side: BorderSide(color: kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        ),
                        child: Text('Cancel',
                          style: GoogleFonts.inter(fontSize: 14.0, fontWeight: FontWeight.w600, color: kTextSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 18.0),
                            const SizedBox(width: 6.0),
                            Text('Add Accessory',
                              style: GoogleFonts.inter(fontSize: 14.0, fontWeight: FontWeight.w600)),
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
      )
    );

    if (confirm == true && nameCtrl.text.isNotEmpty) {
      await http.post(
        Uri.parse('$apiBase/inventory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'item_name': nameCtrl.text,
          'quantity': int.tryParse(qtyCtrl.text) ?? 0,
          'threshold': int.tryParse(thrCtrl.text) ?? 5,
          'batch_no': batchCtrl.text.isEmpty ? null : batchCtrl.text,
          'expiry_date': expCtrl.text.isEmpty ? null : expCtrl.text,
        })
      );
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 768;
      return Container(
        color: kBgDeep,
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 16.0,
            runSpacing: 16.0,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inventory Management', 
                      style: GoogleFonts.outfit(fontSize: 28.0, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5, height: 1.2)),
                    SizedBox(height: 8.0),
                    Text('Manage stock and treatment accessories',
                      style: GoogleFonts.inter(fontSize: 14.0, color: kTextMuted, height: 1.5)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.add_rounded, size: 18.0),
                label: Text('Add Accessories', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.0)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
                onPressed: _showAddItemDialog,
              ),
            ],
          ),
          SizedBox(height: 24.0),
          if (_loading)
            Expanded(child: Center(child: CircularProgressIndicator(color: kAccent, strokeWidth: 2.5)))
          else
            Expanded(child: _InventoryTab(
              inventory: _inventory,
              treatments: _treatments,
              accessories: _accessories,
              onChanged: _loadAll,
            )),
        ]),
      );
    });
  }
}

class _InventoryTab extends StatefulWidget {
  final List inventory, treatments, accessories;
  final VoidCallback onChanged;
  const _InventoryTab({required this.inventory, required this.treatments, required this.accessories, required this.onChanged});
  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _filterLowStock = false;
  int? _selectedTreatmentId;
  List _filteredInventory = [];
  final Map<int, bool> _editingMode = {};
  final Map<int, Map<String, TextEditingController>> _ctrls = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilters);
    _filteredInventory = List.from(widget.inventory);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final m in _ctrls.values) for (final c in m.values) c.dispose();
    super.dispose();
  }

  void _initCtrl(Map item) {
    final id = item['id'] as int;
    if (!_ctrls.containsKey(id)) {
      _ctrls[id] = {
        'name': TextEditingController(text: '${item['item_name']}'),
        'qty': TextEditingController(text: '${item['quantity']}'),
        'thr': TextEditingController(text: '${item['threshold']}'),
        'batch': TextEditingController(text: item['batch_no'] ?? ''),
        'exp': TextEditingController(text: item['expiry_date'] ?? ''),
      };
      _editingMode[id] = false;
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredInventory = widget.inventory.where((item) {
        final name = '${item['item_name']}'.toLowerCase();
        final query = _searchCtrl.text.toLowerCase();
        final matchesSearch = query.isEmpty || name.contains(query);
        final matchesLowStock = !_filterLowStock || (item['quantity'] <= item['threshold']);
        final matchesTreatment = _selectedTreatmentId == null || widget.accessories
            .where((acc) => acc['treatment_id'] == _selectedTreatmentId && acc['inventory_id'] == item['id'])
            .isNotEmpty;
        return matchesSearch && matchesLowStock && matchesTreatment;
      }).toList();
    });
  }

  InputDecoration _cellField(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 12.0, color: kTextMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: kAccent, width: 2.0),
    ),
    filled: true,
    fillColor: kSurfaceAlt.withValues(alpha: 0.1),
    isDense: true,
  );

  Future<void> _saveItem(Map item) async {
    final id = item['id'] as int;
    final c = _ctrls[id]!;
    await http.put(
      Uri.parse('$apiBase/inventory/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'item_name': c['name']!.text,
        'quantity': int.tryParse(c['qty']!.text) ?? 0,
        'threshold': int.tryParse(c['thr']!.text) ?? 5,
        'batch_no': c['batch']!.text,
        'expiry_date': c['exp']!.text,
      }),
    );
    setState(() => _editingMode[id] = false);
    widget.onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item updated successfully',
          style: GoogleFonts.inter(fontSize: 13.0, fontWeight: FontWeight.w500)),
        backgroundColor: kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ));
  }

  Future<void> _deleteItem(Map item) async {
    final reasonCtrl = TextEditingController();
    final id = item['id'] as int;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Soft Delete Accessory', style: TextStyle(color: kTextPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${item['item_name']}"? This item can be restored within 30 days.',
                style: TextStyle(color: kTextSecondary, fontSize: 14.0),
              ),
              SizedBox(height: 16),
              Text(
                'Reason for deletion',
                style: TextStyle(color: kTextPrimary, fontSize: 13.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(color: kTextPrimary, fontSize: 13.0),
                decoration: InputDecoration(
                  hintText: 'Enter reason (e.g., Damaged, Expired, Discontinued)...',
                  hintStyle: TextStyle(color: kTextMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Soft Delete'),
          ),
        ],
      )
    );

    if (confirm != true) return;

    try {
      await http.post(
        Uri.parse('$apiBase/inventory/$id/soft-delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'reason': reasonCtrl.text.isEmpty ? 'User action' : reasonCtrl.text,
          'user_id': 'admin'
        })
      );
      
      widget.onChanged();
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item['item_name']}" soft-deleted.'),
          backgroundColor: kBgDark,
          action: SnackBarAction(
            textColor: kAccent,
            label: 'UNDO',
            onPressed: () async {
              try {
                final undoRes = await http.post(
                  Uri.parse('$apiBase/inventory/$id/undo-delete'),
                );
                if (undoRes.statusCode == 200) {
                  widget.onChanged();
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _adjustStock(Map item) async {
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final id = item['id'] as int;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Stock: ${item['item_name']}', style: TextStyle(color: kTextPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current stock: ${item['quantity']}',
                style: TextStyle(color: kTextSecondary, fontSize: 13.0),
              ),
              SizedBox(height: 16),
              Text(
                'Quantity change (+ for restock, - for deduction)',
                style: TextStyle(color: kTextPrimary, fontSize: 13.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.numberWithOptions(signed: true),
                style: TextStyle(color: kTextPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. +10 or -5',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Reason for adjustment',
                style: TextStyle(color: kTextPrimary, fontSize: 13.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: TextStyle(color: kTextPrimary, fontSize: 13.0),
                decoration: InputDecoration(
                  hintText: 'Enter reason (e.g. Manual inventory count, damaged item)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Adjust'),
          ),
        ],
      )
    );

    if (confirm != true) return;

    final change = int.tryParse(qtyCtrl.text) ?? 0;
    if (change == 0) return;

    try {
      final res = await http.post(
        Uri.parse('$apiBase/inventory/$id/adjust-stock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'quantity_change': change,
          'reason': reasonCtrl.text.isEmpty ? 'Manual adjustment' : reasonCtrl.text,
          'user_id': 'admin'
        })
      );
      final body = json.decode(res.body);
      if (res.statusCode == 200) {
        widget.onChanged();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['message']), backgroundColor: kSuccess),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${body['error']}'), backgroundColor: kDanger),
        );
      }
    } catch (_) {}
  }

  // ─── Mobile card for one inventory item ───────────────────────────────────
  Widget _mobileCard(Map item, int index) {
    _initCtrl(item);
    final id = item['id'] as int;
    final c = _ctrls[id]!;
    final isLow = (item['quantity'] as int) <= (item['threshold'] as int);
    final isEditing = _editingMode[id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: isLow ? kDanger.withValues(alpha: 0.4) : kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name row + status badge
            Row(
              children: [
                Expanded(
                  child: isEditing
                    ? TextField(
                        controller: c['name'],
                        style: GoogleFonts.inter(fontSize: 15.0, color: kTextPrimary, fontWeight: FontWeight.w700),
                        decoration: _cellField('Item name'),
                      )
                    : Text(c['name']!.text,
                        style: GoogleFonts.outfit(fontSize: 15.0, color: kTextPrimary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: isLow ? kDanger.withValues(alpha: 0.12) : kSuccess.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: isLow ? kDanger.withValues(alpha: 0.4) : kSuccess.withValues(alpha: 0.4)),
                  ),
                  child: Text(isLow ? 'LOW STOCK' : 'SUFFICIENT',
                    style: GoogleFonts.inter(
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: isLow ? kDanger : kSuccess,
                      letterSpacing: 0.4)),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            // Qty / Threshold / Batch / Expiry
            Wrap(
              spacing: 16.0,
              runSpacing: 10.0,
              children: [
                _mobileField('Qty', c['qty']!, isEditing, isNumeric: true, width: 70),
                _mobileField('Threshold', c['thr']!, isEditing, isNumeric: true, width: 90),
                _mobileField('Batch', c['batch']!, isEditing, width: 110),
                _mobileField('Expiry', c['exp']!, isEditing,
                  isDate: true, width: 120),
              ],
            ),
            const SizedBox(height: 14.0),
            Divider(color: kBorder, height: 1),
            const SizedBox(height: 10.0),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: isEditing
                ? [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _editingMode[id] = false),
                      icon: Icon(Icons.close_rounded, size: 15.0),
                      label: Text('Cancel', style: GoogleFonts.inter(fontSize: 12.0)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextMuted,
                        side: BorderSide(color: kBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton.icon(
                      onPressed: () => _saveItem(item),
                      icon: Icon(Icons.check_rounded, size: 15.0),
                      label: Text('Save', style: GoogleFonts.inter(fontSize: 12.0, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      ),
                    ),
                  ]
                : [
                    _iconBtn(Icons.edit_rounded, kAccent, 'Edit', () => setState(() => _editingMode[id] = true)),
                    const SizedBox(width: 6.0),
                    _iconBtn(Icons.swap_vert_rounded, kInfo, 'Adjust Stock', () => _adjustStock(item)),
                    const SizedBox(width: 6.0),
                    _iconBtn(Icons.delete_outline_rounded, kTextMuted, 'Delete', () => _deleteItem(item)),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileField(String label, TextEditingController ctrl, bool isEditing,
      {bool isNumeric = false, bool isDate = false, double width = 100}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.0, fontWeight: FontWeight.w600, color: kTextMuted, letterSpacing: 0.3)),
        const SizedBox(height: 4.0),
        isEditing
          ? SizedBox(
              width: width,
              child: TextField(
                controller: ctrl,
                keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                inputFormatters: isDate ? [_DateDDMMYYYY()] : [],
                style: GoogleFonts.inter(fontSize: 13.0, color: kTextPrimary),
                decoration: _cellField(label),
              ))
          : Text(
              ctrl.text.isEmpty ? '—' : ctrl.text,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: kTextPrimary,
                fontWeight: isNumeric ? FontWeight.w700 : FontWeight.w400,
              )),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, size: 16.0, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search & Filter Row
      Wrap(
        spacing: 10.0,
        runSpacing: 10.0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: isMobile ? double.infinity : 300.0,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: kBorder),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(fontSize: 13.0, color: kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search item name...',
                hintStyle: GoogleFonts.inter(fontSize: 13.0, color: kTextMuted),
                prefixIcon: Icon(Icons.search_rounded, color: kTextMuted, size: 18.0),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _filterLowStock ? kTextMuted.withValues(alpha: 0.1) : kSurface,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: _filterLowStock ? kTextMuted.withValues(alpha: 0.3) : kBorder),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() { _filterLowStock = !_filterLowStock; _applyFilters(); }),
                borderRadius: BorderRadius.circular(10.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_rounded, size: 16.0, color: _filterLowStock ? kTextPrimary : kTextMuted),
                    SizedBox(width: 6.0),
                    Text('Low Stock', style: GoogleFonts.inter(
                      fontSize: 13.0, fontWeight: FontWeight.w600,
                      color: _filterLowStock ? kTextPrimary : kTextSecondary)),
                  ]),
                ),
              ),
            ),
          ),
          // Treatment Filter Dropdown
          Container(
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: kBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: DropdownButton<int?>(
                value: _selectedTreatmentId,
                underline: const SizedBox(),
                isDense: true,
                style: GoogleFonts.inter(fontSize: 13.0, color: kTextPrimary),
                items: [
                  DropdownMenuItem(value: null, child: Text('All Treatments', style: GoogleFonts.inter(fontSize: 13.0))),
                  ...widget.treatments.map((t) => DropdownMenuItem(
                    value: t['id'] as int?,
                    child: Text(t['name'], style: GoogleFonts.inter(fontSize: 13.0)),
                  )),
                ],
                onChanged: (v) => setState(() { _selectedTreatmentId = v; _applyFilters(); }),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 16.0),
      // Results info
      if (_searchCtrl.text.isNotEmpty || _filterLowStock || _selectedTreatmentId != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Showing ${_filteredInventory.length} of ${widget.inventory.length} items',
              style: GoogleFonts.inter(fontSize: 12.0, color: kTextMuted)))),
      // ─── Inventory list: cards on mobile, table on desktop ───────────────
      Expanded(
        child: isMobile
          ? (_filteredInventory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48.0, color: kTextMuted),
                      const SizedBox(height: 12.0),
                      Text('No items found',
                        style: GoogleFonts.inter(fontSize: 15.0, color: kTextMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredInventory.length,
                  itemBuilder: (_, i) => _mobileCard(_filteredInventory[i], i),
                )
            )
          : Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(color: kBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13.0),
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, tableConstraints) {
                      return _buildDesktopTable(tableConstraints.maxWidth);
                    },
                  ),
                ),
              ),
            ),
      ),
    ]);
  }

  Widget _buildDesktopTable(double tableWidth) {
    // Column flex ratios: name=3, qty=1, threshold=1, batch=2, expiry=2, status=2.5, actions=2
    const colFlex = [3.0, 1.0, 1.0, 2.0, 2.0, 2.5, 2.0];
    final totalFlex = colFlex.reduce((a, b) => a + b);
    final margin = 20.0;
    final spacing = 12.0;
    final usable = tableWidth - (margin * 2) - (spacing * (colFlex.length - 1));
    final colWidths = colFlex.map((f) => (usable * f / totalFlex)).toList();

    final headers = ['ITEM NAME', 'QTY', 'THRESHOLD', 'BATCH NO.', 'EXPIRY DATE', 'STATUS', 'ACTIONS'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ──
        Container(
          width: double.infinity,
          color: kSurfaceAlt.withValues(alpha: 0.12),
          padding: EdgeInsets.symmetric(horizontal: margin, vertical: 14.0),
          child: Row(
            children: List.generate(headers.length, (i) {
              return SizedBox(
                width: colWidths[i],
                child: Padding(
                  padding: EdgeInsets.only(right: i < headers.length - 1 ? spacing : 0),
                  child: Text(headers[i],
                    style: GoogleFonts.inter(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: kTextMuted,
                      letterSpacing: 0.5,
                    )),
                ),
              );
            }),
          ),
        ),
        Divider(height: 1, color: kBorder),
        // ── Data rows ──
        if (_filteredInventory.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 44.0, color: kTextMuted),
                  const SizedBox(height: 10.0),
                  Text('No items found',
                    style: GoogleFonts.inter(fontSize: 14.0, color: kTextMuted)),
                ],
              ),
            ),
          )
        else
          ...(_filteredInventory.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            _initCtrl(item);
            final id = item['id'] as int;
            final c = _ctrls[id]!;
            final isLow = (item['quantity'] as int) <= (item['threshold'] as int);
            final isEditing = _editingMode[id] ?? false;

            return Column(
              children: [
                Container(
                  color: index.isEven ? Colors.transparent : kSurfaceAlt.withValues(alpha: 0.15),
                  padding: EdgeInsets.symmetric(horizontal: margin, vertical: 14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Item Name
                      SizedBox(
                        width: colWidths[0],
                        child: Padding(
                          padding: EdgeInsets.only(right: spacing),
                          child: isEditing
                            ? TextField(
                                controller: c['name'],
                                style: GoogleFonts.inter(fontSize: 13.5, color: kTextPrimary, fontWeight: FontWeight.w600),
                                decoration: _cellField('Item name'),
                              )
                            : Tooltip(
                                message: 'Click to edit',
                                child: InkWell(
                                  onTap: () => setState(() => _editingMode[id] = true),
                                  child: Text(c['name']!.text,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: kTextPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                        ),
                      ),
                      // Qty
                      SizedBox(
                        width: colWidths[1],
                        child: Padding(
                          padding: EdgeInsets.only(right: spacing),
                          child: isEditing
                            ? TextField(
                                controller: c['qty'],
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontSize: 14.0, color: kTextPrimary, fontWeight: FontWeight.w700),
                                decoration: _cellField('Qty'),
                              )
                            : Text(c['qty']!.text,
                                style: GoogleFonts.inter(fontSize: 14.0, color: kTextPrimary, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      // Threshold
                      SizedBox(
                        width: colWidths[2],
                        child: Padding(
                          padding: EdgeInsets.only(right: spacing),
                          child: isEditing
                            ? TextField(
                                controller: c['thr'],
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontSize: 13.0, color: kTextSecondary),
                                decoration: _cellField('Thr'),
                              )
                            : Text(c['thr']!.text,
                                style: GoogleFonts.inter(fontSize: 13.0, color: kTextSecondary)),
                        ),
                      ),
                      // Batch
                      SizedBox(
                        width: colWidths[3],
                        child: Padding(
                          padding: EdgeInsets.only(right: spacing),
                          child: isEditing
                            ? TextField(
                                controller: c['batch'],
                                style: GoogleFonts.inter(fontSize: 13.0, color: kTextPrimary),
                                decoration: _cellField('Batch no.'),
                              )
                            : Text(c['batch']!.text.isEmpty ? '—' : c['batch']!.text,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: c['batch']!.text.isEmpty ? kTextMuted : kTextSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                        ),
                      ),
                      // Expiry
                      SizedBox(
                        width: colWidths[4],
                        child: Padding(
                          padding: EdgeInsets.only(right: spacing),
                          child: isEditing
                            ? TextField(
                                controller: c['exp'],
                                inputFormatters: [_DateDDMMYYYY()],
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.inter(fontSize: 13.0, color: kTextPrimary),
                                decoration: _cellField('DD-MM-YYYY'),
                              )
                            : Text(c['exp']!.text.isEmpty ? '—' : c['exp']!.text,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: c['exp']!.text.isEmpty ? kTextMuted : kTextSecondary,
                                ),
                              ),
                        ),
                      ),
                      // Status badge
                      SizedBox(
                        width: colWidths[5],
                        child: Padding(
                          padding: EdgeInsets.only(right: spacing),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: isLow
                                ? kDanger.withValues(alpha: 0.12)
                                : kSuccess.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: isLow
                                  ? kDanger.withValues(alpha: 0.4)
                                  : kSuccess.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              isLow ? 'LOW' : 'OK',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: isLow ? kDanger : kSuccess,
                                letterSpacing: 0.4,
                              )),
                          ),
                        ),
                      ),
                      // Actions
                      SizedBox(
                        width: colWidths[6],
                        child: isEditing
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              _iconBtn(Icons.check_rounded, kAccent, 'Save', () => _saveItem(item)),
                              const SizedBox(width: 6.0),
                              _iconBtn(Icons.close_rounded, kTextMuted, 'Cancel',
                                () => setState(() => _editingMode[id] = false)),
                            ])
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              _iconBtn(Icons.edit_rounded, kAccent, 'Edit item',
                                () => setState(() => _editingMode[id] = true)),
                              const SizedBox(width: 6.0),
                              _iconBtn(Icons.swap_vert_rounded, kInfo, 'Adjust Stock',
                                () => _adjustStock(item)),
                              const SizedBox(width: 6.0),
                              _iconBtn(Icons.delete_outline_rounded, kTextMuted, 'Delete item',
                                () => _deleteItem(item)),
                            ]),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: kBorder.withValues(alpha: 0.5)),
              ],
            );
          }).toList()),
      ],
    );
  }
}
