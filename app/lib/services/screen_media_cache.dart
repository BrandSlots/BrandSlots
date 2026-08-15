import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/app_models.dart';
import 'screen_media_cache_stub.dart'
    if (dart.library.io) 'screen_media_cache_io.dart';

abstract class ScreenMediaCache {
  Future<void> syncAssignedMedia(List<MediaItem> items);
  Future<void> pruneToAssignedMedia(List<MediaItem> items);
  Future<PreparedMediaImage> prepareImage(MediaItem item);
  Future<VideoPlayerController> prepareVideoController(MediaItem item);
}

class PreparedMediaImage {
  const PreparedMediaImage({
    required this.provider,
    required this.isCached,
  });

  final ImageProvider<Object> provider;
  final bool isCached;
}

ScreenMediaCache createScreenMediaCache() => createScreenMediaCacheImpl();
