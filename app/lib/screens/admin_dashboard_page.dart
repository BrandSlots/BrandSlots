// ignore_for_file: unused_import, unused_field, unused_element, unused_local_variable, unused_element_parameter

import 'dart:async';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/video_thumbnail_stub.dart'
    if (dart.library.js_util) '../services/video_thumbnail_web.dart';
import '../services/pdf_download_stub.dart'
    if (dart.library.js_interop) '../services/pdf_download_web.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/app_models.dart';
import '../services/report_pdf_service.dart';
import '../state/app_controller.dart';

enum _AdminSection { dashboard, screens, clients, player, reports }

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

enum _TimePeriod { daily, weekly, monthly, yearly, custom }

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  _AdminSection _section = _AdminSection.dashboard;
  String? _selectedClientId;
  String? _selectedScreenId;
  DateTime _customStartDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _customEndDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String? _reportFilterClientId;
  String _reportClientSearch = '';
  String? _expandedReportCardId;
  String _screenSearch = '';
  String _playerSearch = '';
  String _playerClientSearch = '';
  String _clientSearch = '';
  String? _selectedPlayerClientId;
  final Map<String, Uint8List> _videoThumbnails = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant AdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncSelections(controller);
    final isCompact = MediaQuery.of(context).size.width < 1080;
    final meta = _metaFor(_section);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: isCompact
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Text(meta.title),
              actions: [
                IconButton(
                  onPressed: () =>
                      _showOrganizationDialog(controller.organization),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                ),
                IconButton(
                  onPressed: controller.logout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            )
          : null,
      drawer: isCompact
          ? Drawer(
              child: SafeArea(
                child: _DashboardNav(
                  controller: controller,
                  selected: _section,
                  onSelected: (section) {
                    setState(() => _section = section);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isCompact)
            SizedBox(
              width: 224,
              height: double.infinity,
              child: _DashboardNav(
                controller: controller,
                selected: _section,
                onSelected: (section) => setState(() => _section = section),
              ),
            ),
          Expanded(
            child: SafeArea(
              left: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 16 : 28, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCompact)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: _PageHeader(
                          title: meta.title,
                          subtitle: meta.subtitle,
                          actions: [
                            OutlinedButton.icon(
                              onPressed: () => _showOrganizationDialog(
                                  controller.organization),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Admin Profile'),
                            ),
                            FilledButton.icon(
                              onPressed: controller.logout,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Logout'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: KeyedSubtree(
                          key: ValueKey(_section),
                          child: _buildSection(controller),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: _AdminSection.values.indexOf(_section),
              onDestinationSelected: (index) {
                setState(() => _section = _AdminSection.values[index]);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tv_outlined),
                  label: 'Screens',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  label: 'Clients',
                ),
                NavigationDestination(
                  icon: Icon(Icons.playlist_play_rounded),
                  label: 'Player',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'Reports',
                ),
              ],
            )
          : null,
    );
  }

  void _syncSelections(AppController controller) {
    if (controller.clients.isEmpty) {
      _selectedClientId = null;
    } else if (_selectedClientId == null ||
        controller.getClientById(_selectedClientId!) == null) {
      _selectedClientId = controller.clients.first.id;
    }

    if (controller.screens.isEmpty) {
      _selectedScreenId = null;
    } else if (_selectedScreenId == null ||
        controller.getScreenById(_selectedScreenId!) == null) {
      _selectedScreenId = controller.screens.first.id;
    }
  }

  _SectionMeta _metaFor(_AdminSection section) {
    switch (section) {
      case _AdminSection.dashboard:
        return const _SectionMeta(
          'Dashboard',
          'Monitor clients, active screens, and media playback health.',
        );
      case _AdminSection.screens:
        return const _SectionMeta(
          'Screens',
          'Register screen players and track each device playlist status.',
        );
      case _AdminSection.clients:
        return const _SectionMeta(
          'Clients',
          'Create clients and upload the videos and photos that belong to them.',
        );
      case _AdminSection.player:
        return const _SectionMeta(
          'Screen Player',
          'Assign client media to each screen, reorder playlists, and remove items.',
        );
      case _AdminSection.reports:
        return const _SectionMeta(
          'Reports',
          'Total plays and media breakdown per client and per screen.',
        );
    }
  }

  Widget _buildSection(AppController controller) {
    switch (_section) {
      case _AdminSection.dashboard:
        return _buildDashboard(controller);
      case _AdminSection.screens:
        return _buildScreens(controller);
      case _AdminSection.clients:
        return _buildClients(controller);
      case _AdminSection.player:
        return _buildPlayer(controller);
      case _AdminSection.reports:
        return _buildReports(controller);
    }
  }

  Widget _buildDashboard(AppController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final statCardWidth = w < 520
            ? w
            : w < 980
                ? (w - 16) / 2
                : (w - 48) / 4;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: statCardWidth,
                    child: _buildStatCard(
                      'Total Screens',
                      '${controller.screens.length}',
                      'Registered screen players',
                      const Color(0xFF111827),
                      Icons.tv_rounded,
                    ),
                  ),
                  SizedBox(
                    width: statCardWidth,
                    child: _buildStatCard(
                      'Online Screens',
                      '${controller.screens.where((s) => _isNowPlaying(s)).length}',
                      'Currently playing media',
                      const Color(0xFF22C55E),
                      Icons.circle,
                    ),
                  ),
                  SizedBox(
                    width: statCardWidth,
                    child: _buildStatCard(
                      'Total Clients',
                      '${controller.clients.length}',
                      'Accounts with their own media library',
                      const Color(0xFF6B7280),
                      Icons.groups_rounded,
                    ),
                  ),
                  SizedBox(
                    width: statCardWidth,
                    child: _buildStatCard(
                      'Uploaded Media',
                      '${controller.mediaItems.length}',
                      'Videos and photos stored',
                      const Color(0xFF6B7280),
                      Icons.cloud_upload_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Two panels side by side or stacked
              _buildScreensOverviewPanel(controller),
              const SizedBox(height: 20),
              _buildMediaOverviewPanel(controller),
              const SizedBox(height: 20),
              _buildClientsOverviewPanel(controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, String detail, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 240;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              if (compact)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: accent, size: 20),
                  ],
                )
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                detail,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMediaOverviewPanel(AppController controller) {
    final summaries = _allMediaSummaries(controller);
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(
            title: 'Media Breakdown',
            subtitle:
                'Every uploaded asset with the same play totals used across the app.',
          ),
          const SizedBox(height: 20),
          if (summaries.isEmpty)
            const Text(
              'No media uploaded yet. Add an asset in the Clients section to see performance here.',
              style: TextStyle(color: Color(0xFF5A6B80)),
            )
          else
            _MediaBreakdownList(
              summaries: summaries,
              controller: controller,
            ),
        ],
      ),
    );
  }

  Widget _buildClientsOverviewPanel(AppController controller) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(
              title: 'Clients Overview',
              subtitle: 'Every client owns its own upload library.'),
          const SizedBox(height: 20),
          if (controller.clients.isEmpty)
            const Text(
                'No clients yet. Add your first client in the Clients section.',
                style: TextStyle(color: Color(0xFF5A6B80)))
          else
            for (int idx = 0; idx < controller.clients.length; idx++) ...[
              _MetricListTile(
                title: controller.clients[idx].name,
                subtitle:
                    '${controller.mediaForClient(controller.clients[idx].id).length} uploaded assets',
                trailing:
                    '${_sumClientPlays(controller, controller.clients[idx].id)} plays',
              ),
              if (idx < controller.clients.length - 1)
                const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _buildScreensOverviewPanel(AppController controller) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeading(
              title: 'Screens Overview',
              subtitle: 'Each screen has its own ordered playlist.'),
          const SizedBox(height: 20),
          if (controller.screens.isEmpty)
            const Text('No screens registered yet.',
                style: TextStyle(color: Color(0xFF5A6B80)))
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final screen in controller.screens)
                  SizedBox(
                    width: 280,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isNowPlaying(screen))
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  screen.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${screen.assignedMediaIds.length} items',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${controller.playsForScreen(screen.id)} plays',
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScreens(AppController controller) {
    final filtered = controller.screens
        .where((s) =>
            s.name.toLowerCase().contains(_screenSearch.toLowerCase()) ||
            s.location.toLowerCase().contains(_screenSearch.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackHeader = constraints.maxWidth < 700;
        final narrowCards = constraints.maxWidth < 520;
        final crossAxisCount =
            narrowCards ? 1 : (constraints.maxWidth / 380).floor().clamp(1, 4);
        final mainAxisExtent = narrowCards ? 460.0 : 380.0;

        final searchField = TextField(
          onChanged: (v) => setState(() => _screenSearch = v),
          decoration: InputDecoration(
            hintText: 'Search screens...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        );

        final addButton = FilledButton.icon(
          onPressed: _showAddScreenDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Screen'),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stackHeader)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  addButton,
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  addButton,
                ],
              ),
            const SizedBox(height: 16),
            if (controller.screens.isEmpty)
              const _EmptyStateCard(
                title: 'No screens registered',
                subtitle:
                    'Add a screen to create a unique screen player account.',
              )
            else if (filtered.isEmpty)
              const _EmptyStateCard(
                title: 'No screens found',
                subtitle: 'Try a different search term.',
              )
            else
              Expanded(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final screen = filtered[index];
                    final nowPlaying = _isNowPlaying(screen);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: nowPlaying
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE5E7EB),
                          width: nowPlaying ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: nowPlaying
                                ? const Color(0x1A10B981)
                                : const Color(0x0A000000),
                            blurRadius: nowPlaying ? 16 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: nowPlaying
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.tv_rounded,
                                  size: 20,
                                  color: nowPlaying
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  screen.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (nowPlaying)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Text(
                                        'Now Playing',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _KeyValueRow(label: 'Code', value: screen.loginCode),
                          _KeyValueRow(
                            label: 'Location',
                            value: screen.location.isEmpty
                                ? 'Not set'
                                : screen.location,
                          ),
                          _KeyValueRow(
                            label: 'Playlist',
                            value: '${screen.assignedMediaIds.length} items',
                          ),
                          _KeyValueRow(
                            label: 'Last playback',
                            value: _formatTimestamp(screen.lastPlaybackAt),
                          ),
                          const SizedBox(height: 8),
                          _TodayKpiRow(screen: screen, controller: controller),
                          const Spacer(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showEditScreenDialog(screen),
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                label: const Text('Edit'),
                              ),
                              if (controller.apkDownloadUrlForScreen(screen) !=
                                  null)
                                FilledButton.tonalIcon(
                                  onPressed: () => _openUrl(
                                    controller.apkDownloadUrlForScreen(screen)!,
                                  ),
                                  icon: const Icon(Icons.download_rounded,
                                      size: 14),
                                  label: const Text('APK'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildClients(AppController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PanelHeading(
                      title: 'Clients',
                      subtitle:
                          'Click a client to view and manage their media.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _showAddClientDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Client'),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: _PanelHeading(
                        title: 'Clients',
                        subtitle:
                            'Click a client to view and manage their media.',
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _showAddClientDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Client'),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              if (controller.clients.isEmpty)
                const _EmptyStateCard(
                  title: 'No clients yet',
                  subtitle:
                      'Add a client to start uploading videos and photos.',
                )
              else ...[
                TextField(
                  onChanged: (v) => setState(() => _clientSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search clients...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                for (final client in controller.clients
                    .where((c) => c.name
                        .toLowerCase()
                        .contains(_clientSearch.toLowerCase()))
                    .toList()) ...[
                  _ClientExpandableCard(
                    client: client,
                    controller: controller,
                    isExpanded: client.id == _selectedClientId,
                    onTap: () => setState(() => _selectedClientId =
                        _selectedClientId == client.id ? null : client.id),
                    onEdit: () => _showEditClientDialog(client),
                    onDelete: () => _confirmDeleteClient(client),
                    onUpload: () => _showAddMediaDialog(client),
                    onDeleteMedia: _confirmDeleteMedia,
                    onAssignToScreens: (item) =>
                        _showAssignToScreensDialog(item),
                    onThumbnailCaptured: (id, bytes) =>
                        _videoThumbnails[id] = bytes,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientMediaList(
    AppController controller,
    ClientProfile client,
  ) {
    final mediaItems = controller.mediaForClient(client.id);
    if (mediaItems.isEmpty) {
      return const _EmptyStateCard(
        title: 'No media uploaded for this client',
        subtitle:
            'Upload photos or videos here. These assets can then be added to screen playlists.',
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        for (final item in mediaItems)
          SizedBox(
            width: 380,
            child: _SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media preview
                  if (item.url.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.kind == MediaKind.image
                          ? Image.network(
                              item.url,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _MediaPlaceholder(kind: item.kind),
                            )
                          : _VideoPreviewTile(
                              url: item.url,
                              mediaId: item.id,
                              controller: controller,
                              onThumbnailCaptured: (id, bytes) =>
                                  _videoThumbnails[id] = bytes),
                    )
                  else
                    _MediaPlaceholder(kind: item.kind),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (item.kind == MediaKind.image)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.durationSeconds}s',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () => _confirmDeleteMedia(item),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: const TextStyle(color: Color(0xFF5A6B80)),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayer(AppController controller) {
    final filteredScreens = controller.screens
        .where(
            (s) => s.name.toLowerCase().contains(_playerSearch.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selectedScreen = _selectedScreenId == null
        ? null
        : controller.getScreenById(_selectedScreenId!);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackLayout = constraints.maxWidth < 900;
        final leftPanel = Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _playerSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search screens...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    if (controller.screens.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: _EmptyStateCard(
                          title: 'No screens',
                          subtitle: 'Add a screen first.',
                          compact: true,
                        ),
                      )
                    else
                      for (final screen in filteredScreens)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _SelectableTile(
                            title: screen.name,
                            subtitle: '${screen.assignedMediaIds.length} items',
                            selected: screen.id == _selectedScreenId,
                            onTap: () =>
                                setState(() => _selectedScreenId = screen.id),
                          ),
                        ),
                    if (controller.clients.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
                        child: Text(
                          'CLIENTS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: TextField(
                          onChanged: (v) =>
                              setState(() => _playerClientSearch = v),
                          decoration: InputDecoration(
                            hintText: 'Search clients...',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 16),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                          ),
                        ),
                      ),
                      for (final client in controller.clients
                          .where((c) => c.name
                              .toLowerCase()
                              .contains(_playerClientSearch.toLowerCase()))
                          .toList()) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _SelectableTile(
                            title: client.name,
                            subtitle:
                                '${controller.mediaForClient(client.id).length} media',
                            selected: client.id == _selectedPlayerClientId,
                            onTap: () => setState(() {
                              _selectedPlayerClientId =
                                  _selectedPlayerClientId == client.id
                                      ? null
                                      : client.id;
                            }),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
        final leftPanelWidget = stackLayout
            ? SizedBox(height: 420, child: leftPanel)
            : SizedBox(width: 260, child: leftPanel);

        final rightPanel = selectedScreen == null
            ? const _EmptyStateCard(
                title: 'Select a screen',
                subtitle:
                    'Choose a screen to assign client media and reorder its playlist.',
              )
            : LayoutBuilder(
                builder: (context, innerConstraints) {
                  final stack = innerConstraints.maxWidth < 700;
                  final left =
                      _buildAvailableMediaPanel(controller, selectedScreen);
                  final right = _buildPlaylistPanel(controller, selectedScreen);
                  if (stack) {
                    return Column(
                      children: [
                        left,
                        const SizedBox(height: 16),
                        right,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 16),
                      Expanded(child: right),
                    ],
                  );
                },
              );

        if (stackLayout) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftPanelWidget,
                const SizedBox(height: 16),
                rightPanel,
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leftPanelWidget,
            const SizedBox(width: 16),
            Expanded(child: rightPanel),
          ],
        );
      },
    );
  }

  Widget _buildAvailableMediaPanel(
    AppController controller,
    ScreenDevice screen,
  ) {
    final selectedClient = _selectedPlayerClientId == null
        ? null
        : controller.getClientById(_selectedPlayerClientId!);
    final mediaItems = selectedClient == null
        ? controller.mediaItems
        : controller.mediaForClient(selectedClient.id);

    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            title: selectedClient == null
                ? 'Available Client Media'
                : '${selectedClient.name} Media',
            subtitle: 'Add uploaded client media to ${screen.name}.',
          ),
          const SizedBox(height: 16),
          if (mediaItems.isEmpty)
            const _EmptyStateCard(
              title: 'No client media available',
              subtitle: 'Upload media in the Clients section first.',
              compact: true,
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final item in mediaItems) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.url.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item.kind == MediaKind.image
                                      ? Image.network(
                                          item.url,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _MediaPlaceholder(
                                                  kind: item.kind),
                                        )
                                      : SizedBox(
                                          height: 120,
                                          child: _VideoPreviewTile(
                                              url: item.url,
                                              mediaId: item.id,
                                              controller: controller,
                                              onThumbnailCaptured: (id, bytes) =>
                                                  _videoThumbnails[id] = bytes),
                                        ),
                                )
                              else
                                SizedBox(
                                  height: 120,
                                  child: _MediaPlaceholder(kind: item.kind),
                                ),
                              const SizedBox(height: 8),
                              _MetricListTile(
                                title: item.title,
                                subtitle: _clientName(controller, item.clientId),
                                trailingWidget: FilledButton.tonal(
                                  onPressed: screen.assignedMediaIds
                                          .contains(item.id)
                                      ? null
                                      : () => _addMediaToScreen(screen, item.id),
                                  child: Text(
                                    screen.assignedMediaIds.contains(item.id)
                                        ? 'Added'
                                        : 'Add',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaylistPanel(
    AppController controller,
    ScreenDevice screen,
  ) {
    final playlist = controller.mediaForScreen(screen.id);
    final isPortrait =
        screen.screenPlayerOrientation.toLowerCase() == 'portrait';
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeading(
            title: '${screen.name} Playlist',
            subtitle: 'Reorder, remove, and review what this screen will play.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Screen orientation',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10233D),
                ),
              ),
              FilledButton.tonal(
                onPressed: () => _setScreenOrientation(screen, 'portrait'),
                style: FilledButton.styleFrom(
                  backgroundColor: isPortrait
                      ? const Color(0xFF10233D)
                      : const Color(0xFFE3F1F1),
                  foregroundColor:
                      isPortrait ? Colors.white : const Color(0xFF10233D),
                ),
                child: const Text('Portrait'),
              ),
              FilledButton.tonal(
                onPressed: () => _setScreenOrientation(screen, 'landscape'),
                style: FilledButton.styleFrom(
                  backgroundColor: isPortrait
                      ? const Color(0xFFE3F1F1)
                      : const Color(0xFF10233D),
                  foregroundColor:
                      isPortrait ? const Color(0xFF10233D) : Colors.white,
                ),
                child: const Text('Landscape'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (playlist.isEmpty)
            const _EmptyStateCard(
              title: 'Playlist is empty',
              subtitle: 'Add client media from the left panel.',
              compact: true,
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: playlist.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorderPlaylist(screen, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final item = playlist[index];
                  return Container(
                    key: ValueKey(item.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FBFD),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDCE3ED)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F1F1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item.kind == MediaKind.video
                                ? Icons.videocam_outlined
                                : Icons.image_outlined,
                            color: const Color(0xFF005F73),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10233D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _clientName(controller, item.clientId),
                                style: const TextStyle(
                                  color: Color(0xFF5A6B80),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final confirmed = await _confirm(
                              title: 'Remove from playlist?',
                              message:
                                  'Remove "${item.title}" from ${screen.name}?',
                            );
                            if (confirmed == true)
                              _removeMediaFromScreen(screen, item.id);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const Icon(Icons.drag_handle_rounded),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  ({DateTime from, DateTime to}) get _reportDateRange => (
        from: _customStartDate,
        to: _customEndDate,
      );

  // Monthly: list all months that have data (or all months of selected year)
  // Yearly: list all years that have data
  // Weekly: week selector (pick any day → snap to Monday)
  // Daily: date picker
  // Custom: start + end

  List<int> get _availableYears {
    final years = <int>{};
    for (final s in widget.controller.playbackStats) {
      final d = s.playDate != null ? DateTime.tryParse(s.playDate!) : null;
      if (d != null) years.add(d.year);
    }
    final now = DateTime.now().year;
    years.add(now);
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<int> get _availableMonthsForYear {
    final months = <int>{};
    final selectedYear = DateTime.now().year;
    for (final s in widget.controller.playbackStats) {
      final d = s.playDate != null ? DateTime.tryParse(s.playDate!) : null;
      if (d != null && d.year == selectedYear) months.add(d.month);
    }
    final now = DateTime.now();
    if (selectedYear == now.year) months.add(now.month);
    if (months.isEmpty) months.add(DateTime.now().month);
    final list = months.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  Widget _buildReports(AppController controller) {
    return _buildReportsContent(controller);
  }

  Widget _buildReportsContent(AppController controller) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 780;
              final dateRange = Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _customStartDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('From: ${_formatDate(_customStartDate)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customEndDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _customEndDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('To: ${_formatDate(_customEndDate)}'),
                    ),
                  ),
                ],
              );
              final toggles = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: stack ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  _ViewToggleButton(
                    label: 'Screens',
                    icon: Icons.tv_rounded,
                    selected: _reportFilterClientId == null,
                    onTap: () => setState(() {
                      _reportFilterClientId = null;
                    }),
                  ),
                  _ViewToggleButton(
                    label: 'Clients',
                    icon: Icons.groups_rounded,
                    selected: _reportFilterClientId != null,
                    onTap: () => setState(() {
                      _reportFilterClientId = controller.clients.isNotEmpty
                          ? controller.clients.first.id
                          : null;
                      _reportClientSearch = '';
                    }),
                  ),
                  if (_reportFilterClientId != null)
                    FilledButton.icon(
                      onPressed: controller.clients.isEmpty
                          ? null
                          : () async {
                              final client = controller.clients.firstWhere(
                                (c) => c.id == _reportFilterClientId,
                                orElse: () => controller.clients.first,
                              );
                              await _AdminDashboardPageState
                                  ._downloadClientReportDirect(
                                context,
                                controller,
                                client,
                                _videoThumbnails,
                                _customStartDate,
                                _customEndDate,
                              );
                            },
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Download PDF'),
                    ),
                ],
              );

              return _SurfacePanel(
                child: stack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          dateRange,
                          const SizedBox(height: 16),
                          toggles,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: dateRange),
                          const SizedBox(width: 16),
                          toggles,
                        ],
                      ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Reports Content
          _SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PanelHeading(
                        title: _reportFilterClientId == null
                            ? 'Screens Report'
                            : 'Clients Report',
                        subtitle: _reportFilterClientId == null
                            ? 'Active screens, total plays, and video breakdown.'
                            : 'Total plays and usage per client.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_reportFilterClientId == null) ...[
                  // Screens Report
                  if (controller.screens.isEmpty)
                    const _EmptyStateCard(
                      title: 'No screens registered',
                      subtitle:
                          'Add and configure screens to see playback analytics.',
                    )
                  else
                    Column(
                      children: [
                        for (int idx = 0;
                            idx < controller.screens.length;
                            idx++) ...[
                          _ScreenReportCard(
                            screen: controller.screens[idx],
                            controller: controller,
                            from: _reportDateRange.from,
                            to: _reportDateRange.to,
                            isExpanded: _expandedReportCardId ==
                                controller.screens[idx].id,
                            onToggle: () {
                              setState(() {
                                final screenId = controller.screens[idx].id;
                                if (_expandedReportCardId == screenId) {
                                  _expandedReportCardId = null;
                                } else {
                                  _expandedReportCardId = screenId;
                                }
                              });
                            },
                          ),
                          if (idx < controller.screens.length - 1)
                            const SizedBox(height: 16),
                        ],
                      ],
                    ),
                ] else ...[
                  // Clients Report
                  if (controller.clients.isEmpty)
                    const _EmptyStateCard(
                      title: 'No clients yet',
                      subtitle:
                          'Create clients and upload media to see usage analytics.',
                      compact: true,
                    )
                  else
                    Builder(
                      builder: (context) {
                        final search = _reportClientSearch.trim().toLowerCase();
                        final filteredClients = controller.clients
                            .where(
                              (client) =>
                                  search.isEmpty ||
                                  client.name.toLowerCase().contains(search),
                            )
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _reportClientSearch = value),
                              decoration: InputDecoration(
                                hintText: 'Search clients in reports...',
                                prefixIcon:
                                    const Icon(Icons.search_rounded, size: 20),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (filteredClients.isEmpty)
                              const _EmptyStateCard(
                                title: 'No matching clients',
                                subtitle:
                                    'Try a different search term to find a client report.',
                                compact: true,
                              )
                            else
                              Column(
                                children: [
                                  for (int index = 0;
                                      index < filteredClients.length;
                                      index++) ...[
                                    _ClientReportCard(
                                      client: filteredClients[index],
                                      controller: controller,
                                      videoThumbnails: _videoThumbnails,
                                      from: _reportDateRange.from,
                                      to: _reportDateRange.to,
                                      isExpanded: _expandedReportCardId ==
                                          filteredClients[index].id,
                                      onToggle: () {
                                        setState(() {
                                          final clientId =
                                              filteredClients[index].id;
                                          if (_expandedReportCardId ==
                                              clientId) {
                                            _expandedReportCardId = null;
                                          } else {
                                            _expandedReportCardId = clientId;
                                          }
                                        });
                                      },
                                    ),
                                    if (index < filteredClients.length - 1)
                                      const SizedBox(height: 16),
                                  ],
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOrganizationDialog(OrganizationProfile profile) async {
    final companyController = TextEditingController(text: profile.companyName);
    final adminController = TextEditingController(text: profile.adminName);
    final emailController = TextEditingController(text: profile.adminEmail);
    final phoneController = TextEditingController(text: profile.phone);
    final welcomeController =
        TextEditingController(text: profile.welcomeMessage);
    final apkBaseController = TextEditingController(text: profile.apkBaseUrl);
    final localPathController =
        TextEditingController(text: profile.localProjectPath);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Admin Profile'),
              content: SizedBox(
                width: _dialogContentWidth(context, 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DialogField(
                          label: 'Company name', controller: companyController),
                      _DialogField(
                          label: 'Admin name', controller: adminController),
                      _DialogField(
                          label: 'Admin email', controller: emailController),
                      _DialogField(label: 'Phone', controller: phoneController),
                      _DialogField(
                        label: 'Welcome message',
                        controller: welcomeController,
                        maxLines: 3,
                      ),
                      _DialogField(
                          label: 'APK base URL', controller: apkBaseController),
                      _DialogField(
                        label: 'Local project path',
                        controller: localPathController,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    if (companyController.text.trim().isEmpty ||
        adminController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty) {
      _showMessage('Company, admin name, and admin email are required.');
      return;
    }

    await widget.controller.updateOrganization(
      profile.copyWith(
        companyName: companyController.text.trim(),
        adminName: adminController.text.trim(),
        adminEmail: emailController.text.trim(),
        phone: phoneController.text.trim(),
        welcomeMessage: welcomeController.text.trim(),
        apkBaseUrl: apkBaseController.text.trim(),
        localProjectPath: localPathController.text.trim(),
      ),
    );
    _showMessage('Admin profile updated.');
  }

  Future<void> _confirmAndResetContent() async {
    final confirmed = await _confirm(
      title: 'Reset content data?',
      message:
          'This will clear all clients, media, media playback counts, and round history while keeping the existing screen accounts.',
    );
    if (confirmed != true) return;

    await widget.controller.resetContentData();
    setState(() {
      _selectedClientId = widget.controller.clients.isNotEmpty
          ? widget.controller.clients.first.id
          : null;
      _selectedScreenId = widget.controller.screens.isNotEmpty
          ? widget.controller.screens.first.id
          : null;
      _selectedPlayerClientId = null;
      _reportFilterClientId = null;
      _reportClientSearch = '';
      _expandedReportCardId = null;
    });
    _showMessage('Clients, media, and plays cleared.');
  }

  Future<void> _showAddScreenDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final locationController = TextEditingController();
    var selectedOrientation = 'landscape';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Screen'),
          content: SizedBox(
            width: _dialogContentWidth(context, 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(label: 'Screen name', controller: nameController),
                _DialogField(label: 'Login code', controller: codeController),
                _DialogField(label: 'Password', controller: passwordController),
                _DialogField(label: 'Location', controller: locationController),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedOrientation,
                    decoration: const InputDecoration(
                      labelText: 'Screen orientation',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'landscape',
                        child: Text('Landscape'),
                      ),
                      DropdownMenuItem(
                        value: 'portrait',
                        child: Text('Portrait'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedOrientation = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      _showMessage('Screen name, login code, and password are required.');
      return;
    }

    final error = await widget.controller.addScreen(
      name: nameController.text.trim(),
      loginCode: codeController.text.trim(),
      password: passwordController.text,
      location: locationController.text.trim(),
      screenPlayerOrientation: selectedOrientation,
    );

    if (!mounted) return;
    if (error != null) {
      _showMessage(error);
      return;
    }
    _showMessage('Screen added.');
  }

  Future<void> _showEditScreenDialog(ScreenDevice screen) async {
    final nameController = TextEditingController(text: screen.name);
    final codeController = TextEditingController(text: screen.loginCode);
    final passwordController = TextEditingController(text: screen.password);
    final locationController = TextEditingController(text: screen.location);
    var selectedOrientation = screen.screenPlayerOrientation.isEmpty
        ? 'landscape'
        : screen.screenPlayerOrientation;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Screen'),
          content: SizedBox(
            width: _dialogContentWidth(context, 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(label: 'Screen name', controller: nameController),
                _DialogField(label: 'Login code', controller: codeController),
                _DialogField(label: 'Password', controller: passwordController),
                _DialogField(label: 'Location', controller: locationController),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedOrientation,
                    decoration: const InputDecoration(
                      labelText: 'Screen orientation',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'landscape',
                        child: Text('Landscape'),
                      ),
                      DropdownMenuItem(
                        value: 'portrait',
                        child: Text('Portrait'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedOrientation = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    if (nameController.text.trim().isEmpty ||
        codeController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      _showMessage('Screen name, login code, and password are required.');
      return;
    }

    await widget.controller.updateScreen(
      screen.copyWith(
        name: nameController.text.trim(),
        loginCode: codeController.text.trim(),
        password: passwordController.text,
        location: locationController.text.trim(),
        screenPlayerOrientation: selectedOrientation,
      ),
    );
    _showMessage('Screen updated.');
  }

  Future<void> _showAddClientDialog() async {
    final created = await _showClientForm();
    if (created == null) return;
    if (created.name.isEmpty) {
      _showMessage('Client name is required.');
      return;
    }
    await widget.controller.addClient(
      name: created.name,
      contactName: created.contactName,
      contactEmail: created.contactEmail,
      phone: created.phone,
      notes: created.notes,
    );
    _showMessage('Client added.');
  }

  Future<void> _showEditClientDialog(ClientProfile client) async {
    final updated = await _showClientForm(client: client);
    if (updated == null) return;
    if (updated.name.isEmpty) {
      _showMessage('Client name is required.');
      return;
    }
    await widget.controller.updateClient(client.copyWith(
      name: updated.name,
      contactName: updated.contactName,
      contactEmail: updated.contactEmail,
      phone: updated.phone,
      notes: updated.notes,
    ));
    _showMessage('Client updated.');
  }

  Future<_ClientDraft?> _showClientForm({ClientProfile? client}) async {
    final nameController = TextEditingController(text: client?.name ?? '');
    final contactController =
        TextEditingController(text: client?.contactName ?? '');
    final emailController =
        TextEditingController(text: client?.contactEmail ?? '');
    final phoneController = TextEditingController(text: client?.phone ?? '');
    final notesController = TextEditingController(text: client?.notes ?? '');

    return showDialog<_ClientDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client == null ? 'Add Client' : 'Edit Client'),
        content: SizedBox(
          width: _dialogContentWidth(context, 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(label: 'Client name', controller: nameController),
                _DialogField(
                    label: 'Contact name', controller: contactController),
                _DialogField(
                    label: 'Contact email', controller: emailController),
                _DialogField(label: 'Phone', controller: phoneController),
                _DialogField(
                  label: 'Notes',
                  controller: notesController,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (client != null)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _confirmDeleteClient(client);
              },
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                _ClientDraft(
                  name: nameController.text.trim(),
                  contactName: contactController.text.trim(),
                  contactEmail: emailController.text.trim(),
                  phone: phoneController.text.trim(),
                  notes: notesController.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMediaDialog(ClientProfile client) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final durationController = TextEditingController(text: '15');
    final urlController = TextEditingController();
    var selectedKind = MediaKind.video;
    PlatformFile? pickedFile;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Upload Media for ${client.name}'),
          content: SizedBox(
            width: _dialogContentWidth(context, 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<MediaKind>(
                    segments: const [
                      ButtonSegment(
                        value: MediaKind.video,
                        label: Text('Video'),
                        icon: Icon(Icons.videocam_outlined),
                      ),
                      ButtonSegment(
                        value: MediaKind.image,
                        label: Text('Photo'),
                        icon: Icon(Icons.image_outlined),
                      ),
                    ],
                    selected: {selectedKind},
                    onSelectionChanged: (value) {
                      setDialogState(() => selectedKind = value.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  _DialogField(label: 'Title', controller: titleController),
                  _DialogField(
                    label: 'Description',
                    controller: descriptionController,
                    maxLines: 3,
                  ),
                  if (selectedKind == MediaKind.image)
                    _DialogField(
                      label: 'Display duration in seconds',
                      controller: durationController,
                    ),
                  _DialogField(
                    label: 'External URL (optional)',
                    controller: urlController,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: selectedKind == MediaKind.video
                              ? ['mp4', 'mov', 'm4v', 'webm']
                              : ['jpg', 'jpeg', 'png', 'webp'],
                          withData: true,
                        );
                        if (result == null || result.files.isEmpty) return;
                        setDialogState(() => pickedFile = result.files.first);
                      },
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        pickedFile == null ? 'Pick File' : pickedFile!.name,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;

    if (titleController.text.trim().isEmpty) {
      _showMessage('Media title is required.');
      return;
    }
    if ((pickedFile?.bytes == null || pickedFile!.bytes!.isEmpty) &&
        urlController.text.trim().isEmpty) {
      _showMessage('Choose a file or provide an external URL.');
      return;
    }

    try {
      await widget.controller.addMedia(
        clientId: client.id,
        title: titleController.text.trim(),
        kind: selectedKind,
        description: descriptionController.text.trim(),
        durationSeconds: selectedKind == MediaKind.image
            ? (int.tryParse(durationController.text.trim()) ?? 15)
            : 0,
        externalUrl: urlController.text.trim().isEmpty
            ? null
            : urlController.text.trim(),
        fileBytes: pickedFile?.bytes,
        fileName: pickedFile?.name,
      );
      _showMessage('Media uploaded to ${client.name}.');
    } catch (error) {
      _showMessage('Media upload failed: $error');
    }
  }

  Future<void> _showAssignToScreensDialog(MediaItem item) async {
    final controller = widget.controller;
    if (controller.screens.isEmpty) {
      _showMessage('No screens registered yet.');
      return;
    }

    final selected = <String>{
      for (final screen in controller.screens)
        if (screen.assignedMediaIds.contains(item.id)) screen.id,
    };

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign "${item.title}" to Screens'),
          content: SizedBox(
            width: _dialogContentWidth(context, 400),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final screen in controller.screens)
                      CheckboxListTile(
                        value: selected.contains(screen.id),
                        title: Text(screen.name),
                        subtitle: Text(screen.location.isEmpty
                            ? 'No location'
                            : screen.location),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(screen.id);
                            } else {
                              selected.remove(screen.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                for (final screen in controller.screens) {
                  final hasIt = screen.assignedMediaIds.contains(item.id);
                  final shouldHave = selected.contains(screen.id);
                  if (shouldHave && !hasIt) {
                    await controller.updateScreen(
                      screen.copyWith(assignedMediaIds: [
                        ...screen.assignedMediaIds,
                        item.id
                      ]),
                    );
                  } else if (!shouldHave && hasIt) {
                    await controller.updateScreen(
                      screen.copyWith(
                        assignedMediaIds: screen.assignedMediaIds
                            .where((id) => id != item.id)
                            .toList(),
                      ),
                    );
                  }
                }
                _showMessage('Screen assignments updated.');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClient(ClientProfile client) async {
    final confirmed = await _confirm(
      title: 'Delete client?',
      message:
          'Deleting ${client.name} will also remove its media, analytics, and screen assignments.',
    );
    if (confirmed != true) return;
    await widget.controller.deleteClient(client.id);
    _showMessage('Client deleted.');
  }

  Future<void> _confirmDeleteMedia(MediaItem item) async {
    final confirmed = await _confirm(
      title: 'Delete media?',
      message:
          'Deleting ${item.title} removes it from all screen playlists and analytics.',
    );
    if (confirmed != true) return;
    await widget.controller.deleteMedia(item.id);
    _showMessage('Media deleted.');
  }

  Future<void> _addMediaToScreen(ScreenDevice screen, String mediaId) async {
    if (screen.assignedMediaIds.contains(mediaId)) return;
    await widget.controller.updateScreen(
      screen.copyWith(assignedMediaIds: [...screen.assignedMediaIds, mediaId]),
    );
  }

  Future<void> _removeMediaFromScreen(
      ScreenDevice screen, String mediaId) async {
    await widget.controller.updateScreen(
      screen.copyWith(
        assignedMediaIds:
            screen.assignedMediaIds.where((id) => id != mediaId).toList(),
      ),
    );
  }

  Future<void> _reorderPlaylist(
    ScreenDevice screen,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = [...screen.assignedMediaIds];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await widget.controller
        .updateScreen(screen.copyWith(assignedMediaIds: reordered));
  }

  Future<void> _setScreenOrientation(
    ScreenDevice screen,
    String screenPlayerOrientation,
  ) async {
    if (screen.screenPlayerOrientation.toLowerCase() ==
        screenPlayerOrientation.toLowerCase()) {
      return;
    }
    await widget.controller.updateScreen(
      screen.copyWith(screenPlayerOrientation: screenPlayerOrientation),
    );
    _showMessage(
      '${screen.name} set to ${screenPlayerOrientation.toLowerCase()}.',
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      _showMessage('The link is invalid.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<MediaItem> _topMedia(AppController controller) {
    final items = [...controller.mediaItems];
    items.sort(
      (left, right) => controller
          .totalPlaysForMedia(right.id)
          .compareTo(controller.totalPlaysForMedia(left.id)),
    );
    return items.take(5).toList();
  }

  List<MediaPerformanceSummary> _topMediaSummaries(AppController controller) {
    final summaries = _allMediaSummaries(controller);
    summaries.sort((left, right) {
      final byPlays = right.playCount.compareTo(left.playCount);
      if (byPlays != 0) return byPlays;
      return left.media.title
          .toLowerCase()
          .compareTo(right.media.title.toLowerCase());
    });
    return summaries.take(5).toList();
  }

  List<MediaPerformanceSummary> _allMediaSummaries(AppController controller) {
    final summaries = controller.mediaItems
        .map((item) => controller.mediaSummaryForMedia(item))
        .toList();
    summaries.sort((left, right) {
      final byPlays = right.playCount.compareTo(left.playCount);
      if (byPlays != 0) return byPlays;
      return left.media.title
          .toLowerCase()
          .compareTo(right.media.title.toLowerCase());
    });
    return summaries;
  }

  List<ScreenDevice> _assignedScreens(
      AppController controller, String mediaId) {
    return controller.screens
        .where((screen) => screen.assignedMediaIds.contains(mediaId))
        .toList();
  }

  int _sumClientPlays(AppController controller, String clientId) {
    return controller.mediaSummariesForClient(clientId).fold<int>(
          0,
          (sum, item) => sum + item.playCount,
        );
  }

  String _clientName(AppController controller, String clientId) {
    return controller.getClientById(clientId)?.name ?? 'Unknown client';
  }

  static Future<void> _downloadClientReportDirect(
    BuildContext context,
    AppController controller,
    ClientProfile client,
    Map<String, Uint8List> videoThumbnails,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await showDialog<_DownloadReportResult>(
      context: context,
      builder: (_) =>
          _ReportGroupDialog(initialStart: startDate, initialEnd: endDate),
    );
    if (result == null) return;

    if (!context.mounted) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingOverlay(message: 'Generating PDF...'),
    );

    void dismissOverlay() {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    // Let the UI render the loading dialog before heavy PDF work
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final pdf = await ReportPdfService.generateClientReport(
        client: client,
        controller: controller,
        startDate: result.startDate,
        endDate: result.endDate,
        groupBy: result.groupBy,
        videoThumbnails: videoThumbnails,
      );

      dismissOverlay();
      await downloadPdf(pdf, '${client.name}_report.pdf');
    } catch (e, st) {
      dismissOverlay();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF error: $e'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
      // ignore: avoid_print
      print('PDF generation error: $e\n$st');
    }
  }
}

class _ReportPeriodResult {
  const _ReportPeriodResult({required this.startDate, required this.endDate});
  final DateTime startDate;
  final DateTime endDate;
}

class _ReportPeriodDialog extends StatefulWidget {
  const _ReportPeriodDialog({required this.now});
  final DateTime now;

  @override
  State<_ReportPeriodDialog> createState() => _ReportPeriodDialogState();
}

class _ReportPeriodDialogState extends State<_ReportPeriodDialog> {
  _TimePeriod _period = _TimePeriod.monthly;
  DateTime? _selectedDate;
  DateTime? _selectedWeekStart;
  int? _selectedMonth;
  int? _selectedMonthYear;
  int? _selectedYear;
  DateTime? _customStart;
  DateTime? _customEnd;

  static DateTime _monday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  @override
  void initState() {
    super.initState();
    final now = widget.now;
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedWeekStart = _monday(now);
    _selectedMonth = now.month;
    _selectedMonthYear = now.year;
    _selectedYear = now.year;
  }

  ({DateTime from, DateTime to}) get _range {
    final now = widget.now;
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _TimePeriod.daily:
        final d = _selectedDate ?? today;
        return (from: d, to: d);
      case _TimePeriod.weekly:
        final mon = _selectedWeekStart ?? _monday(today);
        final sun = mon.add(const Duration(days: 6));
        return (from: mon, to: sun.isAfter(today) ? today : sun);
      case _TimePeriod.monthly:
        final first = DateTime(
            _selectedMonthYear ?? today.year, _selectedMonth ?? today.month, 1);
        final last = DateTime(first.year, first.month + 1, 0);
        return (from: first, to: last.isAfter(today) ? today : last);
      case _TimePeriod.yearly:
        final first = DateTime(_selectedYear ?? today.year, 1, 1);
        final last = DateTime(_selectedYear ?? today.year, 12, 31);
        return (from: first, to: last.isAfter(today) ? today : last);
      case _TimePeriod.custom:
        return (
          from: _customStart ?? DateTime(today.year, 1, 1),
          to: _customEnd ?? today,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now;
    return AlertDialog(
      title: const Text('Select Report Period'),
      content: SizedBox(
        width: _dialogContentWidth(context, 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _TimePeriod.values)
                  _DateRangeChip(
                    label: _formatTimePeriod(p),
                    selected: _period == p,
                    onTap: () => setState(() {
                      _period = p;
                      _customStart = null;
                      _customEnd = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_period == _TimePeriod.daily)
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? now,
                    firstDate: DateTime(2020),
                    lastDate: now,
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_selectedDate == null
                    ? 'Pick date'
                    : _formatDate(_selectedDate!)),
              )
            else if (_period == _TimePeriod.weekly)
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedWeekStart ?? now,
                    firstDate: DateTime(2020),
                    lastDate: now,
                    helpText: 'Pick any day in the week',
                  );
                  if (picked != null)
                    setState(() => _selectedWeekStart = _monday(picked));
                },
                icon: const Icon(Icons.calendar_view_week, size: 16),
                label: () {
                  final mon = _selectedWeekStart ??
                      _monday(DateTime(now.year, now.month, now.day));
                  final sun = mon.add(const Duration(days: 6));
                  return Text('${_formatDate(mon)} – ${_formatDate(sun)}');
                }(),
              )
            else if (_period == _TimePeriod.monthly)
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(_selectedMonthYear ?? now.year,
                        _selectedMonth ?? now.month),
                    firstDate: DateTime(2020),
                    lastDate: now,
                    helpText: 'Pick any day in the month',
                  );
                  if (picked != null)
                    setState(() {
                      _selectedMonth = picked.month;
                      _selectedMonthYear = picked.year;
                    });
                },
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(() {
                  const months = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec'
                  ];
                  return '${months[(_selectedMonth ?? now.month) - 1]} ${_selectedMonthYear ?? now.year}';
                }()),
              )
            else if (_period == _TimePeriod.yearly)
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(_selectedYear ?? now.year),
                    firstDate: DateTime(2020),
                    lastDate: now,
                    helpText: 'Pick any day in the year',
                  );
                  if (picked != null)
                    setState(() => _selectedYear = picked.year);
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('${_selectedYear ?? now.year}'),
              )
            else if (_period == _TimePeriod.custom)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customStart ?? now,
                          firstDate: DateTime(2020),
                          lastDate: now,
                        );
                        if (picked != null)
                          setState(() => _customStart = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_customStart == null
                          ? 'Start date'
                          : _formatDate(_customStart!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _customEnd ?? now,
                          firstDate: DateTime(2020),
                          lastDate: now,
                        );
                        if (picked != null) setState(() => _customEnd = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_customEnd == null
                          ? 'End date'
                          : _formatDate(_customEnd!)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_period == _TimePeriod.custom &&
                (_customStart == null || _customEnd == null)) return;
            final r = _range;
            Navigator.of(context).pop(
              _ReportPeriodResult(startDate: r.from, endDate: r.to),
            );
          },
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Download'),
        ),
      ],
    );
  }
}

class _SectionMeta {
  const _SectionMeta(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class _ScreenReportCard extends StatelessWidget {
  const _ScreenReportCard({
    required this.screen,
    required this.controller,
    required this.from,
    required this.to,
    this.isExpanded = false,
    this.onToggle,
  });

  final ScreenDevice screen;
  final AppController controller;
  final DateTime from;
  final DateTime to;
  final bool isExpanded;
  final VoidCallback? onToggle;

  bool get _isNowPlaying {
    final ts = screen.lastPlaybackAt;
    if (ts == null || ts.isEmpty) return false;
    final last = DateTime.tryParse(ts);
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds <= 10;
  }

  @override
  Widget build(BuildContext context) {
    final screenMediaStats =
        controller.playbackForScreen(screen.id, from: from, to: to);
    final filteredPlayCount =
        controller.playsForScreen(screen.id, from: from, to: to);
    String? latestTimestamp(String? left, String? right) {
      final leftDate = DateTime.tryParse(left ?? '');
      final rightDate = DateTime.tryParse(right ?? '');
      if (leftDate == null) return right;
      if (rightDate == null) return left;
      return rightDate.isAfter(leftDate) ? right : left;
    }

    final statsByMediaId = <String, ({int plays, String? lastPlayedAt})>{};
    for (final stat in screenMediaStats) {
      final current = statsByMediaId[stat.mediaId];
      statsByMediaId[stat.mediaId] = (
        plays: (current?.plays ?? 0) + stat.playCount,
        lastPlayedAt: latestTimestamp(current?.lastPlayedAt, stat.lastPlayedAt),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with screen name
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.tv_rounded,
                        color: Color(0xFF111827),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            screen.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            screen.location.isEmpty
                                ? 'Location not set'
                                : screen.location,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isNowPlaying)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Playing',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _SimpleStatBox(
                  label: 'Total Plays',
                  value: '$filteredPlayCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SimpleStatBox(
                  label: 'Last Played',
                  value: _formatTimestamp(screen.lastPlaybackAt),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Videos breakdown — always show assigned playlist, overlay play counts
          () {
            final assignedMedia = screen.assignedMediaIds
                .map((id) =>
                    controller.mediaItems.where((m) => m.id == id).firstOrNull)
                .whereType<MediaItem>()
                .toList();
            if (assignedMedia.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No media assigned to this screen',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF9CA3AF),
                        ),
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Playlist Videos',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < assignedMedia.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF374151),
                                          fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(assignedMedia[i].title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Color(0xFF111827))),
                                    const SizedBox(height: 2),
                                    Text(
                                      () {
                                        final summary =
                                            statsByMediaId[assignedMedia[i].id];
                                        return 'Last: ${_formatTimestamp(summary?.lastPlayedAt)}';
                                      }(),
                                      style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  () {
                                    final summary =
                                        statsByMediaId[assignedMedia[i].id];
                                    return '${summary?.plays ?? 0}×';
                                  }(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF374151),
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < assignedMedia.length - 1)
                          const Divider(
                              height: 1, color: Color(0xFFF3F4F6), indent: 56),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ScreenDailyBreakdown(
                    screen: screen, controller: controller, from: from, to: to),
              ],
            );
          }(),
        ],
      ),
    );
  }
}

class _ClientReportCard extends StatelessWidget {
  const _ClientReportCard({
    required this.client,
    required this.controller,
    required this.videoThumbnails,
    required this.from,
    required this.to,
    this.isExpanded = false,
    this.onToggle,
  });

  final ClientProfile client;
  final AppController controller;
  final Map<String, Uint8List> videoThumbnails;
  final DateTime from;
  final DateTime to;
  final bool isExpanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final mediaSummaries =
        controller.mediaSummariesForClient(client.id, from: from, to: to);
    final mediaItems = mediaSummaries.map((summary) => summary.media).toList();
    final totalPlays =
        mediaSummaries.fold<int>(0, (sum, item) => sum + item.playCount);
    final totalSeconds =
        mediaSummaries.fold<int>(0, (sum, item) => sum + item.playTimeSeconds);
    final playTimeLabel = totalSeconds < 60
        ? '${totalSeconds}s'
        : totalSeconds < 3600
            ? '${totalSeconds ~/ 60}m ${totalSeconds % 60}s'
            : '${totalSeconds ~/ 3600}h ${(totalSeconds % 3600) ~/ 60}m';

    // All media IDs for this client (including removed-from-playlist)
    final assignedIds = <String>{};
    for (final s in controller.screens) {
      for (final id in s.assignedMediaIds) {
        assignedIds.add(id);
      }
    }
    final activeMedia =
        mediaSummaries.where((m) => assignedIds.contains(m.media.id)).toList();
    final removedMedia =
        mediaSummaries.where((m) => !assignedIds.contains(m.media.id)).toList();

    // Screen breakdown for this client
    final screenBreakdown = <({ScreenDevice screen, int plays, int secs})>[];
    for (final screen in controller.screens) {
      var plays = 0;
      var secs = 0;
      for (final m in mediaItems) {
        for (final stat
            in controller.playbackForScreen(screen.id, from: from, to: to)) {
          if (stat.mediaId == m.id) {
            plays += stat.playCount;
            secs += stat.playCount * m.durationSeconds;
          }
        }
      }
      if (plays > 0)
        screenBreakdown.add((screen: screen, plays: plays, secs: secs));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF111827),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (client.contactName.isNotEmpty)
                          _ContactChip(
                              icon: Icons.person_outline_rounded,
                              label: client.contactName),
                        if (client.contactEmail.isNotEmpty)
                          _ContactChip(
                              icon: Icons.email_outlined,
                              label: client.contactEmail),
                        if (client.phone.isNotEmpty)
                          _ContactChip(
                              icon: Icons.phone_outlined, label: client.phone),
                        if (client.contactEmail.isEmpty &&
                            client.contactName.isEmpty &&
                            client.phone.isEmpty)
                          const Text('No contact details',
                              style: TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () =>
                    _AdminDashboardPageState._downloadClientReportDirect(
                        context, controller, client, videoThumbnails, from, to),
                icon: const Icon(Icons.download_outlined, size: 20),
                color: const Color(0xFF111827),
                tooltip: 'Download Report',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SimpleStatBox(
                  label: 'Media Assets',
                  value: '${mediaItems.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SimpleStatBox(
                  label: 'Total Plays',
                  value: '$totalPlays',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SimpleStatBox(
                  label: 'Total Play Time',
                  value: playTimeLabel,
                ),
              ),
            ],
          ),
          if (isExpanded && mediaItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Screen breakdown
            if (screenBreakdown.isNotEmpty) ...[
              const Text(
                'Screen Breakdown',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < screenBreakdown.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.tv_rounded,
                                size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                screenBreakdown[i].screen.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${screenBreakdown[i].plays} plays  ·  ${() {
                                  final s = screenBreakdown[i].secs;
                                  if (s < 60) return '${s}s';
                                  if (s < 3600) return '${s ~/ 60}m ${s % 60}s';
                                  return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
                                }()}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3B82F6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < screenBreakdown.length - 1)
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Active media breakdown
            const Text(
              'Media Breakdown',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 10),
            _MediaBreakdownList(summaries: activeMedia, controller: controller),
            // Removed from playlist (but not deleted)
            if (removedMedia.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.remove_circle_outline,
                      size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  const Text(
                    'Removed from Playlist',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MediaBreakdownList(
                  summaries: removedMedia,
                  controller: controller,
                  dimmed: true),
            ],
          ],
        ],
      ),
    );
  }
}

class _TodayKpiRow extends StatefulWidget {
  const _TodayKpiRow({required this.screen, required this.controller});
  final ScreenDevice screen;
  final AppController controller;
  @override
  State<_TodayKpiRow> createState() => _TodayKpiRowState();
}

class _TodayKpiRowState extends State<_TodayKpiRow> {
  _TimePeriod _period = _TimePeriod.daily;
  DateTime? _customFrom;
  DateTime? _customTo;

  ({DateTime from, DateTime to}) get _range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _TimePeriod.daily:
        return (from: today, to: today);
      case _TimePeriod.weekly:
        return (
          from: today.subtract(Duration(days: today.weekday - 1)),
          to: today
        );
      case _TimePeriod.monthly:
        return (from: DateTime(today.year, today.month, 1), to: today);
      case _TimePeriod.yearly:
        return (from: DateTime(today.year, 1, 1), to: today);
      case _TimePeriod.custom:
        return (from: _customFrom ?? today, to: _customTo ?? today);
    }
  }

  String get _periodLabel {
    switch (_period) {
      case _TimePeriod.daily:
        return 'Today';
      case _TimePeriod.weekly:
        return 'This Week';
      case _TimePeriod.monthly:
        return 'This Month';
      case _TimePeriod.yearly:
        return 'This Year';
      case _TimePeriod.custom:
        if (_customFrom != null && _customTo != null) {
          return '${_customFrom!.month}/${_customFrom!.day} – ${_customTo!.month}/${_customTo!.day}';
        }
        return 'Custom';
    }
  }

  Future<void> _showPicker() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _KpiPeriodDialog(
        period: _period,
        customFrom: _customFrom,
        customTo: _customTo,
        onApply: (p, from, to) => setState(() {
          _period = p;
          _customFrom = from;
          _customTo = to;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final from = range.from;
    final to =
        DateTime(range.to.year, range.to.month, range.to.day, 23, 59, 59);

    final plays =
        widget.controller.playsForScreen(widget.screen.id, from: from, to: to);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _showPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _periodLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.expand_more_rounded,
                  size: 14, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Plays',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF16A34A))),
                    const SizedBox(height: 2),
                    Text('$plays',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF15803D))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiPeriodDialog extends StatefulWidget {
  const _KpiPeriodDialog({
    required this.period,
    required this.customFrom,
    required this.customTo,
    required this.onApply,
  });
  final _TimePeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;
  final void Function(_TimePeriod, DateTime?, DateTime?) onApply;
  @override
  State<_KpiPeriodDialog> createState() => _KpiPeriodDialogState();
}

class _KpiPeriodDialogState extends State<_KpiPeriodDialog> {
  late _TimePeriod _period;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _period = widget.period;
    _from = widget.customFrom;
    _to = widget.customTo;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Period'),
      content: SizedBox(
        width: _dialogContentWidth(context, 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _TimePeriod.values)
                  _DateRangeChip(
                    label: _formatTimePeriod(p),
                    selected: _period == p,
                    onTap: () => setState(() {
                      _period = p;
                      if (p != _TimePeriod.custom) {
                        _from = null;
                        _to = null;
                      }
                    }),
                  ),
              ],
            ),
            if (_period == _TimePeriod.custom) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _from ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _from = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label:
                          Text(_from == null ? 'Start' : _formatDate(_from!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _to ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _to = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(_to == null ? 'End' : _formatDate(_to!)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_period == _TimePeriod.custom && (_from == null || _to == null))
              return;
            widget.onApply(_period, _from, _to);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _MediaBreakdownList extends StatelessWidget {
  const _MediaBreakdownList({
    required this.summaries,
    required this.controller,
    this.dimmed = false,
  });

  final List<MediaPerformanceSummary> summaries;
  final AppController controller;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    String formatDuration(int seconds) {
      if (seconds < 60) return '${seconds}s';
      if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
      return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
    }

    return Container(
      decoration: BoxDecoration(
        color: dimmed ? const Color(0xFFF9FAFB) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < summaries.length; i++) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _KindIcon(kind: summaries[i].media.kind),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summaries[i].media.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: dimmed
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF111827),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${summaries[i].playCount}×',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151),
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatDuration(summaries[i].playTimeSeconds)} • ${summaries[i].screenCount} screens',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (i < summaries.length - 1)
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ],
        ],
      ),
    );
  }
}

class _MonthListSelector extends StatelessWidget {
  const _MonthListSelector({
    required this.selectedMonth,
    required this.selectedYear,
    required this.availableMonths,
    required this.availableYears,
    required this.onChanged,
  });

  final int selectedMonth;
  final int selectedYear;
  final List<int> availableMonths;
  final List<int> availableYears;
  final void Function(int month, int year) onChanged;

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year selector row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final y in availableYears)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _DateRangeChip(
                    label: '$y',
                    selected: y == selectedYear,
                    onTap: () {
                      final months = availableMonths;
                      final newMonth = months.contains(selectedMonth)
                          ? selectedMonth
                          : months.first;
                      onChanged(newMonth, y);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Month list
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in availableMonths)
              _DateRangeChip(
                label: _monthNames[m - 1],
                selected: m == selectedMonth && selectedYear == selectedYear,
                onTap: () => onChanged(m, selectedYear),
              ),
          ],
        ),
      ],
    );
  }
}

class _YearListSelector extends StatelessWidget {
  const _YearListSelector({
    required this.selectedYear,
    required this.availableYears,
    required this.onChanged,
  });

  final int selectedYear;
  final List<int> availableYears;
  final void Function(int year) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final y in availableYears)
          _DateRangeChip(
            label: '$y',
            selected: y == selectedYear,
            onTap: () => onChanged(y),
          ),
      ],
    );
  }
}

class _ScreenDailyBreakdown extends StatelessWidget {
  const _ScreenDailyBreakdown({
    required this.screen,
    required this.controller,
    required this.from,
    required this.to,
  });

  final ScreenDevice screen;
  final AppController controller;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    // Group playback stats for this screen by date
    final stats = controller.playbackForScreen(screen.id, from: from, to: to);
    final Map<String, int> playsByDate = {};
    for (final stat in stats) {
      final d = stat.playDate ?? '';
      if (d.isEmpty) continue;
      playsByDate[d] = (playsByDate[d] ?? 0) + stat.playCount;
    }
    if (playsByDate.isEmpty) return const SizedBox.shrink();

    final sortedDates = playsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Breakdown',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < sortedDates.length; i++) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateStr(sortedDates[i]),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${playsByDate[sortedDates[i]]} plays',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < sortedDates.length - 1)
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateStr(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _SimpleStatBox extends StatelessWidget {
  const _SimpleStatBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final isVideo = kind == MediaKind.video;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        size: 16,
        color: const Color(0xFF6B7280),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5A6B80),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardNav extends StatelessWidget {
  const _DashboardNav({
    required this.controller,
    required this.selected,
    required this.onSelected,
  });

  final AppController controller;
  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final organization = controller.organization;
    final items = [
      (_AdminSection.dashboard, Icons.dashboard_outlined, 'Dashboard'),
      (_AdminSection.screens, Icons.tv_outlined, 'Screens'),
      (_AdminSection.clients, Icons.groups_outlined, 'Clients'),
      (_AdminSection.player, Icons.playlist_play_rounded, 'Screen Player'),
      (_AdminSection.reports, Icons.bar_chart_rounded, 'Reports'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'B',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Brand Slots',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        organization.companyName.isEmpty
                            ? 'Management System'
                            : organization.companyName,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _NavButton(
                        icon: item.$2,
                        label: item.$3,
                        selected: selected == item.$1,
                        onTap: () => onSelected(item.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // User footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF3F4F6)),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        organization.adminName.isEmpty
                            ? 'A'
                            : organization.adminName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          organization.adminName.isEmpty
                              ? 'Admin'
                              : organization.adminName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF6EE7B7)),
                          ),
                          child: const Text(
                            'Super Admin',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: controller.logout,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
              ),
            ],
          ),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
    this.icon,
  });

  final String title;
  final String value;
  final String detail;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE3ED)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF5A6B80))),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(detail, style: const TextStyle(color: Color(0xFF5A6B80))),
              ],
            ),
          ),
          if (icon != null)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricListTile extends StatelessWidget {
  const _MetricListTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingWidget,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 360;
          final trailingChild = trailingWidget ??
              (trailing != null
                  ? Text(
                      trailing!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    )
                  : const SizedBox.shrink());

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                if (trailingWidget != null || trailing != null) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: trailingChild),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null) trailingWidget!,
              if (trailingWidget == null && trailing != null) trailingChild,
            ],
          );
        },
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3F4F6) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xFFF9FAFB),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check, color: Color(0xFF111827), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: compact ? 28 : 36,
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChipSummary extends StatelessWidget {
  const _ChipSummary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF10233D)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind});

  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final isVideo = kind == MediaKind.video;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isVideo ? const Color(0xFFFFF4E8) : const Color(0xFFEAF8F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isVideo ? 'Video' : 'Photo',
        style: TextStyle(
          color: isVideo ? const Color(0xFFCA6702) : const Color(0xFF005F73),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF111827) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: selected ? Colors.transparent : const Color(0xFFF9FAFB),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE3ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF10233D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5A6B80)),
          ),
        ],
      ),
    );
  }
}

class _ScreenStatusCard extends StatelessWidget {
  const _ScreenStatusCard({required this.screen});
  final ScreenDevice screen;

  bool get _isActive {
    final ts = screen.lastPlaybackAt;
    if (ts == null || ts.isEmpty) return false;
    final last = DateTime.tryParse(ts);
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds <= 10;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color:
                  _isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  screen.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  screen.location.isEmpty ? 'No location' : screen.location,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.play_arrow_outlined,
            size: 18,
            color:
                _isActive ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingBadge extends StatelessWidget {
  const _NowPlayingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FAEF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.play_circle_filled_rounded,
              size: 14, color: Color(0xFF1F8A4D)),
          SizedBox(width: 5),
          Text(
            'Now Playing',
            style: TextStyle(
              color: Color(0xFF1F8A4D),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isNowPlaying(ScreenDevice screen) {
  final activity = screen.lastSeenAt ?? screen.lastPlaybackAt;
  if (activity == null || activity.isEmpty) return false;
  final last = DateTime.tryParse(activity);
  if (last == null) return false;
  return DateTime.now().difference(last).inMinutes <= 2;
}

class _SelectableTileWithDelete extends StatelessWidget {
  const _SelectableTileWithDelete({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3F4F6) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xFFF9FAFB),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check, color: Color(0xFF111827), size: 16),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: const Color(0xFFEF4444),
                tooltip: 'Delete client',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.kind});
  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        kind == MediaKind.video
            ? Icons.videocam_outlined
            : Icons.image_outlined,
        size: 40,
        color: const Color(0xFF9CA3AF),
      ),
    );
  }
}

class _VideoPreviewTile extends StatefulWidget {
  const _VideoPreviewTile(
      {required this.url,
      this.mediaId,
      this.controller,
      this.onThumbnailCaptured});
  final String url;
  final String? mediaId;
  final AppController? controller;
  final void Function(String mediaId, Uint8List bytes)? onThumbnailCaptured;

  @override
  State<_VideoPreviewTile> createState() => _VideoPreviewTileState();
}

class _VideoPreviewTileState extends State<_VideoPreviewTile> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await ctrl.initialize();
      await ctrl.seekTo(Duration.zero);
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      // Save duration if not yet stored
      final durationSecs = ctrl.value.duration.inSeconds;
      if (durationSecs > 0 &&
          widget.mediaId != null &&
          widget.controller != null) {
        unawaited(widget.controller!.updateMediaDuration(
          mediaId: widget.mediaId!,
          durationSeconds: durationSecs,
        ));
      }
      setState(() {
        _controller = ctrl;
        _initialized = true;
      });
      // Capture first frame after next paint
      if (widget.onThumbnailCaptured != null && widget.mediaId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _captureFrame());
      }
    } catch (_) {}
  }

  Future<void> _captureFrame() async {
    try {
      if (kIsWeb) {
        final bytes = await captureVideoThumbnailWeb(widget.url);
        if (bytes != null && mounted) {
          widget.onThumbnailCaptured!(widget.mediaId!, bytes);
        }
        return;
      }
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      widget.onThumbnailCaptured!(
          widget.mediaId!, byteData.buffer.asUint8List());
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(widget.url),
          mode: LaunchMode.externalApplication),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_initialized && _controller != null)
              RepaintBoundary(
                key: _repaintKey,
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: const Color(0xFF111827),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientExpandableCard extends StatelessWidget {
  const _ClientExpandableCard({
    required this.client,
    required this.controller,
    required this.isExpanded,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onUpload,
    required this.onDeleteMedia,
    required this.onAssignToScreens,
    this.onThumbnailCaptured,
  });

  final ClientProfile client;
  final AppController controller;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUpload;
  final void Function(MediaItem) onDeleteMedia;
  final void Function(MediaItem) onAssignToScreens;
  final void Function(String mediaId, Uint8List bytes)? onThumbnailCaptured;

  @override
  Widget build(BuildContext context) {
    final mediaItems = controller.mediaForClient(client.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        Widget buildHeaderButtons() {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 13),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 13),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFFEF4444),
                ),
              ),
            ],
          );
        }

        Widget buildHeader() {
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                '${mediaItems.length} media asset${mediaItems.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          );

          final leading = Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.groups_outlined,
              size: 18,
              color: Color(0xFF6B7280),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                buildHeaderButtons(),
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: titleBlock),
              if (!isExpanded) ...[
                buildHeaderButtons(),
                const SizedBox(width: 8),
              ],
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF9CA3AF),
              ),
            ],
          );
        }

        Widget buildMediaGrid(BoxConstraints innerConstraints) {
          final itemWidth = innerConstraints.maxWidth < 360
              ? innerConstraints.maxWidth
              : 320.0;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final item in mediaItems)
                SizedBox(
                  width: itemWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          child: item.url.isNotEmpty
                              ? (item.kind == MediaKind.image
                                  ? Image.network(
                                      item.url,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _MediaPlaceholder(kind: item.kind),
                                    )
                                  : _VideoPreviewTile(
                                      url: item.url,
                                      mediaId: item.id,
                                      controller: controller,
                                      onThumbnailCaptured: onThumbnailCaptured,
                                    ))
                              : _MediaPlaceholder(kind: item.kind),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              if (item.kind == MediaKind.image)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.durationSeconds}s',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              IconButton(
                                onPressed: () => onDeleteMedia(item),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                color: const Color(0xFFEF4444),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () => onAssignToScreens(item),
                                icon: const Icon(Icons.tv_outlined, size: 18),
                                color: const Color(0xFF111827),
                                tooltip: 'Add to screens',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                        if (item.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Text(
                              item.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpanded
                  ? const Color(0xFF111827)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onTap,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, compact ? 20 : 12, 16),
                  child: buildHeader(),
                ),
              ),
              if (isExpanded) ...[
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final stackActions = innerConstraints.maxWidth < 620;
                          final chips = Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (client.contactName.isNotEmpty)
                                _ChipSummary(
                                  label: 'Contact',
                                  value: client.contactName,
                                ),
                              if (client.contactEmail.isNotEmpty)
                                _ChipSummary(
                                  label: 'Email',
                                  value: client.contactEmail,
                                ),
                              if (client.phone.isNotEmpty)
                                _ChipSummary(
                                  label: 'Phone',
                                  value: client.phone,
                                ),
                            ],
                          );
                          final actions = Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: onEdit,
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                label: const Text('Edit'),
                              ),
                              OutlinedButton.icon(
                                onPressed: onDelete,
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 14),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: onUpload,
                                icon:
                                    const Icon(Icons.upload_rounded, size: 14),
                                label: const Text('Upload Media'),
                              ),
                            ],
                          );

                          if (stackActions) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                chips,
                                const SizedBox(height: 12),
                                actions,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: chips),
                              const SizedBox(width: 12),
                              actions,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      if (mediaItems.isEmpty)
                        const _EmptyStateCard(
                          title: 'No media uploaded',
                          subtitle: 'Upload photos or videos for this client.',
                          compact: true,
                        )
                      else
                        LayoutBuilder(
                          builder: (context, innerConstraints) =>
                              buildMediaGrid(innerConstraints),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ClientDraft {
  const _ClientDraft({
    required this.name,
    required this.contactName,
    required this.contactEmail,
    required this.phone,
    required this.notes,
  });

  final String name;
  final String contactName;
  final String contactEmail;
  final String phone;
  final String notes;
}

String _formatTimestamp(String? value) {
  if (value == null || value.isEmpty) return 'Never';
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$month/$day/${date.year} $hour:$minute';
}

String _formatTimePeriod(_TimePeriod period) {
  switch (period) {
    case _TimePeriod.daily:
      return 'Daily';
    case _TimePeriod.weekly:
      return 'Weekly';
    case _TimePeriod.monthly:
      return 'Monthly';
    case _TimePeriod.yearly:
      return 'Yearly';
    case _TimePeriod.custom:
      return 'Custom';
  }
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

double _dialogContentWidth(BuildContext context, double desiredWidth) {
  final availableWidth = MediaQuery.sizeOf(context).width - 32;
  return availableWidth < desiredWidth ? availableWidth : desiredWidth;
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:
                  selected ? const Color(0xFF111827) : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadReportResult {
  const _DownloadReportResult({
    required this.groupBy,
    required this.startDate,
    required this.endDate,
  });
  final ReportGroupBy groupBy;
  final DateTime startDate;
  final DateTime endDate;
}

class _ReportGroupDialog extends StatefulWidget {
  const _ReportGroupDialog({this.initialStart, this.initialEnd});
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<_ReportGroupDialog> createState() => _ReportGroupDialogState();
}

class _ReportGroupDialogState extends State<_ReportGroupDialog> {
  ReportGroupBy _groupBy = ReportGroupBy.daily;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = widget.initialStart ?? DateTime(now.year, now.month, 1);
    _end = widget.initialEnd ?? DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Download Report'),
      content: SizedBox(
        width: _dialogContentWidth(context, 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date Range',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _start,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _start = picked);
                    },
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text('From: ${_formatDate(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _end,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _end = picked);
                    },
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text('To: ${_formatDate(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Breakdown Type',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _BreakdownOption(
                    label: 'Daily',
                    subtitle: 'Date-wise breakdown per video',
                    icon: Icons.calendar_today_outlined,
                    selected: _groupBy == ReportGroupBy.daily,
                    onTap: () => setState(() => _groupBy = ReportGroupBy.daily),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BreakdownOption(
                    label: 'Monthly',
                    subtitle: 'Month-wise breakdown per video',
                    icon: Icons.calendar_month_outlined,
                    selected: _groupBy == ReportGroupBy.monthly,
                    onTap: () =>
                        setState(() => _groupBy = ReportGroupBy.monthly),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            _DownloadReportResult(
                groupBy: _groupBy, startDate: _start, endDate: _end),
          ),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Download PDF'),
        ),
      ],
    );
  }
}

class _BreakdownOption extends StatelessWidget {
  const _BreakdownOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? Colors.white : const Color(0xFF6B7280)),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF111827),
                )),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF9CA3AF),
                )),
          ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 18),
              Text(message,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      ],
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF111827) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  selected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
