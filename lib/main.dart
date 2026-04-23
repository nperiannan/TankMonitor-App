import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';
import 'login_screen.dart';
import 'setup_screen.dart';
import 'dashboard_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TankService(),
      child: const TankMonitorApp(),
    ),
  );
}

class TankMonitorApp extends StatelessWidget {
  const TankMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tank Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF1890ff)),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF1890ff) : null),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF1890ff).withOpacity(0.4) : null),
        ),
      ),
      home: const _Startup(),
    );
  }
}

/// Loads the saved token and URLs on first frame.
/// If no token → LoginScreen.
/// If token present and URLs saved → DashboardScreen.
/// If token present but no URLs → SetupScreen.
class _Startup extends StatefulWidget {
  const _Startup();

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  bool _ready       = false;
  bool _loggedIn    = false;
  bool _hasSavedUrl = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final svc = context.read<TankService>();
    await svc.loadToken();
    if (svc.authToken == null) {
      setState(() { _loggedIn = false; _ready = true; });
      return;
    }
    await svc.loadSavedUrls();
    if (svc.wifiUrl.isNotEmpty || svc.mobileUrl.isNotEmpty) {
      await svc.connectAuto();
      setState(() { _loggedIn = true; _hasSavedUrl = true; _ready = true; });
    } else {
      setState(() { _loggedIn = true; _hasSavedUrl = false; _ready = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF141414),
        body: Center(
          child: Text('💧', style: TextStyle(fontSize: 48)),
        ),
      );
    }
    if (!_loggedIn) return const LoginScreen();
    return _hasSavedUrl ? const DashboardScreen() : const SetupScreen();
  }
}
