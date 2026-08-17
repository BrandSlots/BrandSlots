import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_runtime.dart';
import 'screens/screen_player_page.dart';
import 'services/repository_factory.dart';
import 'state/app_controller.dart';
import 'supabase_options.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseOptions.url,
    anonKey: SupabaseOptions.anonKey,
  );

  final controller = AppController(RepositoryFactory.createSupabase());
  runApp(ScreenApplianceApp(controller: controller));
}

class ScreenApplianceApp extends StatefulWidget {
  const ScreenApplianceApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScreenApplianceApp> createState() => _ScreenApplianceAppState();
}

class _ScreenApplianceAppState extends State<ScreenApplianceApp> {
  String? _bootError;
  bool _isBooting = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await widget.controller.initialize();
    } catch (_) {
      setState(() {
        _bootError =
            'Screen startup failed before cached content could be loaded.';
        _isBooting = false;
      });
      return;
    }

    final code = AppRuntime.screenCode.trim();
    final password = AppRuntime.screenPassword;
    if (code.isEmpty || password.isEmpty) {
      setState(() {
        _bootError =
            'Missing SCREEN_CODE or SCREEN_PASSWORD in the build configuration.';
        _isBooting = false;
      });
      return;
    }

    final success = await widget.controller.loginScreen(code, password);
    if (!success) {
      setState(() {
        _bootError =
            'Automatic screen sign-in failed for "$code". Check the embedded credentials.';
        _isBooting = false;
      });
      return;
    }

    setState(() => _isBooting = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppRuntime.screenTitle,
      theme: buildAppTheme(),
      home: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          if (!widget.controller.isReady || _isBooting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          if (_bootError != null) {
            return _ScreenBootError(message: _bootError!);
          }

          return ScreenPlayerPage(controller: widget.controller);
        },
      ),
    );
  }
}

class _ScreenBootError extends StatelessWidget {
  const _ScreenBootError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.orangeAccent,
                  size: 72,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
