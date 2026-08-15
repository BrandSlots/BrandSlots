import 'dart:async';
import 'dart:typed_data';

import '../models/app_models.dart';
import 'app_repository.dart';
import 'app_store.dart';

class LocalAppRepository implements AppRepository {
  LocalAppRepository(this._store);

  final AppStore _store;
  final StreamController<AppData> _controller =
      StreamController<AppData>.broadcast();
  AppData _data = AppData.empty();

  @override
  bool get isCloudBacked => false;

  @override
  String get backendLabel => 'Local demo storage';

  @override
  Future<void> initialize() async {
    _data = await _store.load();
    _controller.add(_data);
  }

  @override
  Future<AppData> loadInitialData() async {
    _data = await _store.load();
    return _data;
  }

  @override
  Stream<AppData> watchAppData() => _controller.stream;

  @override
  Future<void> createAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
  }) async {
    final admin = AdminAccount(name: name, email: email, password: password);
    final organization = _data.organization.copyWith(
      companyName: companyName,
      adminName: name,
      adminEmail: email,
      screenPlayerOrientation: 'landscape',
    );
    _data = _data.copyWith(admin: admin, organization: organization);
    await _persist();
  }

  @override
  Future<bool> loginAdmin(String email, String password) async {
    final existing = _data.admin;
    if (existing == null) return false;
    final loginValue = email.trim().toLowerCase();
    final storedEmail = existing.email.trim().toLowerCase();
    final storedName = _data.organization.adminName.trim().toLowerCase();

    return (storedEmail == loginValue || storedName == loginValue) &&
        existing.password.trim() == password.trim();
  }

  @override
  Future<bool> loginScreen(String loginCode, String password) async {
    final match = _data.screens.where((screen) {
      return screen.loginCode.trim().toLowerCase() ==
              loginCode.trim().toLowerCase() &&
          screen.password == password;
    }).toList();
    if (match.isEmpty) return false;
    final screen = match.first.copyWith(
      lastSeenAt: DateTime.now().toIso8601String(),
    );
    _data = _data.copyWith(
      screens: _data.screens
          .map((item) => item.id == screen.id ? screen : item)
          .toList(),
    );
    await _persist();
    return true;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> updateOrganization(OrganizationProfile profile) async {
    _data = _data.copyWith(organization: profile);
    final admin = _data.admin;
    if (admin != null) {
      _data = _data.copyWith(
        admin: admin.copyWith(
          name: profile.adminName,
          email: profile.adminEmail,
        ),
      );
    }
    await _persist();
  }

  @override
  Future<void> addClient({
    required String name,
    required String contactName,
    required String contactEmail,
    required String phone,
    required String notes,
  }) async {
    _data = _data.copyWith(
      clients: [
        ..._data.clients,
        ClientProfile(
          id: _id(),
          name: name.trim(),
          contactName: contactName.trim(),
          contactEmail: contactEmail.trim(),
          phone: phone.trim(),
          notes: notes.trim(),
          createdAt: DateTime.now().toIso8601String(),
        ),
      ],
    );
    await _persist();
  }

  @override
  Future<void> updateClient(ClientProfile client) async {
    _data = _data.copyWith(
      clients: _data.clients
          .map((item) => item.id == client.id ? client : item)
          .toList(),
    );
    await _persist();
  }

  @override
  Future<void> deleteClient(String clientId) async {
    final mediaIds = _data.mediaItems
        .where((item) => item.clientId == clientId)
        .map((item) => item.id)
        .toSet();
    _data = _data.copyWith(
      clients: _data.clients.where((item) => item.id != clientId).toList(),
      mediaItems:
          _data.mediaItems.where((item) => item.clientId != clientId).toList(),
      playbackStats: _data.playbackStats
          .where((item) => !mediaIds.contains(item.mediaId))
          .toList(),
      screens: _data.screens
          .map(
            (screen) => screen.copyWith(
              assignedMediaIds: screen.assignedMediaIds
                  .where((id) => !mediaIds.contains(id))
                  .toList(),
            ),
          )
          .toList(),
    );
    await _persist();
  }

  @override
  Future<String?> addScreen({
    required String name,
    required String loginCode,
    required String password,
    required String location,
    required String screenPlayerOrientation,
  }) async {
    final exists = _data.screens.any(
      (screen) =>
          screen.loginCode.trim().toLowerCase() ==
          loginCode.trim().toLowerCase(),
    );
    if (exists) {
      return 'Login code already exists.';
    }

    _data = _data.copyWith(
      screens: [
        ..._data.screens,
        ScreenDevice(
          id: _id(),
          name: name.trim(),
          loginCode: loginCode.trim(),
          password: password,
          location: location.trim(),
          screenPlayerOrientation: screenPlayerOrientation,
          assignedMediaIds: const [],
          lastSeenAt: null,
          playCount: 0,
          lastPlaybackAt: null,
        ),
      ],
    );
    await _persist();
    return null;
  }

  @override
  Future<void> updateScreen(ScreenDevice screen) async {
    _data = _data.copyWith(
      screens: _data.screens
          .map((item) => item.id == screen.id ? screen : item)
          .toList(),
    );
    await _persist();
  }

  @override
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
    final media = MediaItem(
      id: _id(),
      clientId: clientId,
      title: title.trim(),
      url: (externalUrl ?? '').trim(),
      kind: kind,
      description: description.trim(),
      durationSeconds: durationSeconds,
      createdAt: DateTime.now().toIso8601String(),
      storagePath: null,
    );

    _data = _data.copyWith(mediaItems: [..._data.mediaItems, media]);
    await _persist();
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    _data = _data.copyWith(
      mediaItems: _data.mediaItems.where((item) => item.id != mediaId).toList(),
      playbackStats:
          _data.playbackStats.where((item) => item.mediaId != mediaId).toList(),
      screens: _data.screens
          .map(
            (screen) => screen.copyWith(
              assignedMediaIds: screen.assignedMediaIds
                  .where((item) => item != mediaId)
                  .toList(),
            ),
          )
          .toList(),
    );
    await _persist();
  }

  @override
  Future<void> updateMediaDuration(
      {required String mediaId, required int durationSeconds}) async {
    _data = _data.copyWith(
      mediaItems: _data.mediaItems
          .map((item) => item.id == mediaId
              ? item.copyWith(durationSeconds: durationSeconds)
              : item)
          .toList(),
    );
    await _persist();
  }

  @override
  Future<void> reportScreenPlayback({
    required String screenId,
    required String mediaId,
    required bool completedRound,
  }) async {
    if (!completedRound) return;

    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final screens = _data.screens.map((screen) {
      if (screen.id != screenId) return screen;
      return screen.copyWith(
        playCount: screen.playCount + 1,
        lastPlaybackAt: nowStr,
      );
    }).toList();

    const sentinel = '__round__';
    final statIndex = _data.playbackStats.indexWhere(
      (item) =>
          item.mediaId == sentinel &&
          item.screenId == screenId &&
          item.playDate == today,
    );
    final playbackStats = [..._data.playbackStats];
    if (statIndex == -1) {
      playbackStats.add(
        MediaPlaybackStat(
          id: _id(),
          mediaId: sentinel,
          screenId: screenId,
          playCount: 0,
          lastPlayedAt: nowStr,
          playDate: today,
          roundCount: 1,
        ),
      );
    } else {
      final current = playbackStats[statIndex];
      playbackStats[statIndex] = current.copyWith(
        roundCount: current.roundCount + 1,
        lastPlayedAt: nowStr,
      );
    }

    _data = _data.copyWith(screens: screens, playbackStats: playbackStats);
    await _persist();
  }

  @override
  Future<void> resetContentData() async {
    _data = _data.copyWith(
      clients: const [],
      mediaItems: const [],
      playbackStats: const [],
      screens: _data.screens
          .map(
            (screen) => screen.copyWith(
              assignedMediaIds: const [],
              playCount: 0,
              lastPlaybackAt: null,
            ),
          )
          .toList(),
    );
    await _persist();
  }

  Future<void> _persist() async {
    await _store.save(_data);
    _controller.add(_data);
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}
