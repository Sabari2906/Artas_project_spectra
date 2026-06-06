import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

import '../main.dart'; // To access constants like kAccent, kBgDeep, apiBase

// ============================================================
//  DASHBOARD VIEW
// ============================================================
class DashboardView extends StatefulWidget {
  final void Function(int, [String?])? onNavigate;
  const DashboardView({super.key, this.onNavigate});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  Map<String, dynamic> stats = {};
  List notifications = [];
  List appointments = [];
  bool loading = true;
  StreamSubscription? _refreshSub;
  DateTime _selectedDate = DateTime.now();
  DateTime _displayMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  @override
  void initState() {
    super.initState();
    _load();
    _refreshSub = globalRefresh.stream.listen((_) {
      if (mounted) {
        setState(() => loading = true);
        _load();
      }
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('$apiBase/dashboard/stats')),
        http.get(Uri.parse('$apiBase/notifications')),
        http.get(Uri.parse('$apiBase/appointments')),
      ]);
      if (results[0].statusCode == 200) {
        if (mounted) {
          setState(() {
            stats = json.decode(results[0].body);
            notifications = json.decode(results[1].body);
            appointments = json.decode(results[2].body);
            if (!quiet) loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && !quiet) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: kAccent));
    }

    bool isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 18 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clinic Overview',
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
                      'Real-time clinical intelligence dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kTextMuted,
                        letterSpacing: 0.1,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Bell Notification Icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Tooltip(
                    message: "Alerts",
                    child: IconButton(
                      icon: Icon(Icons.notifications_none_rounded, color: kTextPrimary),
                      onPressed: () => _showAlertsDialog(context),
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: kDanger,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${notifications.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 4),
              SizedBox(width: 4),
              Text(
                DateFormat('EEEE, MMM dd yyyy').format(DateTime.now()),
                style: TextStyle(color: kTextSecondary, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 28),

          // Dashboard Layout Exactly Matching React Reference
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatsGrid(isMobile),
              SizedBox(height: 24),
              _buildIncomingChatbotRequests(),
              SizedBox(height: 24),
              _buildWorkflowPipeline(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingChatbotRequests() {
    final pending = appointments
        .where((a) => a['status'] == 'pending')
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceAlt.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF25D366).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mark_chat_unread,
                color: Color(0xFF25D366),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Live Chatbot Requests (${pending.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF25D366),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                'Awaiting Admin Approval',
                style: TextStyle(color: kTextMuted, fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...pending
              .map(
                (apt) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kBgDeep,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: kAccent.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.person,
                          color: kAccent,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              apt['patient_name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kTextPrimary,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${apt['patient_phone']}  •  ${apt['treatment_name']}',
                              style: TextStyle(
                                color: kTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat(
                                'MMM dd, yyyy',
                              ).format(DateTime.parse(apt['date'])),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kTextPrimary,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Action Required',
                              style: TextStyle(color: kWarning, fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildWorkflowPipeline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kHighlight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.route_rounded, size: 18, color: kHighlight),
            ),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Treatment Workflow',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'ARTAS patient journey from booking to completion',
                style: GoogleFonts.inter(fontSize: 12, color: kTextMuted),
              ),
            ]),
          ]),
          SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: () {
                final steps = [
                  {'label': 'Appointment Request', 'icon': Icons.send_rounded},
                  {'label': 'Admin Approval', 'icon': Icons.check_circle_rounded},
                  {'label': 'Doctor Consultation', 'icon': Icons.medical_services_rounded},
                  {'label': 'Medical Tests', 'icon': Icons.science_rounded},
                  {'label': 'Clearance', 'icon': Icons.verified_rounded},
                  {'label': 'Treatment', 'icon': Icons.healing_rounded},
                ];
                List<Widget> widgets = [];
                for (int i = 0; i < steps.length; i++) {
                  widgets.add(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: kBgDeep,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(steps[i]['icon'] as IconData, size: 16, color: kAccent.withValues(alpha: 0.7)),
                        SizedBox(width: 8),
                        Text(
                          steps[i]['label'] as String,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ]),
                    ),
                  );
                  if (i < steps.length - 1) {
                    widgets.add(
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: kAccent.withValues(alpha: 0.4),
                          size: 18,
                        ),
                      ),
                    );
                  }
                }
                return widgets;
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isMobile) {
    int pending = appointments.where((a) => a['status'] == 'pending').length;
    int testing = appointments.where((a) => a['status'] == 'testing').length;
    int cleared = appointments.where((a) => a['status'] == 'cleared').length;

    List<Widget> cards = [
      _buildPanelCard(
        'APPROVAL PENDING',
        '$pending',
        Icons.access_time_rounded,
        kWarning,
        () => widget.onNavigate?.call(1, 'pending'),
      ),
      _buildPanelCard(
        'CONSULTATION',
        '${stats['confirmed'] ?? 0}',
        Icons.check_circle_outline_rounded,
        kAccent,
        () => widget.onNavigate?.call(1, 'confirmed'),
      ),
      _buildPanelCard(
        'MEDICAL TESTING',
        '$testing',
        Icons.science_outlined,
        kInfo,
        () => widget.onNavigate?.call(2, 'testing'), // Patient Data page (testing patients)
      ),
      _buildPanelCard(
        'TESTING CLEARED',
        '$cleared',
        Icons.shield_outlined,
        const Color(0xFF10B981), // Emerald
        () => widget.onNavigate?.call(2, 'cleared'), // Patient Data page (cleared testing)
      ),
      _buildPanelCard(
        'TREATMENT COMPLETED',
        '${stats['completed'] ?? 0}',
        Icons.show_chart_rounded,
        kHighlight,
        () => widget.onNavigate?.call(1, 'completed'), // Appointments tab with completed filter
      ),
      _buildPanelCard(
        'INVENTORY ALERTS',
        '${stats['lowStock'] ?? 0}',
        Icons.warning_amber_rounded,
        kDanger,
        () => widget.onNavigate?.call(3), // Inventory tab (index 3)
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: c,
              ),
            )
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: cards.take(3)
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: c,
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: 16),
        Row(
          children: cards.skip(3)
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: c,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPanelCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: color.withValues(alpha: 0.04),
        splashColor: color.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: kTextMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kTextSubtle),
        ],
      ),
    )));
  }


  void _changeMonth(int offset) {
    setState(() {
      _displayMonth = DateTime(
        _displayMonth.year,
        _displayMonth.month + offset,
        1,
      );
    });
  }

  void _showAppointmentsModal(BuildContext context, int day) {
    setState(() {
      _selectedDate = DateTime(_displayMonth.year, _displayMonth.month, day);
    });

    showDialog(
      context: context,
      barrierColor: Colors.black87, // Very dark opaque barrier
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        surfaceTintColor:
            Colors.transparent, // Prevent flutter Material tinting
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: kSurface, // Forces an explicit solid backing
          width: 500,
          child: _buildDailyAppointmentsList(),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAppointmentsCard() {
    // Calculate calendar grid variables
    int daysInMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 0).day;
    int firstWeekday = DateTime(_displayMonth.year, _displayMonth.month, 1).weekday % 7;
    int offset = firstWeekday;
    int days = daysInMonth;
    
    // Extract days with appointments
    List<int> daysWithAppointments = [];
    for (var apt in appointments) {
      if (apt['date'] != null) {
        try {
          DateTime d = DateTime.parse(apt['date']);
          if (d.year == _displayMonth.year && d.month == _displayMonth.month) {
            daysWithAppointments.add(d.day);
          }
        } catch (_) {}
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Appointments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: kTextSecondary,
                    size: 20,
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
              ),
              SizedBox(width: 8),
              Text(
                DateFormat('MMMM yyyy').format(_displayMonth),
                style: TextStyle(
                  color: kTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: kTextSecondary,
                    size: 20,
                  ),
                  onPressed: () => _changeMonth(1),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 42,
            itemBuilder: (ctx, i) {
              int day = i - offset + 1;
              if (day < 1 || day > days) return SizedBox();

              bool isSelected =
                  day == _selectedDate.day &&
                  _displayMonth.month == _selectedDate.month &&
                  _displayMonth.year == _selectedDate.year;
              bool today =
                  day == DateTime.now().day &&
                  _displayMonth.month == DateTime.now().month &&
                  _displayMonth.year == DateTime.now().year;
              bool hasApt = daysWithAppointments.contains(day);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAppointmentsModal(context, day),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0D9488)
                          : (today ? kSurfaceAlt : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: kHighlight)
                          : (today ? Border.all(color: kTextSecondary) : null),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (today ? kTextPrimary : kTextSecondary),
                            fontSize: 12,
                            fontWeight: (isSelected || today)
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        if (hasApt)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Color(0xFF2DD4BF),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyAppointmentsList() {
    List dailyAppointments = appointments.where((apt) {
      if (apt['date'] == null) return false;
      try {
        DateTime d = DateTime.parse(apt['date']);
        return d.year == _selectedDate.year &&
            d.month == _selectedDate.month &&
            d.day == _selectedDate.day;
      } catch (_) {
        return false;
      }
    }).toList();

    return Container(
      // Keep height somewhat restricted to mimic Inventory Status panel replacement precisely
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.8,
          colors: [
            const Color(0xFF1E284A).withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${DateFormat('MMMM dd').format(_selectedDate)} Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${dailyAppointments.length} bookings',
                  style: TextStyle(
                    color: kAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: dailyAppointments.isEmpty
                ? Center(
                    child: Text(
                      'No appointments scheduled for this date.',
                      style: TextStyle(color: kTextMuted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: dailyAppointments.length,
                    itemBuilder: (ctx, i) {
                      var apt = dailyAppointments[i];
                      String status = (apt['status'] ?? 'pending')
                          .toString()
                          .toLowerCase();
                      Color statusColor = status == 'confirmed'
                          ? const Color(0xFF3B82F6)
                          : (status == 'completed'
                                ? const Color(0xFF22C55E)
                                : (status == 'canceled' ? kDanger : kWarning));
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kBgDeep,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 48,
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    apt['patient_name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: kTextPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    apt['treatment_name'] ?? 'No Treatment',
                                    style: TextStyle(
                                      color: kTextSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  apt['time'] ?? '--:--',
                                  style: TextStyle(
                                    color: kTextPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: kTextSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, size: 16, color: kTextSecondary),
              SizedBox(width: 10),
              Text(
                'Alerts & Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A0D17),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF5C1C28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFFCA5A5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Low Stock Alert',
                      style: TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFF5C1C28),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'ARTAS IX: 1 Punch Cartridges remaining!',
                  style: TextStyle(color: kTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.receipt_long, size: 16, color: kTextMuted),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminder Sent',
                      style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kBgDeep,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.send, size: 12, color: kAccent),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Appointment Reminder sent to QWERTY at 9:00AM',
                              style: TextStyle(
                                color: kTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildQuickActionsRow(bool isMobile) {
    List<Widget> actionBtns = [
      _quickBtn(
        'New Appointment',
        Icons.add,
        const Color(0xFF10B981),
        const Color(0xFF064E3B),
        () => widget.onNavigate?.call(1),
      ),
      _quickBtn(
        'View Inventory',
        Icons.inventory_2,
        const Color(0xFFFBBF24),
        const Color(0xFF78350F),
        () => widget.onNavigate?.call(3),
      ),
      _quickBtn(
        'Usage Logs',
        Icons.assignment_rounded,
        const Color(0xFFA855F7),
        const Color(0xFF4C1D95),
        () => widget.onNavigate?.call(4),
      ),
    ];

    Widget content = isMobile
        ? Column(
            children: [
              Row(
                children: [
                  Expanded(child: actionBtns[0]),
                  SizedBox(width: 16),
                  Expanded(child: actionBtns[1]),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: actionBtns[2]),
                  SizedBox(width: 16),
                  const Spacer(),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: actionBtns[0]),
              SizedBox(width: 16),
              Expanded(child: actionBtns[1]),
              SizedBox(width: 16),
              Expanded(child: actionBtns[2]),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: 16),
        content,
      ],
    );
  }

  Widget _quickBtn(
    String label,
    IconData icon,
    Color iconColor,
    Color bgCircle,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceAlt.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgCircle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                SizedBox(height: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: kTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: kSurface,
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, color: kDanger),
                      SizedBox(width: 8),
                      Text(
                        'Alert Notifications',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: kTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: kBorder, height: 32),
              if (notifications.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No new alerts at this time.',
                      style: TextStyle(color: kTextSecondary, fontSize: 15),
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: notifications.map((notif) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A0D17),
                            border: Border.all(color: const Color(0xFF5C1C28)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFF87171),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  notif['message'].toString(),
                                  style: TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



