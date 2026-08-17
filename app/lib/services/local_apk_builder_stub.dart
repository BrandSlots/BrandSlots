import '../models/app_models.dart';
import 'local_apk_builder.dart';

class UnsupportedLocalApkBuilder implements LocalApkBuilder {
  @override
  bool get isSupported => false;

  @override
  Future<ApkBuildResult> buildScreenApk({
    required String projectPath,
    required ScreenDevice screen,
  }) async {
    return const ApkBuildResult(
      success: false,
      message: 'Local APK building is only supported on desktop app runs.',
    );
  }
}

LocalApkBuilder createLocalApkBuilderImpl() => UnsupportedLocalApkBuilder();
