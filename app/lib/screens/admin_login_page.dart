import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_controller.dart';
import '../supabase_options.dart';

const _adminBuildVersion = 'ba189a7';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({
    super.key,
    required this.controller,
    required this.onBack,
    this.showBackButton = true,
  });

  final AppController controller;
  final VoidCallback onBack;
  final bool showBackButton;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isBusy = false;
  String? _debugAdminSummary;

  @override
  void initState() {
    super.initState();
    _loadDebugAdminSummary();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final success = await widget.controller.loginAdmin(
        _emailController.text,
        _passwordController.text,
      );
      if (!success) {
        setState(() {
          _error = 'Invalid email or password.';
          _isBusy = false;
        });
        return;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isBusy = false;
      });
      return;
    }

    if (widget.controller.errorMessage != null) {
      if (!mounted) return;
      setState(() {
        _error = widget.controller.errorMessage;
        _isBusy = false;
      });
      return;
    }

    if (mounted) {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _loadDebugAdminSummary() async {
    try {
      final row = await Supabase.instance.client
          .from('app_config')
          .select('id, admin_name, admin_email')
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        if (row == null) {
          _debugAdminSummary = 'Debug: no app_config row found.';
          return;
        }
        final adminName = (row['admin_name'] as String? ?? '').trim();
        final adminEmail = (row['admin_email'] as String? ?? '').trim();
        _debugAdminSummary =
            'Debug: app_config found. admin_name="$adminName", admin_email="$adminEmail"';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _debugAdminSummary = 'Debug: failed to read app_config: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: const Text('Admin Login'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 24,
                24,
                isCompact ? 16 : 24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(isCompact ? 20 : 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sign in to the admin portal',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 20),
                            SelectableText(
                              'Build: $_adminBuildVersion\nSupabase: ${SupabaseOptions.url}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (_debugAdminSummary != null) ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                _debugAdminSummary!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              decoration:
                                  const InputDecoration(labelText: 'Email'),
                              validator: _required,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration:
                                  const InputDecoration(labelText: 'Password'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'This field is required.';
                                }
                                return null;
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isBusy ? null : _submit,
                                child: const Text('Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }
}
