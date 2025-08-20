import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/telegram_proxy_provider.dart';
import 'providers/v2ray_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/privacy_welcome_screen.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if user has accepted privacy policy
  final prefs = await SharedPreferences.getInstance();
  final bool privacyAccepted = prefs.getBool('privacy_accepted') ?? false;

  runApp(MyApp(privacyAccepted: privacyAccepted));
}

class MyApp extends StatefulWidget {
  final bool privacyAccepted;

  const MyApp({super.key, required this.privacyAccepted});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    // Check for updates after the app is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final update = await _updateService.checkForUpdates();
    if (update != null && mounted) {
      _updateService.showUpdateDialog(context, update);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => V2RayProvider()),
        ChangeNotifierProvider(create: (context) => TelegramProxyProvider()),
      ],
      child: MaterialApp(
        title: 'Proxy Cloud',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme(),
        home:
            widget.privacyAccepted
                ? const MainNavigationScreen()
                : const PrivacyWelcomeScreen(),
      ),
    );
  }
}
