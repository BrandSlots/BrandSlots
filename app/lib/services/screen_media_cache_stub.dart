import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/app_models.dart';
import 'screen_media_cache.dart';

class StubScreenMediaCache implements ScreenMediaCache {
  @override
  Future<void> pruneToAssignedMedia(List<MediaItem> items) async {}

  @override
  Future<PreparedMediaImage> prepareImage(MediaItem item) async {
    return PreparedMediaImage(
      provider: NetworkImage(item.url),
      isCached: false,
    );
  }

  @override
  Future<VideoPlayerController> prepareVideoController(MediaItem item) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(item.url));
    await controller.initialize();
    await controller.setLooping(false);
    return controller;
  }

  @override
  Future<void> syncAssignedMedia(List<MediaItem> items) async {}
}

ScreenMediaCache createScreenMediaCacheImpl() => StubScreenMediaCache();
