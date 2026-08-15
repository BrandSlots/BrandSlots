import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/admin_dashboard_page.dart';
import 'screens/admin_login_page.dart';
import 'screens/screen_login_page.dart';
import 'screens/screen_player_page.dart';
import 'services/repository_factory.dart';
import 'state/app_controller.dart';
import 'supabase_options.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Always initialize Supabase for TV functionality
  await Supabase.initialize(
    url: SupabaseOptions.url,
    anonKey: SupabaseOptions.anonKey,
  );
  
  final controller = AppController(RepositoryFactory.createSupabase());
  runApp(AdMasterApp(controller: controller));
}

enum RouteStep { admin, screen }

class AdMasterApp extends StatefulWidget {
  const AdMasterApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdMasterApp> createState() => _AdMasterAppState();
}

class _AdMasterAppState extends State<AdMasterApp> {
  RouteStep _routeStep = RouteStep.admin;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ad Master Flutter',
      theme: buildAppTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final controller = widget.controller;

    if (!controller.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (controller.errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'App failed to load',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      controller.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (controller.sessionMode == SessionMode.admin) {
      return AdminDashboardPage(controller: controller);
    }

    if (controller.sessionMode == SessionMode.screen) {
      return ScreenPlayerPage(controller: controller);
    }

    switch (_routeStep) {
      case RouteStep.admin:
        return AdminLoginPage(
          controller: controller,
          onBack: () {}, // No back button needed
        );
      case RouteStep.screen:
        return ScreenLoginPage(
          controller: controller,
          onBack: () => setState(() => _routeStep = RouteStep.admin),
        );
    }
  }
}
