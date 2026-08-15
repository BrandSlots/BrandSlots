import '../models/app_models.dart';
import 'local_apk_builder_stub.dart'
    if (dart.library.io) 'local_apk_builder_io.dart';

class ApkBuildResult {
  const ApkBuildResult({
    required this.success,
    required this.message,
    this.apkPath,
    this.log,
  });

  final bool success;
  final String message;
  final String? apkPath;
  final String? log;
}

abstract class LocalApkBuilder {
  bool get isSupported;

  Future<ApkBuildResult> buildScreenApk({
    required String projectPath,
    required ScreenDevice screen,
  });
}

LocalApkBuilder createLocalApkBuilder() => createLocalApkBuilderImpl();
