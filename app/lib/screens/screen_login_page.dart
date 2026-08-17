import 'package:flutter/material.dart';

import '../state/app_controller.dart';

class ScreenLoginPage extends StatefulWidget {
  const ScreenLoginPage({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final AppController controller;
  final VoidCallback onBack;

  @override
  State<ScreenLoginPage> createState() => _ScreenLoginPageState();
}

class _ScreenLoginPageState extends State<ScreenLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isBusy = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final success = await widget.controller.loginScreen(
      _codeController.text,
      _passwordController.text,
    );
    if (!success && mounted) {
      setState(() {
        _isBusy = false;
        _error = 'Screen login failed. Check the code and password.';
      });
      return;
    }
    if (mounted) {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Screen Login'),
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
                              'Sign a screen into the platform',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Screen code',
                              ),
                              validator: _required,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Screen password',
                              ),
                              obscureText: true,
                              validator: _required,
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
                                child: const Text('Login Screen'),
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
          ),
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
