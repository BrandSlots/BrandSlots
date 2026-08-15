import 'dart:typed_data';

import '../models/app_models.dart';

abstract class AppRepository {
  bool get isCloudBacked;
  String get backendLabel;

  Future<void> initialize();
  Future<AppData> loadInitialData();
  Stream<AppData> watchAppData();
  Future<void> createAdmin({
    required String name,
    required String email,
    required String password,
    required String companyName,
  });
  Future<bool> loginAdmin(String email, String password);
  Future<bool> loginScreen(String loginCode, String password);
  Future<void> logout();
  Future<void> updateOrganization(OrganizationProfile profile);
  Future<void> addClient({
    required String name,
    required String contactName,
    required String contactEmail,
    required String phone,
    required String notes,
  });
  Future<void> updateClient(ClientProfile client);
  Future<void> deleteClient(String clientId);
  Future<String?> addScreen({
    required String name,
    required String loginCode,
    required String password,
    required String location,
    required String screenPlayerOrientation,
  });
  Future<void> updateScreen(ScreenDevice screen);
  Future<void> addMedia({
    required String clientId,
    required String title,
    required MediaKind kind,
    required String description,
    required int durationSeconds,
    String? externalUrl,
    Uint8List? fileBytes,
    String? fileName,
  });
  Future<void> deleteMedia(String mediaId);
  Future<void> updateMediaDuration(
      {required String mediaId, required int durationSeconds});
  Future<void> reportScreenPlayback({
    required String screenId,
    required String mediaId,
    required bool completedRound,
  });
  Future<void> resetContentData();
}
