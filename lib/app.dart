import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bloc/sensors/sensors_bloc.dart';
import 'bloc/sensors/sensors_event.dart';
import 'bloc/session/session_bloc.dart';
import 'bloc/session/session_event.dart';
import 'bloc/session/session_state.dart';
import 'config/theme.dart';
import 'screens/analysis_screen.dart';
import 'main.dart' show appNavigatorKey;
import 'screens/dashboard_screen.dart';
import 'screens/data_hub_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/session_history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/trends_screen.dart';
import 'services/ble_service.dart';
import 'services/session_recorder.dart';
import 'services/session_storage.dart';
import 'services/storage_service.dart';
import 'services/trend_analyst.dart';
import 'services/widget_service.dart';

class BioVoltApp extends StatefulWidget {
  final SessionStorage sessionStorage;
  final BleService bleService;
  final SessionRecorder sessionRecorder;
  final TrendAnalyst trendAnalyst;
  final bool firstLaunch;

  const BioVoltApp({
    super.key,
    required this.sessionStorage,
    required this.bleService,
    required this.sessionRecorder,
    required this.trendAnalyst,
    this.firstLaunch = false,
  });

  @override
  State<BioVoltApp> createState() => _BioVoltAppState();
}

class _BioVoltAppState extends State<BioVoltApp>
    with WidgetsBindingObserver {
  bool _authChecked = false;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuth();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sync the home-screen widget immediately when the app comes
    // back to the foreground — catches any "I ate" taps or protocol
    // edits that happened in a different session.
    if (state == AppLifecycleState.resumed) {
      WidgetService.updateWidget();
    }
  }

  Future<void> _checkAuth() async {
    // Wait for Firebase to restore auth state
    await FirebaseAuth.instance.authStateChanges().first;
    if (mounted) {
      setState(() {
        _isSignedIn = FirebaseAuth.instance.currentUser != null;
        _authChecked = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        navigatorKey: appNavigatorKey,
        home: _buildHome(),
      ),
    );
  }

  Widget _buildHome() {
    if (!_authChecked) {
      return const Scaffold(
        backgroundColor: BioVoltColors.background,
        body: Center(
          child: CircularProgressIndicator(color: BioVoltColors.teal),
        ),
      );
    }

    if (!_isSignedIn) {
      return SignInScreen(
        onSignedIn: () => setState(() => _isSignedIn = true),
      );
    }

    if (widget.firstLaunch) {
      return _FirstLaunchWrapper(
        bleService: widget.bleService,
        trendAnalyst: widget.trendAnalyst,
      );
    }

    return _MainShell(
      bleService: widget.bleService,
      trendAnalyst: widget.trendAnalyst,
    );
  }
}

class _MainShell extends StatefulWidget {
  final BleService bleService;
  final TrendAnalyst trendAnalyst;

  const _MainShell({required this.bleService, required this.trendAnalyst});

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
      JournalScreen(bleService: widget.bleService),
      TrendsScreen(trendAnalyst: widget.trendAnalyst),
      const DataHubScreen(),
      const SettingsScreen(),
    ];

    return BlocListener<SessionBloc, SessionState>(
      listenWhen: (prev, curr) =>
          prev.status != SessionStatus.completed &&
          curr.status == SessionStatus.completed &&
          curr.analysis != null,
      listener: (context, state) {
        // Find the session from storage for the analysis
        final sessionId = state.analysis!.sessionId;
        final session = StorageService().getSession(sessionId);
        if (session != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<SessionBloc>(),
                child: AnalysisScreen(
                  session: session,
                  analysis: state.analysis,
                ),
              ),
            ),
          );
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
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
            label: 'LIVE',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'SESSIONS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'JOURNAL',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            label: 'TRENDS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_rounded),
            label: 'DATA',
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

/// Shows ProfileScreen first, then replaces with MainShell after profile is saved.
class _FirstLaunchWrapper extends StatefulWidget {
  final BleService bleService;
  final TrendAnalyst trendAnalyst;

  const _FirstLaunchWrapper({
    required this.bleService,
    required this.trendAnalyst,
  });

  @override
  State<_FirstLaunchWrapper> createState() => _FirstLaunchWrapperState();
}

class _FirstLaunchWrapperState extends State<_FirstLaunchWrapper> {
  bool _profileDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => const ProfileScreen(isFirstLaunch: true),
          ))
          .then((_) {
        if (mounted) setState(() => _profileDone = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_profileDone) {
      return _MainShell(
        bleService: widget.bleService,
        trendAnalyst: widget.trendAnalyst,
      );
    }
    return const Scaffold(backgroundColor: BioVoltColors.background);
  }
}
