// ignore_for_file: unused_field, unused_local_variable, unused_element, unnecessary_cast

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/app_models.dart';
import '../services/screen_media_cache.dart';
import '../state/app_controller.dart';

enum _StatPeriod { daily, weekly, monthly, yearly, custom }
enum _PlayerOrientation { portrait, landscape }

class ScreenPlayerPage extends StatefulWidget {
  const ScreenPlayerPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScreenPlayerPage> createState() => _ScreenPlayerPageState();
}

class _ScreenPlayerPageState extends State<ScreenPlayerPage> {
  int _currentIndex = 0;
  int _visibleIndex = 0;
  String? _visibleMediaId;
  int _loadToken = 0;
  bool _isAdvancing = false;
  bool _hasPendingPlaylistRefresh = false;
  Timer? _imageTimer;
  Timer? _midnightTimer;
  Timer? _heartbeatTimer;
  VideoPlayerController? _videoController;
  ImageProvider<Object>? _imageProvider;
  late final ScreenMediaCache _mediaCache;
  String _playlistSignature = '';
  DateTime _currentDay = DateTime.now();
  _PlayerOrientation _playerOrientation = _PlayerOrientation.landscape;

  // Round tracking: incremented each time we wrap back to index 0
  int _roundsPlayedThisSession = 0;

  // Stats overlay
  _StatPeriod _statPeriod = _StatPeriod.daily;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _showStatPanel = false;

  @override
  void initState() {
    super.initState();
    _mediaCache = createScreenMediaCache();
    widget.controller.addListener(_handleControllerUpdate);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _playerOrientation = _currentScreenOrientation();
    unawaited(_applyPlayerOrientation(_playerOrientation));
    _playlistSignature = _buildPlaylistSignature(_media);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCurrentMedia());
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
    _scheduleMidnightCheck();
  }

  @override
  void didUpdateWidget(covariant ScreenPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerUpdate);
      widget.controller.addListener(_handleControllerUpdate);
      _playlistSignature = _buildPlaylistSignature(_media);
      _syncPlayerOrientation();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _imageTimer?.cancel();
    _midnightTimer?.cancel();
    _heartbeatTimer?.cancel();
    _disposeVideo();
    super.dispose();
  }

  Future<void> _sendHeartbeat() async {
    final screen = widget.controller.activeScreen;
    if (screen == null) return;
    try {
      await widget.controller.updateScreen(
        screen.copyWith(lastSeenAt: DateTime.now().toIso8601String()),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _applyPlayerOrientation(_PlayerOrientation orientation) async {
    final orientations = orientation == _PlayerOrientation.portrait
        ? const [DeviceOrientation.portraitUp]
        : const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
    await SystemChrome.setPreferredOrientations(orientations);
  }

  Future<void> _setPlayerOrientation(_PlayerOrientation orientation) async {
    if (_playerOrientation == orientation) return;
    setState(() => _playerOrientation = orientation);
    await _applyPlayerOrientation(orientation);
  }

  _PlayerOrientation _orientationFromValue(String value) {
    return value.toLowerCase() == 'portrait'
        ? _PlayerOrientation.portrait
        : _PlayerOrientation.landscape;
  }

  _PlayerOrientation _currentScreenOrientation() {
    final screen = widget.controller.activeScreen;
    if (screen == null) return _PlayerOrientation.landscape;
    return _orientationFromValue(screen.screenPlayerOrientation);
  }

  void _syncPlayerOrientation() {
    final desired = _currentScreenOrientation();
    if (_playerOrientation == desired) return;
    setState(() => _playerOrientation = desired);
    unawaited(_applyPlayerOrientation(desired));
  }

  List<MediaItem> get _media {
    final screen = widget.controller.activeScreen;
    if (screen == null) return const [];
    return widget.controller.mediaForScreen(screen.id);
  }

  void _handleControllerUpdate() {
    _syncPlayerOrientation();
    final media = _media;
    final nextSignature = _buildPlaylistSignature(media);
    if (nextSignature == _playlistSignature) return;

    _playlistSignature = nextSignature;
    _syncOfflineCache(media);

    if (media.isEmpty) {
      _hasPendingPlaylistRefresh = false;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _prepareCurrentMedia());
      return;
    }

    final visibleItem = _visibleItem;
    final visibleStillExists =
        visibleItem != null && media.any((item) => item.id == visibleItem.id);

    if (!visibleStillExists) {
      _hasPendingPlaylistRefresh = false;
      _currentIndex = 0;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _prepareCurrentMedia());
      return;
    }

    _hasPendingPlaylistRefresh = true;
  }

  MediaItem? get _visibleItem {
    final media = _media;
    if (media.isEmpty) return null;
    final visibleMediaId = _visibleMediaId;
    if (visibleMediaId != null) {
      for (final item in media) {
        if (item.id == visibleMediaId) return item;
      }
    }
    if (_visibleIndex < 0 || _visibleIndex >= media.length) return null;
    return media[_visibleIndex];
  }

  String _buildPlaylistSignature(List<MediaItem> media) {
    return media
        .map((item) =>
            '${item.id}|${item.url}|${item.kind.name}|${item.durationSeconds}')
        .join('||');
  }

  Future<void> _prepareCurrentMedia() async {
    final activeScreen = widget.controller.activeScreen;
    final media = _media;
    if (activeScreen == null || media.isEmpty) {
      _imageTimer?.cancel();
      _disposeVideo();
      if (mounted) {
        setState(() {
          _currentIndex = 0;
          _visibleIndex = 0;
          _visibleMediaId = null;
          _imageProvider = null;
        });
      }
      return;
    }

    _syncOfflineCache(media);

    if (_currentIndex >= media.length) {
      _currentIndex = 0;
    }

    final current = media[_currentIndex];
    final token = ++_loadToken;

    _imageTimer?.cancel();
    unawaited(_sendHeartbeat());

    if (current.kind == MediaKind.image) {
      late final PreparedMediaImage prepared;
      try {
        prepared = await _mediaCache.prepareImage(current);
        await precacheImage(prepared.provider, context);
      } catch (_) {
        if (!mounted || token != _loadToken) return;
        _disposeVideo();
        setState(() {
          _imageProvider = null;
          _isAdvancing = false;
        });
        _imageTimer =
            Timer(Duration(seconds: current.durationSeconds), _advance);
        return;
      }

      if (!mounted || token != _loadToken) return;

      _disposeVideo();
      setState(() {
        _visibleIndex = _currentIndex;
        _visibleMediaId = current.id;
        _imageProvider = prepared.provider;
        _isAdvancing = false;
      });
      _imageTimer = Timer(Duration(seconds: current.durationSeconds), _advance);
      return;
    }

    late final VideoPlayerController controller;
    try {
      controller = await _mediaCache.prepareVideoController(current);
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      _disposeVideo();
      setState(() {
        _visibleIndex = _currentIndex;
        _visibleMediaId = current.id;
        _imageProvider = null;
        _isAdvancing = false;
      });
      _imageTimer = Timer(Duration(seconds: current.durationSeconds), _advance);
      return;
    }

    if (!mounted || token != _loadToken) {
      await controller.dispose();
      return;
    }

    final oldController = _videoController;
    controller.addListener(() {
      if (!mounted || _videoController != controller) return;
      final value = controller.value;
      if (!value.isInitialized || value.duration.inMilliseconds <= 0) return;
      if (value.position >= value.duration) {
        _advance();
      }
    });

    setState(() {
      _visibleIndex = _currentIndex;
      _visibleMediaId = current.id;
      _videoController = controller;
      _imageProvider = null;
      _isAdvancing = false;
    });

    await oldController?.dispose();
    await controller.play();
  }

  void _advance() {
    if (_isAdvancing) return;

    final screen = widget.controller.activeScreen;
    final media = _media;
    if (screen == null || media.isEmpty) return;

    final visibleItem = _visibleItem;
    final currentPosition = visibleItem == null
        ? -1
        : media.indexWhere((item) => item.id == visibleItem.id);
    final fallbackIndex = _visibleIndex.clamp(0, media.length - 1) as int;

    final videoDuration = _videoController?.value.duration;
    if (visibleItem != null &&
        visibleItem.kind == MediaKind.video &&
        visibleItem.durationSeconds == 0 &&
        videoDuration != null &&
        videoDuration.inSeconds > 0) {
      unawaited(
        widget.controller.updateMediaDuration(
          mediaId: visibleItem.id,
          durationSeconds: videoDuration.inSeconds,
        ),
      );
    }

    _isAdvancing = true;

    int nextIndex;
    if (_hasPendingPlaylistRefresh) {
      _hasPendingPlaylistRefresh = false;
      nextIndex = visibleItem == null
          ? 0
          : (currentPosition == -1 ? 0 : (currentPosition + 1) % media.length);
    } else {
      nextIndex = (_currentIndex + 1) % media.length;
    }

    // A round completes when we wrap back to index 0 (after playing the last item)
    final isLastItem = (currentPosition == media.length - 1) ||
        (_currentIndex == media.length - 1 && nextIndex == 0);
    if (isLastItem && nextIndex == 0) {
      _roundsPlayedThisSession++;
      unawaited(
        widget.controller.reportScreenPlayback(
          screenId: screen.id,
          mediaId: '',
          completedRound: true,
        ),
      );
    }

    setState(() => _currentIndex = nextIndex);
    _prepareCurrentMedia();
  }

  void _disposeVideo() {
    final controller = _videoController;
    _videoController = null;
    controller?.dispose();
  }

  void _syncOfflineCache(List<MediaItem> items) {
    _mediaCache.syncAssignedMedia(items);
    _mediaCache.pruneToAssignedMedia(items);
  }

  void _scheduleMidnightCheck() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final untilMidnight = tomorrow.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(untilMidnight, () {
      if (!mounted) return;
      setState(() => _currentDay = DateTime.now());
      _scheduleMidnightCheck();
    });
  }

  ({DateTime from, DateTime to}) get _statDateRange {
    final today =
        DateTime(_currentDay.year, _currentDay.month, _currentDay.day);
    switch (_statPeriod) {
      case _StatPeriod.daily:
        return (from: today, to: today);
      case _StatPeriod.weekly:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return (from: monday, to: today);
      case _StatPeriod.monthly:
        return (from: DateTime(today.year, today.month, 1), to: today);
      case _StatPeriod.yearly:
        return (from: DateTime(today.year, 1, 1), to: today);
      case _StatPeriod.custom:
        return (
          from: _customFrom ?? today,
          to: _customTo ?? today,
        );
    }
  }

  ({int rounds}) _statsForPeriod() {
    final screen = widget.controller.activeScreen;
    if (screen == null) return (rounds: 0);
    final range = _statDateRange;
    final from = range.from;
    final to =
        DateTime(range.to.year, range.to.month, range.to.day, 23, 59, 59);

    var rounds = 0;
    for (final stat in widget.controller.playbackStats) {
      if (stat.screenId != screen.id) continue;
      if (stat.mediaId != _kRoundSentinel) continue;
      final d =
          stat.playDate != null ? DateTime.tryParse(stat.playDate!) : null;
      if (d == null) continue;
      if (d.isBefore(from) || d.isAfter(to)) continue;
      rounds += stat.roundCount;
    }
    return (rounds: rounds);
  }

  String _periodLabel() {
    switch (_statPeriod) {
      case _StatPeriod.daily:
        return 'Today';
      case _StatPeriod.weekly:
        return 'This Week';
      case _StatPeriod.monthly:
        return 'This Month';
      case _StatPeriod.yearly:
        return 'This Year';
      case _StatPeriod.custom:
        if (_customFrom != null && _customTo != null) {
          return '${_customFrom!.month}/${_customFrom!.day} – ${_customTo!.month}/${_customTo!.day}';
        }
        return 'Custom';
    }
  }

  Future<void> _showPeriodPicker() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _StatPeriodSheet(
        current: _statPeriod,
        customFrom: _customFrom,
        customTo: _customTo,
        onSelected: (period, from, to) {
          setState(() {
            _statPeriod = period;
            _customFrom = from;
            _customTo = to;
          });
        },
      ),
    );
    if (mounted) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = widget.controller.activeScreen;
    if (screen == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final current = _visibleItem;
    final videoController = _videoController;
    final stats = _statsForPeriod();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPress: widget.controller.logout,
        child: Stack(
          children: [
            SizedBox.expand(
              child: current == null
                  ? const Center(
                      child: Text(
                        'No media assigned yet.',
                        style: TextStyle(color: Colors.white54, fontSize: 20),
                      ),
                    )
                  : current.kind == MediaKind.image
                      ? _buildImage(current)
                      : (videoController != null &&
                              videoController.value.isInitialized)
                          ? SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: videoController.value.size.width,
                                  height: videoController.value.size.height,
                                  child: VideoPlayer(videoController),
                                ),
                              ),
                            )
                          : _buildFallback(current),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(MediaItem item) {
    final provider = _imageProvider;
    if (provider == null) return _buildFallback(item);
    return Image(
      image: provider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _buildFallback(item),
    );
  }

  Widget _buildFallback(MediaItem item) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.ondemand_video_outlined,
              size: 72, color: Colors.white30),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Sentinel media_id used to store round counts in media_playback table
const String _kRoundSentinel = '__round__';

// ── Bottom sheet for picking the stat period ──────────────────────────────────

class _StatPeriodSheet extends StatefulWidget {
  const _StatPeriodSheet({
    required this.current,
    required this.customFrom,
    required this.customTo,
    required this.onSelected,
  });

  final _StatPeriod current;
  final DateTime? customFrom;
  final DateTime? customTo;
  final void Function(_StatPeriod, DateTime? from, DateTime? to) onSelected;

  @override
  State<_StatPeriodSheet> createState() => _StatPeriodSheetState();
}

class _StatPeriodSheetState extends State<_StatPeriodSheet> {
  late _StatPeriod _selected;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _from = widget.customFrom;
    _to = widget.customTo;
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    widget.onSelected(_selected, _from, _to);
  }

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final periods = [
      (_StatPeriod.daily, 'Today'),
      (_StatPeriod.weekly, 'This Week'),
      (_StatPeriod.monthly, 'This Month'),
      (_StatPeriod.yearly, 'This Year'),
      (_StatPeriod.custom, 'Custom'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Show stats for',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in periods)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selected = p.$1);
                      widget.onSelected(_selected, _from, _to);
                      if (p.$1 != _StatPeriod.custom) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selected == p.$1
                            ? Colors.white
                            : const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              _selected == p.$1 ? Colors.black : Colors.white70,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_selected == _StatPeriod.custom) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: _from == null ? 'Start date' : _fmt(_from!),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateButton(
                      label: _to == null ? 'End date' : _fmt(_to!),
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              if (_from != null && _to != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
