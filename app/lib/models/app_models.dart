import 'dart:convert';

enum MediaKind { video, image }

class AdminAccount {
  const AdminAccount({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  AdminAccount copyWith({String? name, String? email, String? password}) {
    return AdminAccount(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'email': email, 'password': password};
  }

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    return AdminAccount(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

class OrganizationProfile {
  const OrganizationProfile({
    required this.companyName,
    required this.adminName,
    required this.adminEmail,
    required this.phone,
    required this.welcomeMessage,
    required this.logoUrl,
    required this.accentColorHex,
    required this.apkBaseUrl,
    required this.localProjectPath,
    required this.screenPlayerOrientation,
  });

  final String companyName;
  final String adminName;
  final String adminEmail;
  final String phone;
  final String welcomeMessage;
  final String logoUrl;
  final String accentColorHex;
  final String apkBaseUrl;
  final String localProjectPath;
  final String screenPlayerOrientation;

  factory OrganizationProfile.empty() {
    return const OrganizationProfile(
      companyName: '',
      adminName: '',
      adminEmail: '',
      phone: '',
      welcomeMessage: 'No content has been assigned yet.',
      logoUrl: '',
      accentColorHex: '#0F766E',
      apkBaseUrl: '',
      localProjectPath: '',
      screenPlayerOrientation: 'landscape',
    );
  }

  OrganizationProfile copyWith({
    String? companyName,
    String? adminName,
    String? adminEmail,
    String? phone,
    String? welcomeMessage,
    String? logoUrl,
    String? accentColorHex,
    String? apkBaseUrl,
    String? localProjectPath,
    String? screenPlayerOrientation,
  }) {
    return OrganizationProfile(
      companyName: companyName ?? this.companyName,
      adminName: adminName ?? this.adminName,
      adminEmail: adminEmail ?? this.adminEmail,
      phone: phone ?? this.phone,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      logoUrl: logoUrl ?? this.logoUrl,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      apkBaseUrl: apkBaseUrl ?? this.apkBaseUrl,
      localProjectPath: localProjectPath ?? this.localProjectPath,
      screenPlayerOrientation:
          screenPlayerOrientation ?? this.screenPlayerOrientation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'adminName': adminName,
      'adminEmail': adminEmail,
      'phone': phone,
      'welcomeMessage': welcomeMessage,
      'logoUrl': logoUrl,
      'accentColorHex': accentColorHex,
      'apkBaseUrl': apkBaseUrl,
      'localProjectPath': localProjectPath,
      'screenPlayerOrientation': screenPlayerOrientation,
    };
  }

  factory OrganizationProfile.fromJson(Map<String, dynamic> json) {
    return OrganizationProfile(
      companyName: json['companyName'] as String? ?? '',
      adminName: json['adminName'] as String? ?? '',
      adminEmail: json['adminEmail'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      welcomeMessage: json['welcomeMessage'] as String? ??
          'No content has been assigned yet.',
      logoUrl: json['logoUrl'] as String? ?? '',
      accentColorHex: json['accentColorHex'] as String? ?? '#0F766E',
      apkBaseUrl: json['apkBaseUrl'] as String? ?? '',
      localProjectPath: json['localProjectPath'] as String? ?? '',
      screenPlayerOrientation:
          json['screenPlayerOrientation'] as String? ?? 'landscape',
    );
  }
}

class ClientProfile {
  const ClientProfile({
    required this.id,
    required this.name,
    required this.contactName,
    required this.contactEmail,
    required this.phone,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String contactName;
  final String contactEmail;
  final String phone;
  final String notes;
  final String createdAt;

  ClientProfile copyWith({
    String? id,
    String? name,
    String? contactName,
    String? contactEmail,
    String? phone,
    String? notes,
    String? createdAt,
  }) {
    return ClientProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contactName': contactName,
      'contactEmail': contactEmail,
      'phone': phone,
      'notes': notes,
      'createdAt': createdAt,
    };
  }

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    return ClientProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      contactName: json['contactName'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class ScreenDevice {
  const ScreenDevice({
    required this.id,
    required this.name,
    required this.loginCode,
    required this.password,
    required this.location,
    required this.screenPlayerOrientation,
    required this.assignedMediaIds,
    required this.lastSeenAt,
    required this.playCount,
    required this.lastPlaybackAt,
  });

  final String id;
  final String name;
  final String loginCode;
  final String password;
  final String location;
  final String screenPlayerOrientation;
  final List<String> assignedMediaIds;
  final String? lastSeenAt;
  final int playCount;
  final String? lastPlaybackAt;

  String get apkAssetFileName {
    final normalized = loginCode.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '-',
        );
    final slug = normalized.replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug.isEmpty ? 'screen' : slug}.apk';
  }

  String? apkDownloadUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return null;
    final cleanBase = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return '$cleanBase/$apkAssetFileName';
  }

  ScreenDevice copyWith({
    String? id,
    String? name,
    String? loginCode,
    String? password,
    String? location,
    String? screenPlayerOrientation,
    List<String>? assignedMediaIds,
    String? lastSeenAt,
    int? playCount,
    String? lastPlaybackAt,
  }) {
    return ScreenDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      loginCode: loginCode ?? this.loginCode,
      password: password ?? this.password,
      location: location ?? this.location,
      screenPlayerOrientation:
          screenPlayerOrientation ?? this.screenPlayerOrientation,
      assignedMediaIds: assignedMediaIds ?? this.assignedMediaIds,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      playCount: playCount ?? this.playCount,
      lastPlaybackAt: lastPlaybackAt ?? this.lastPlaybackAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'loginCode': loginCode,
      'password': password,
      'location': location,
      'screenPlayerOrientation': screenPlayerOrientation,
      'assignedMediaIds': assignedMediaIds,
      'lastSeenAt': lastSeenAt,
      'playCount': playCount,
      'lastPlaybackAt': lastPlaybackAt,
    };
  }

  factory ScreenDevice.fromJson(Map<String, dynamic> json) {
    return ScreenDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      loginCode: json['loginCode'] as String? ?? '',
      password: json['password'] as String? ?? '',
      location: json['location'] as String? ?? '',
      screenPlayerOrientation:
          json['screenPlayerOrientation'] as String? ?? 'landscape',
      assignedMediaIds: (json['assignedMediaIds'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      lastSeenAt: json['lastSeenAt'] as String?,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      lastPlaybackAt: json['lastPlaybackAt'] as String?,
    );
  }
}

class MediaItem {
  const MediaItem({
    required this.id,
    required this.clientId,
    required this.title,
    required this.url,
    required this.kind,
    required this.description,
    required this.durationSeconds,
    required this.createdAt,
    this.storagePath,
  });

  final String id;
  final String clientId;
  final String title;
  final String url;
  final MediaKind kind;
  final String description;
  final int durationSeconds;
  final String createdAt;
  final String? storagePath;

  MediaItem copyWith({
    String? id,
    String? clientId,
    String? title,
    String? url,
    MediaKind? kind,
    String? description,
    int? durationSeconds,
    String? createdAt,
    String? storagePath,
  }) {
    return MediaItem(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      url: url ?? this.url,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      storagePath: storagePath ?? this.storagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'title': title,
      'url': url,
      'kind': kind.name,
      'description': description,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt,
      'storagePath': storagePath,
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      kind: (json['kind'] as String? ?? 'video') == 'image'
          ? MediaKind.image
          : MediaKind.video,
      description: json['description'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 15,
      createdAt: json['createdAt'] as String? ?? '',
      storagePath: json['storagePath'] as String?,
    );
  }
}

class MediaPlaybackStat {
  const MediaPlaybackStat({
    required this.id,
    required this.mediaId,
    required this.screenId,
    required this.playCount,
    required this.lastPlayedAt,
    this.playDate,
    this.roundCount = 0,
  });

  final String id;
  final String mediaId;
  final String screenId;
  /// Per-media play count (used for video/image breakdown in reports).
  final int playCount;
  final String? lastPlayedAt;

  /// ISO date string "YYYY-MM-DD" — one record per media+screen+day.
  final String? playDate;

  /// Round count — only populated when mediaId == '__round__'.
  final int roundCount;

  MediaPlaybackStat copyWith({
    String? id,
    String? mediaId,
    String? screenId,
    int? playCount,
    String? lastPlayedAt,
    String? playDate,
    int? roundCount,
  }) {
    return MediaPlaybackStat(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      screenId: screenId ?? this.screenId,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playDate: playDate ?? this.playDate,
      roundCount: roundCount ?? this.roundCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'screenId': screenId,
      'playCount': playCount,
      'lastPlayedAt': lastPlayedAt,
      'playDate': playDate,
      'roundCount': roundCount,
    };
  }

  factory MediaPlaybackStat.fromJson(Map<String, dynamic> json) {
    return MediaPlaybackStat(
      id: json['id'] as String? ?? '',
      mediaId: json['mediaId'] as String? ?? '',
      screenId: json['screenId'] as String? ?? '',
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      lastPlayedAt: json['lastPlayedAt'] as String?,
      playDate: json['playDate'] as String?,
      roundCount: (json['roundCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MediaPerformanceSummary {
  const MediaPerformanceSummary({
    required this.media,
    required this.playCount,
    required this.playTimeSeconds,
    required this.screenCount,
    required this.lastPlayedAt,
  });

  final MediaItem media;
  final int playCount;
  final int playTimeSeconds;
  final int screenCount;
  final String? lastPlayedAt;
}

class AppData {
  const AppData({
    required this.admin,
    required this.organization,
    required this.clients,
    required this.screens,
    required this.mediaItems,
    required this.playbackStats,
  });

  final AdminAccount? admin;
  final OrganizationProfile organization;
  final List<ClientProfile> clients;
  final List<ScreenDevice> screens;
  final List<MediaItem> mediaItems;
  final List<MediaPlaybackStat> playbackStats;

  factory AppData.empty() {
    return AppData(
      admin: null,
      organization: OrganizationProfile.empty(),
      clients: const [],
      screens: const [],
      mediaItems: const [],
      playbackStats: const [],
    );
  }

  AppData copyWith({
    AdminAccount? admin,
    bool clearAdmin = false,
    OrganizationProfile? organization,
    List<ClientProfile>? clients,
    List<ScreenDevice>? screens,
    List<MediaItem>? mediaItems,
    List<MediaPlaybackStat>? playbackStats,
  }) {
    return AppData(
      admin: clearAdmin ? null : (admin ?? this.admin),
      organization: organization ?? this.organization,
      clients: clients ?? this.clients,
      screens: screens ?? this.screens,
      mediaItems: mediaItems ?? this.mediaItems,
      playbackStats: playbackStats ?? this.playbackStats,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin': admin?.toJson(),
      'organization': organization.toJson(),
      'clients': clients.map((item) => item.toJson()).toList(),
      'screens': screens.map((item) => item.toJson()).toList(),
      'mediaItems': mediaItems.map((item) => item.toJson()).toList(),
      'playbackStats': playbackStats.map((item) => item.toJson()).toList(),
    };
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      admin: json['admin'] == null
          ? null
          : AdminAccount.fromJson(json['admin'] as Map<String, dynamic>),
      organization: OrganizationProfile.fromJson(
        json['organization'] as Map<String, dynamic>? ?? const {},
      ),
      clients: (json['clients'] as List<dynamic>? ?? const [])
          .map((item) => ClientProfile.fromJson(item as Map<String, dynamic>))
          .toList(),
      screens: (json['screens'] as List<dynamic>? ?? const [])
          .map((item) => ScreenDevice.fromJson(item as Map<String, dynamic>))
          .toList(),
      mediaItems: (json['mediaItems'] as List<dynamic>? ?? const [])
          .map((item) => MediaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      playbackStats: (json['playbackStats'] as List<dynamic>? ?? const [])
          .map(
            (item) => MediaPlaybackStat.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory AppData.decode(String raw) {
    return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
