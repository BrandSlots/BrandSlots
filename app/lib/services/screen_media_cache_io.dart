import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/app_models.dart';
import 'screen_media_cache.dart';

class IoScreenMediaCache implements ScreenMediaCache {
  Directory? _cacheDir;
  final Map<String, Future<void>> _downloads = {};

  Future<Directory> _directory() async {
    final existing = _cacheDir;
    if (existing != null) return existing;
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}screen_media');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  @override
  Future<void> syncAssignedMedia(List<MediaItem> items) async {
    for (final item in items) {
      _queueDownload(item);
    }
  }

  @override
  Future<void> pruneToAssignedMedia(List<MediaItem> items) async {
    final dir = await _directory();
    final keep = <String>{};
    for (final item in items) {
      keep.add(await _cachedFilePath(item));
    }

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!keep.contains(entity.path)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<PreparedMediaImage> prepareImage(MediaItem item) async {
    final file = await _waitForCachedFile(
      item,
      timeout: const Duration(seconds: 2),
    );
    if (file != null) {
      return PreparedMediaImage(
        provider: FileImage(file),
        isCached: true,
      );
    }

    unawaited(_queueDownload(item));
    return PreparedMediaImage(
      provider: NetworkImage(item.url),
      isCached: false,
    );
  }

  @override
  Future<VideoPlayerController> prepareVideoController(MediaItem item) async {
    final file = await _waitForCachedFile(
      item,
      timeout: const Duration(seconds: 3),
    );
    final controller = file != null
        ? VideoPlayerController.file(file)
        : VideoPlayerController.networkUrl(Uri.parse(item.url));
    await controller.initialize();
    await controller.setLooping(false);
    if (file == null) {
      unawaited(_queueDownload(item));
    }
    return controller;
  }

  Future<void> _queueDownload(MediaItem item) {
    final existing = _downloads[item.id];
    if (existing != null) {
      return existing;
    }

    final future = _downloadIfNeeded(item).whenComplete(() {
      _downloads.remove(item.id);
    });
    _downloads[item.id] = future;
    return future;
  }

  Future<File?> _cachedFile(MediaItem item) async {
    final path = await _cachedFilePath(item);
    final file = File(path);
    return await file.exists() ? file : null;
  }

  Future<File?> _waitForCachedFile(
    MediaItem item, {
    required Duration timeout,
  }) async {
    final cached = await _cachedFile(item);
    if (cached != null) {
      return cached;
    }

    try {
      await _queueDownload(item).timeout(timeout);
    } catch (_) {}

    return _cachedFile(item);
  }

  Future<String> _cachedFilePath(MediaItem item) async {
    final dir = await _directory();
    final extension = _extensionFor(item);
    return '${dir.path}${Platform.pathSeparator}${_fileKey(item)}$extension';
  }

  String _fileKey(MediaItem item) {
    final raw = '${item.id}|${item.url}|${item.kind.name}';
    final bytes = utf8.encode(raw);
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }

  String _extensionFor(MediaItem item) {
    final uri = Uri.tryParse(item.url);
    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.isNotEmpty && segments.last.contains('.')) {
      final dot = segments.last.lastIndexOf('.');
      final ext = segments.last.substring(dot);
      if (ext.isNotEmpty && ext.length <= 8) return ext;
    }
    return item.kind == MediaKind.video ? '.mp4' : '.jpg';
  }

  Future<void> _downloadIfNeeded(MediaItem item) async {
    final path = await _cachedFilePath(item);
    final file = File(path);
    if (await file.exists()) return;

    final tmp = File('$path.part');
    HttpClient? client;
    IOSink? sink;
    try {
      client = HttpClient();
      final request = await client.getUrl(Uri.parse(item.url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
      if (!await tmp.parent.exists()) {
        await tmp.parent.create(recursive: true);
      }
      sink = tmp.openWrite();
      await response.forEach(sink.add);
      await sink.flush();
      await sink.close();
      sink = null;
      await tmp.rename(path);
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    } finally {
      client?.close(force: true);
    }
  }
}

ScreenMediaCache createScreenMediaCacheImpl() => IoScreenMediaCache();
