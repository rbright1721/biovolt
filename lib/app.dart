import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bloc/sensors/sensors_bloc.dart';
import 'bloc/sensors/sensors_event.dart';
import 'bloc/session/session_bloc.dart';
import 'bloc/session/session_event.dart';
import 'config/theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/session_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trends_screen.dart';
import 'services/ble_service.dart';
import 'services/session_recorder.dart';
import 'services/session_storage.dart';

class BioVoltApp extends StatefulWidget {
  final SessionStorage sessionStorage;
  final BleService bleService;
  final SessionRecorder sessionRecorder;

  const BioVoltApp({
    super.key,
    required this.sessionStorage,
    required this.bleService,
    required this.sessionRecorder,
  });

  @override
  State<BioVoltApp> createState() => _BioVoltAppState();
}

class _BioVoltAppState extends State<BioVoltApp> {
  @override
  void dispose() {
    widget.bleService.dispose();
    widget.sessionRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = SensorsBloc(bleService: widget.bleService);
            bloc.add(SensorsStarted());
            return bloc;
          },
        ),
        BlocProvider(
          create: (ctx) {
            final bloc = SessionBloc(
              sensorsBloc: ctx.read<SensorsBloc>(),
              storage: widget.sessionStorage,
              sessionRecorder: widget.sessionRecorder,
            );
            bloc.add(SessionHistoryLoaded());
            return bloc;
          },
        ),
      ],
      child: MaterialApp(
        title: 'BioVolt',
        debugShowCheckedModeBanner: false,
        theme: BioVoltTheme.dark,
        home: _MainShell(bleService: widget.bleService),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  final BleService bleService;

  const _MainShell({required this.bleService});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(bleService: widget.bleService),
      const SessionHistoryScreen(),
      const TrendsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: BioVoltColors.surface,
        border: Border(
          top: BorderSide(color: BioVoltColors.cardBorder, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: BioVoltColors.teal,
        unselectedItemColor: BioVoltColors.textSecondary,
        selectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          letterSpacing: 1,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'DASHBOARD',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'SESSIONS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            label: 'TRENDS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }
}
