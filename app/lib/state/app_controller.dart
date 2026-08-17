import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import '../services/app_repository.dart';

enum SessionMode { none, admin, screen }

class AppController extends ChangeNotifier {
  AppController(this._repository);

  final AppRepository _repository;

  AppData _data = AppData.empty();
  bool _isReady = false;
  SessionMode _sessionMode = SessionMode.none;
  String? _activeScreenId;
  String? _errorMessage;
  StreamSubscription<AppData>? _dataSubscription;

  AppData get data => _data;
  bool get isReady => _isReady;
  String? get errorMessage => _errorMessage;
  bool get hasAdmin => _data.admin != null;
  bool get isCloudBacked => _repository.isCloudBacked;
  String get backendLabel => _repository.backendLabel;
  SessionMode get sessionMode => _sessionMode;
  OrganizationProfile get organization => _data.organization;
  AdminAccount? get admin => _data.admin;
  List<ClientProfile> get clients => _data.clients;
  List<ScreenDevice> get screens => _data.screens;
  List<MediaItem> get mediaItems => _data.mediaItems;
  List<MediaPlaybackStat> get playbackStats => _data.playbackStats;
  ScreenDevice? get activeScreen =>
      _activeScreenId == null ? null : getScreenById(_activeScreenId!);

  static const _sessionKey = 'ad_master_session_mode';

  Future<void> initialize() async {
    try {
      _errorMessage = null;
      await _repository.initialize();
      _data = await _repository.loadInitialData();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_sessionKey);
      if (saved == SessionMode.admin.name) {
        _sessionMode = SessionMode.admin;
      }
      await _dataSubscription?.cancel();
      _dataSubscription = _repository.watchAppData().listen((data) {
        final previous = _data;
        _data = data;
        if (_shouldNotifyForIncomingData(previous, data)) {
          notifyListeners();
        }
      });
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> createAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
  }) async {
    _errorMessage = null;
    await _repository.createAdmin(
      name: name,
      email: email,
      password: password,
      companyName: companyName,
    );
    _data = await _repository.loadInitialData();
    _sessionMode = SessionMode.admin;
    notifyListeners();
  }

  Future<bool> loginAdmin(String email, String password) async {
    _errorMessage = null;
    final success = await _repository.loginAdmin(email, password);
    if (!success) return false;
    _data = await _repository.loadInitialData();
    _sessionMode = SessionMode.admin;
    _activeScreenId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, SessionMode.admin.name);
    notifyListeners();
    return success;
  }

  Future<bool> loginScreen(String loginCode, String password) async {
    final success = await _repository.loginScreen(loginCode, password);
    if (!success) return false;
    _data = await _repository.loadInitialData();
    final screen = _data.screens.firstWhere(
      (item) =>
          item.loginCode.trim().toLowerCase() == loginCode.trim().toLowerCase(),
      orElse: () => const ScreenDevice(
        id: '',
        name: '',
        loginCode: '',
        password: '',
        location: '',
        screenPlayerOrientation: 'landscape',
        assignedMediaIds: [],
        lastSeenAt: null,
        playCount: 0,
        lastPlaybackAt: null,
      ),
    );
    _sessionMode = SessionMode.screen;
    _activeScreenId = screen.id.isEmpty ? null : screen.id;
    notifyListeners();
    return success;
  }

  Future<void> logout() async {
    // If a screen is logging out, clear its lastPlaybackAt
    if (_sessionMode == SessionMode.screen && _activeScreenId != null) {
      final screen = getScreenById(_activeScreenId!);
      if (screen != null) {
        await _repository.updateScreen(screen.copyWith(lastPlaybackAt: ''));
      }
    }
    await _repository.logout();
    _sessionMode = SessionMode.none;
    _activeScreenId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> updateOrganization(OrganizationProfile profile) async {
    await _repository.updateOrganization(profile);
    _data = _data.copyWith(organization: profile);
    notifyListeners();
  }

  Future<void> addClient({
    required String name,
    required String contactName,
    required String contactEmail,
    required String phone,
    required String notes,
  }) async {
    await _repository.addClient(
      name: name,
      contactName: contactName,
      contactEmail: contactEmail,
      phone: phone,
      notes: notes,
    );
  }

  Future<void> updateClient(ClientProfile client) async {
    await _repository.updateClient(client);
  }

  Future<void> deleteClient(String clientId) async {
    await _repository.deleteClient(clientId);
  }

  Future<String?> addScreen({
    required String name,
    required String loginCode,
    required String password,
    required String location,
    required String screenPlayerOrientation,
  }) async {
    return _repository.addScreen(
      name: name,
      loginCode: loginCode,
      password: password,
      location: location,
      screenPlayerOrientation: screenPlayerOrientation,
    );
  }

  Future<void> updateScreen(ScreenDevice updated) async {
    await _repository.updateScreen(updated);
  }

  Future<void> assignMediaToScreen(ScreenDevice screen, String mediaId) async {
    if (screen.assignedMediaIds.contains(mediaId)) return;
    await _repository.recordMediaAssigned(
      screenId: screen.id,
      mediaId: mediaId,
      atRound: screen.playCount,
    );
    await _repository.updateScreen(
      screen.copyWith(assignedMediaIds: [...screen.assignedMediaIds, mediaId]),
    );
  }

  Future<void> removeMediaFromScreen(ScreenDevice screen, String mediaId) async {
    await _repository.recordMediaRemoved(
      screenId: screen.id,
      mediaId: mediaId,
      atRound: screen.playCount,
    );
    await _repository.updateScreen(
      screen.copyWith(
        assignedMediaIds: screen.assignedMediaIds.where((id) => id != mediaId).toList(),
      ),
    );
  }

  Future<void> addMedia({
    required String clientId,
    required String title,
    required MediaKind kind,
    required String description,
    required int durationSeconds,
    String? externalUrl,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    await _repository.addMedia(
      clientId: clientId,
      title: title,
      kind: kind,
      description: description,
      durationSeconds: durationSeconds,
      externalUrl: externalUrl,
      fileBytes: fileBytes,
      fileName: fileName,
    );
  }

  Future<void> updateMediaDuration(
      {required String mediaId, required int durationSeconds}) async {
    await _repository.updateMediaDuration(
        mediaId: mediaId, durationSeconds: durationSeconds);
  }

  Future<void> deleteMedia(String mediaId) async {
    await _repository.deleteMedia(mediaId);
  }

  Future<void> reportScreenPlayback({
    required String screenId,
    required String mediaId,
    required bool completedRound,
  }) async {
    await _repository.reportScreenPlayback(
      screenId: screenId,
      mediaId: mediaId,
      completedRound: completedRound,
    );
    notifyListeners();
  }

  Future<void> resetContentData() async {
    await _repository.resetContentData();
    _data = await _repository.loadInitialData();
    if (_sessionMode == SessionMode.screen && _activeScreenId != null) {
      final screenStillExists = getScreenById(_activeScreenId!) != null;
      if (!screenStillExists) {
        _activeScreenId = null;
        _sessionMode = SessionMode.none;
      }
    }
    notifyListeners();
  }

  ScreenDevice? getScreenById(String id) {
    for (final screen in _data.screens) {
      if (screen.id == id) return screen;
    }
    return null;
  }

  List<MediaItem> mediaForScreen(String screenId) {
    final screen = getScreenById(screenId);
    if (screen == null) return const [];
    return _data.mediaItems
        .where((item) => screen.assignedMediaIds.contains(item.id))
        .toList()
      ..sort(
        (left, right) => screen.assignedMediaIds
            .indexOf(left.id)
            .compareTo(screen.assignedMediaIds.indexOf(right.id)),
      );
  }

  List<MediaItem> mediaForClient(String clientId) {
    return _data.mediaItems.where((item) => item.clientId == clientId).toList();
  }

  ClientProfile? getClientById(String clientId) {
    for (final client in _data.clients) {
      if (client.id == clientId) return client;
    }
    return null;
  }

  int playsForScreen(String screenId, {DateTime? from, DateTime? to}) {
    var total = 0;
    for (final stat in _data.playbackStats) {
      if (stat.screenId != screenId) continue;
      if (stat.mediaId != '__round__') continue;
      if (!_matchesDateRange(stat, from: from, to: to)) continue;
      total += stat.roundCount;
    }
    return total;
  }

  int totalPlaysForMedia(String mediaId, {DateTime? from, DateTime? to}) {
    // Sum rounds across all assignment windows for this media
    var total = 0;
    for (final screen in _data.screens) {
      final screenAssignments = _data.assignments
          .where((a) => a.screenId == screen.id && a.mediaId == mediaId)
          .toList();
      final currentRounds = screen.playCount;
      for (final a in screenAssignments) {
        final end = a.removedAtRound ?? currentRounds;
        total += (end - a.assignedAtRound).clamp(0, 999999);
      }
      // Fallback: if no assignment record but media is currently assigned
      if (screenAssignments.isEmpty && screen.assignedMediaIds.contains(mediaId)) {
        total += currentRounds;
      }
    }
    return total;
  }

  int totalPlayTimeForMedia(String mediaId, {DateTime? from, DateTime? to}) {
    final media = _data.mediaItems.where((item) => item.id == mediaId).toList();
    if (media.isEmpty) return 0;
    return totalPlaysForMedia(mediaId, from: from, to: to) *
        media.first.durationSeconds;
  }

  MediaPerformanceSummary mediaSummaryForMedia(
    MediaItem media, {
    DateTime? from,
    DateTime? to,
  }) {
    return MediaPerformanceSummary(
      media: media,
      playCount: totalPlaysForMedia(media.id, from: from, to: to),
      playTimeSeconds: totalPlayTimeForMedia(media.id, from: from, to: to),
      screenCount: _data.screens
          .where((screen) => screen.assignedMediaIds.contains(media.id))
          .length,
      lastPlayedAt: _lastPlayedAtForMedia(media.id),
    );
  }

  List<MediaPerformanceSummary> mediaSummariesForClient(
    String clientId, {
    DateTime? from,
    DateTime? to,
  }) {
    return mediaForClient(clientId)
        .map((media) => mediaSummaryForMedia(media, from: from, to: to))
        .toList()
      ..sort((left, right) {
        final byPlays = right.playCount.compareTo(left.playCount);
        if (byPlays != 0) return byPlays;
        return left.media.title
            .toLowerCase()
            .compareTo(right.media.title.toLowerCase());
      });
  }

  List<MediaPerformanceSummary> mediaSummariesForScreen(
    String screenId, {
    DateTime? from,
    DateTime? to,
  }) {
    return mediaForScreen(screenId)
        .map((media) => mediaSummaryForMedia(media, from: from, to: to))
        .toList()
      ..sort((left, right) {
        final byPlays = right.playCount.compareTo(left.playCount);
        if (byPlays != 0) return byPlays;
        return left.media.title
            .toLowerCase()
            .compareTo(right.media.title.toLowerCase());
      });
  }

  List<MediaPlaybackStat> playbackForMedia(String mediaId,
      {DateTime? from, DateTime? to}) {
    return _data.playbackStats.where((item) {
      return item.mediaId == mediaId &&
          _matchesDateRange(item, from: from, to: to);
    }).toList();
  }

  String? _lastPlayedAtForMedia(String mediaId) {
    DateTime? latest;
    String? latestRaw;
    for (final stat in _data.playbackStats) {
      if (stat.mediaId != mediaId) continue;
      final raw = stat.lastPlayedAt;
      if (raw == null || raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
        latestRaw = raw;
      }
    }
    return latestRaw;
  }

  List<MediaPlaybackStat> playbackForScreen(String screenId,
      {DateTime? from, DateTime? to}) {
    return _data.playbackStats.where((item) {
      return item.screenId == screenId &&
          _matchesDateRange(item, from: from, to: to);
    }).toList();
  }

  String? apkDownloadUrlForScreen(ScreenDevice screen) {
    return screen.apkDownloadUrl(_data.organization.apkBaseUrl);
  }

  bool _shouldNotifyForIncomingData(AppData previous, AppData next) {
    if (_sessionMode != SessionMode.screen) {
      return true;
    }

    final activeScreenId = _activeScreenId;
    if (activeScreenId == null) {
      return true;
    }

    final previousScreen = _findScreen(previous.screens, activeScreenId);
    final nextScreen = _findScreen(next.screens, activeScreenId);
    if (previousScreen == null || nextScreen == null) {
      return true;
    }

    if (previousScreen.name != nextScreen.name ||
        previousScreen.loginCode != nextScreen.loginCode ||
        previousScreen.password != nextScreen.password ||
        previousScreen.location != nextScreen.location ||
        previousScreen.playCount != nextScreen.playCount ||
        !_sameStringLists(
          previousScreen.assignedMediaIds,
          nextScreen.assignedMediaIds,
        )) {
      return true;
    }

    if (!_samePlaybackStatsForScreen(previous, next, activeScreenId)) {
      return true;
    }

    final previousMedia = _mediaForScreenFromData(previous, activeScreenId);
    final nextMedia = _mediaForScreenFromData(next, activeScreenId);
    if (previousMedia.length != nextMedia.length) {
      return true;
    }

    for (var i = 0; i < previousMedia.length; i++) {
      if (!_sameMediaItem(previousMedia[i], nextMedia[i])) {
        return true;
      }
    }

    return false;
  }

  ScreenDevice? _findScreen(List<ScreenDevice> screens, String id) {
    for (final screen in screens) {
      if (screen.id == id) return screen;
    }
    return null;
  }

  List<MediaItem> _mediaForScreenFromData(AppData data, String screenId) {
    final screen = _findScreen(data.screens, screenId);
    if (screen == null) return const [];
    return data.mediaItems
        .where((item) => screen.assignedMediaIds.contains(item.id))
        .toList();
  }

  List<MediaPlaybackStat> _playbackForScreenFromData(
      AppData data, String screenId) {
    final items =
        data.playbackStats.where((item) => item.screenId == screenId).toList();
    items.sort((left, right) {
      final byMedia = left.mediaId.compareTo(right.mediaId);
      if (byMedia != 0) return byMedia;
      final leftDate = left.playDate ?? '';
      final rightDate = right.playDate ?? '';
      final byDate = leftDate.compareTo(rightDate);
      if (byDate != 0) return byDate;
      return left.id.compareTo(right.id);
    });
    return items;
  }

  bool _samePlaybackStatsForScreen(
      AppData previous, AppData next, String screenId) {
    final left = _playbackForScreenFromData(previous, screenId);
    final right = _playbackForScreenFromData(next, screenId);
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_samePlaybackStat(left[i], right[i])) return false;
    }
    return true;
  }

  bool _sameStringLists(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  bool _sameMediaItem(MediaItem left, MediaItem right) {
    return left.id == right.id &&
        left.clientId == right.clientId &&
        left.title == right.title &&
        left.url == right.url &&
        left.kind == right.kind &&
        left.description == right.description &&
        left.durationSeconds == right.durationSeconds &&
        left.createdAt == right.createdAt &&
        left.storagePath == right.storagePath;
  }

  bool _samePlaybackStat(MediaPlaybackStat left, MediaPlaybackStat right) {
    return left.id == right.id &&
        left.mediaId == right.mediaId &&
        left.screenId == right.screenId &&
        left.playCount == right.playCount &&
        left.lastPlayedAt == right.lastPlayedAt &&
        left.playDate == right.playDate &&
        left.roundCount == right.roundCount;
  }

  bool _matchesDateRange(
    MediaPlaybackStat stat, {
    DateTime? from,
    DateTime? to,
  }) {
    if (from == null && to == null) return true;

    final rawDate = stat.playDate?.trim().isNotEmpty == true
        ? stat.playDate
        : stat.lastPlayedAt;
    if (rawDate == null || rawDate.isEmpty) return false;

    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return false;

    // Always compare in IST (UTC+5:30)
    final ist = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
    final dateOnly = DateTime(ist.year, ist.month, ist.day);
    if (from != null) {
      final start = DateTime(from.year, from.month, from.day);
      if (dateOnly.isBefore(start)) return false;
    }
    if (to != null) {
      final end = DateTime(to.year, to.month, to.day);
      if (dateOnly.isAfter(end)) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }
}
