import 'views/patient_data_view.dart';
import 'views/usage_logs_view.dart';
import 'views/inventory_view.dart';
import 'views/appointments_view.dart';
import 'views/dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';


const String apiBase = 'http://localhost:5000/api';
final StreamController<void> globalRefresh = StreamController<void>.broadcast();


// ============================================================
//  DYNAMIC THEME COLOR SYSTEM
// ============================================================
class ThemeManager {
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(true);
}

Color get kBgDeep      => ThemeManager.isDark.value ? const Color(0xFF080C14) : const Color(0xFFF1F5F9);
Color get kBgDark      => ThemeManager.isDark.value ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF);
Color get kSurface     => ThemeManager.isDark.value ? const Color(0xFF161B24) : const Color(0xFFFFFFFF);
Color get kSurfaceAlt  => ThemeManager.isDark.value ? const Color(0xFF1E2530) : const Color(0xFFF8FAFC);
Color get kSurfaceHigh => ThemeManager.isDark.value ? const Color(0xFF252D3A) : const Color(0xFFE2E8F0);

Color get kBorder      => ThemeManager.isDark.value ? const Color(0x18FFFFFF) : const Color(0xFFE2E8F0);
Color get kBorderFocus => ThemeManager.isDark.value ? const Color(0x33FFFFFF) : const Color(0xFFCBD5E1);

const Color kAccent     = Color(0xFF3B82F6);
const Color kAccentDim  = Color(0xFF2563EB);
const Color kHighlight  = Color(0xFF8B5CF6);
const Color kInfo       = Color(0xFF06B6D4);
const Color kSuccess    = Color(0xFF10B981);
const Color kDanger     = Color(0xFFEF4444);
const Color kWarning    = Color(0xFFF59E0B);

Color get kTextPrimary   => ThemeManager.isDark.value ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
Color get kTextSecondary => ThemeManager.isDark.value ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
Color get kTextMuted     => ThemeManager.isDark.value ? const Color(0xFF64748B) : const Color(0xFF475569);
Color get kTextSubtle    => ThemeManager.isDark.value ? const Color(0xFF475569) : const Color(0xFF64748B);

void main() {
  runApp(const AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.isDark,
      builder: (context, isDark, _) {
        final textTheme = GoogleFonts.outfitTextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme).copyWith(
          displayLarge: GoogleFonts.outfit(color: kTextPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.2),
          headlineMedium: GoogleFonts.outfit(color: kTextPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.3),
          titleLarge: GoogleFonts.outfit(color: kTextPrimary, fontSize: 18, fontWeight: FontWeight.w700, height: 1.4),
          titleMedium: GoogleFonts.outfit(color: kTextPrimary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
          bodyLarge: GoogleFonts.inter(color: kTextPrimary, fontSize: 15, height: 1.6),
          bodyMedium: GoogleFonts.inter(color: kTextSecondary, fontSize: 14, height: 1.6),
          bodySmall: GoogleFonts.inter(color: kTextMuted, fontSize: 12, height: 1.5),
          labelLarge: GoogleFonts.inter(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          labelSmall: GoogleFonts.inter(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        );

        return MaterialApp(
          title: 'ARTAS Clinic',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: kBgDeep,
            primaryColor: kAccent,
            textTheme: textTheme,
            colorScheme: ColorScheme.light(
              primary: kAccent,
              secondary: kInfo,
              surface: kSurface,
              error: kDanger,
            ),
            cardTheme: CardThemeData(
              color: kSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: kBorder),
              ),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: kBgDark,
              elevation: 0,
              titleTextStyle: GoogleFonts.outfit(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              iconTheme: IconThemeData(color: kTextPrimary),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: kBgDark,
              labelStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              hintStyle: GoogleFonts.inter(color: kTextMuted, fontSize: 13),
              floatingLabelStyle: GoogleFonts.inter(color: kAccent, fontSize: 13, fontWeight: FontWeight.w600),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kAccent, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDanger, width: 1.5),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: kSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: kBorder),
              ),
              titleTextStyle: GoogleFonts.outfit(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return kAccent.withValues(alpha: 0.4);
                  if (states.contains(WidgetState.hovered)) return kAccentDim;
                  return kAccent;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
                elevation: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) return 4;
                  return 0;
                }),
                shadowColor: WidgetStateProperty.all(kAccent.withValues(alpha: 0.3)),
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                textStyle: WidgetStateProperty.all(GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.3,
                )),
                animationDuration: const Duration(milliseconds: 200),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: kTextSecondary,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: kSurface,
              contentTextStyle: GoogleFonts.inter(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              behavior: SnackBarBehavior.floating,
              elevation: 8,
              width: 420,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            dividerColor: kBorder,
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: kBgDeep,
            primaryColor: kAccent,
            textTheme: textTheme,
            colorScheme: ColorScheme.dark(
              primary: kAccent,
              secondary: kInfo,
              surface: kSurface,
              error: kDanger,
            ),
            cardTheme: CardThemeData(
              color: kSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: kBorder),
              ),
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: kBgDark,
              elevation: 0,
              titleTextStyle: GoogleFonts.outfit(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              iconTheme: IconThemeData(color: kTextPrimary),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: kBgDark,
              labelStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              hintStyle: GoogleFonts.inter(color: kTextMuted, fontSize: 13),
              floatingLabelStyle: GoogleFonts.inter(color: kAccent, fontSize: 13, fontWeight: FontWeight.w600),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kAccent, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDanger, width: 1.5),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: kSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: kBorder),
              ),
              titleTextStyle: GoogleFonts.outfit(
                color: kTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) return kAccent.withValues(alpha: 0.4);
                  if (states.contains(WidgetState.hovered)) return kAccentDim;
                  return kAccent;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
                elevation: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) return 4;
                  return 0;
                }),
                shadowColor: WidgetStateProperty.all(kAccent.withValues(alpha: 0.3)),
                padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                textStyle: WidgetStateProperty.all(GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.3,
                )),
                animationDuration: const Duration(milliseconds: 200),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: kTextSecondary,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: kSurface,
              contentTextStyle: GoogleFonts.inter(color: kTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              behavior: SnackBarBehavior.floating,
              elevation: 8,
              width: 420,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            dividerColor: kBorder,
          ),
          home: MainLayout(),
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _appointmentsFilter;
  int _appointKeyCounter = 0;
  int _notificationCount = 0;

  String? _patientDataSelectedApt;
  String? _patientDataInitialFilter;
  int _patientDataKeyCounter = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotificationCount();
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/notifications'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List;
        if (mounted) setState(() => _notificationCount = data.length);
      }
    } catch (_) {}
  }

  final List<_NavItem> _navItems = [
    _NavItem(Icons.dashboard_rounded,      'Dashboard'),
    _NavItem(Icons.calendar_month_rounded, 'Appointments'),
    _NavItem(Icons.person_search_rounded,  'Patient Data'),
    _NavItem(Icons.inventory_2_rounded,    'Inventory'),
    _NavItem(Icons.assignment_rounded,     'Usage Logs'),
  ];

  @override
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: _selectedIndex,
      children: [
        DashboardView(onNavigate: (i, [filter]) => setState(() {
          _selectedIndex = i;
          if (i == 1) {
            _appointmentsFilter = filter ?? 'all';
            _appointKeyCounter++;
          } else if (i == 2) {
            _patientDataInitialFilter = filter;
            _patientDataSelectedApt = null;
            _patientDataKeyCounter++;
          }
        })),
        AppointmentsView(
          key: ValueKey('appointments_$_appointKeyCounter'),
          onNavigate: (i, [extra]) => setState(() {
            _selectedIndex = i;
            if (i == 1) {
              _appointmentsFilter = extra ?? 'all';
              _appointKeyCounter++;
            } else if (i == 2) {
              _patientDataSelectedApt = extra;
              _patientDataInitialFilter = null;
              _patientDataKeyCounter++;
            }
          }),
          initialFilter: _appointmentsFilter,
        ),
        PatientDataView(
          key: ValueKey('patient_data_$_patientDataKeyCounter'),
          initialFilter: _patientDataInitialFilter,
          initialAppointmentId: _patientDataSelectedApt,
          onNavigate: (i, [extra]) => setState(() {
            _selectedIndex = i;
            if (i == 1) {
              _appointmentsFilter = extra ?? 'all';
              _appointKeyCounter++;
            }
          }),
        ),
        InventoryView(),
        UsageLogsView(),
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      final bool isMobile = constraints.maxWidth < 850;

      final toggleBtn = ValueListenableBuilder<bool>(
        valueListenable: ThemeManager.isDark,
        builder: (context, isDark, _) => IconButton(
          tooltip: 'Toggle Theme',
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, 
            color: isMobile ? Colors.white : kTextPrimary),
          onPressed: () => ThemeManager.isDark.value = !isDark,
        ),
      );

      final refreshBtn = IconButton(
        tooltip: 'Refresh',
        icon: Icon(Icons.refresh_rounded, 
          color: isMobile ? Colors.white : kTextPrimary),
        onPressed: () => globalRefresh.add(null),
      );

      if (isMobile) {
        return Scaffold(
          appBar: AppBar(
            iconTheme: IconThemeData(color: kTextPrimary),
            centerTitle: true,
            title: Text(_navItems[_selectedIndex].label,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            actions: [refreshBtn, toggleBtn, const SizedBox(width: 8)],
          ),
          drawer: Drawer(
            backgroundColor: kBgDark,
            child: _buildSidebar(),
          ),
          body: content,
        );
      }

      return Scaffold(
        body: Row(children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: kBgDark,
                    border: Border(bottom: BorderSide(color: kBorder)),
                  ),
                  child: Row(
                    children: [
                      Text(_navItems[_selectedIndex].label,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17, color: kTextPrimary, letterSpacing: -0.2)),
                      const Spacer(),
                      refreshBtn,
                      toggleBtn,
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
    });
  }

  Widget _buildSidebar() {
    return Container(
      width: 256,
      decoration: BoxDecoration(
        color: kBgDark,
        border: Border(right: BorderSide(color: kBorder, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(4, 0)),
        ],
      ),
      child: Column(children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: kAccent.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 2))],
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/spectra_logo.png', fit: BoxFit.contain)),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Spectra Clinic',
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.3)),
              Text('Admin Portal',
                style: GoogleFonts.inter(fontSize: 11, color: kTextMuted, letterSpacing: 0.5, fontWeight: FontWeight.w500)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(color: kBorder, height: 28),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('NAVIGATION',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSubtle, letterSpacing: 1.4))),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _navItems.length,
            itemBuilder: (ctx, i) => _buildNavItem(i),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Divider(color: kBorder, height: 1),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSurfaceAlt.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 8)]),
                  child: const Icon(Icons.person_rounded, size: 18, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Administrator',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
                  Text('Clinic Admin',
                    style: GoogleFonts.inter(fontSize: 11, color: kTextMuted)),
                ])),
              ]),
            ),
            const SizedBox(height: 12),
            Text('© 2026 Spectra Artas Treatment',
              style: GoogleFonts.inter(color: kTextSubtle, fontSize: 10, fontWeight: FontWeight.w400)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildNavItem(int i) {
    final bool active = _selectedIndex == i;
    return _AnimatedNavItem(
      item: _navItems[i],
      active: active,
      notificationCount: i == 0 ? _notificationCount : 0,
      onTap: () {
        setState(() {
          _selectedIndex = i;
          if (i == 2) {
            _patientDataSelectedApt = null;
            _patientDataInitialFilter = null;
            _patientDataKeyCounter++;
          }
        });
        if (i == 0) _fetchNotificationCount();
      },
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  final _NavItem item;
  final bool active;
  final int notificationCount;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.item,
    required this.active,
    required this.notificationCount,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.active;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: active
                ? kAccent.withValues(alpha: 0.12)
                : (_hovered ? kSurfaceAlt.withValues(alpha: 0.5) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? kAccent.withValues(alpha: 0.3) : Colors.transparent),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3, height: active ? 18 : 0,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: kAccent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: active ? [BoxShadow(color: kAccent.withValues(alpha: 0.5), blurRadius: 6)] : [],
                ),
              ),
              Icon(widget.item.icon, size: 18,
                color: active ? kAccent : (_hovered ? kTextSecondary : kTextMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.item.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? kTextPrimary : (_hovered ? kTextSecondary : kTextMuted),
                    letterSpacing: 0.1,
                  )),
              ),
              if (widget.notificationCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kDanger.withValues(alpha: 0.4)),
                  ),
                  child: Text('${widget.notificationCount}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kDanger)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}


