import 'package:flutter/material.dart';

const _buildVersion = 'f53406a';

class LandingPage extends StatelessWidget {
  const LandingPage({
    super.key,
    required this.hasAdmin,
    required this.backendLabel,
    required this.onAdminSelected,
    required this.onScreenSelected,
  });

  final bool hasAdmin;
  final String backendLabel;
  final VoidCallback onAdminSelected;
  final VoidCallback onScreenSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE7F5EF), Color(0xFFF9FCFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 760;
              final contentWidth =
                  constraints.maxWidth > 960 ? 960.0 : constraints.maxWidth;
              final cardWidth = isCompact
                  ? contentWidth
                  : (contentWidth - 24) / 2;

              return SingleChildScrollView(
                padding: EdgeInsets.all(isCompact ? 16 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Backend mode: $backendLabel',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Build: $_buildVersion',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _ModeCard(
                                title: 'Admin Login',
                                subtitle:
                                    'Manage company profile, screens, and media assignments.',
                                icon: Icons.admin_panel_settings_outlined,
                                actionLabel: 'Open Admin',
                                onPressed: onAdminSelected,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _ModeCard(
                                title: 'Screen Login',
                                subtitle:
                                    'Sign a display in with its own code and show assigned content.',
                                icon: Icons.tv_outlined,
                                actionLabel: 'Open Screen',
                                onPressed: onScreenSelected,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF0EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF0F766E)),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 24),
            FilledButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
