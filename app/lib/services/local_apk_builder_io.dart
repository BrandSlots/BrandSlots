import 'dart:io';

import '../models/app_models.dart';
import 'local_apk_builder.dart';

class IoLocalApkBuilder implements LocalApkBuilder {
  @override
  bool get isSupported => Platform.isWindows;

  @override
  Future<ApkBuildResult> buildScreenApk({
    required String projectPath,
    required ScreenDevice screen,
  }) async {
    if (!isSupported) {
      return const ApkBuildResult(
        success: false,
        message: 'Local APK building is not supported on this platform.',
      );
    }

    final trimmedPath = projectPath.trim();
    if (trimmedPath.isEmpty) {
      return const ApkBuildResult(
        success: false,
        message: 'Set the local Flutter project path in the Clients section first.',
      );
    }

    final projectDir = Directory(trimmedPath);
    if (!await projectDir.exists()) {
      return ApkBuildResult(
        success: false,
        message: 'Project path not found: $trimmedPath',
      );
    }

    final scriptPath = '${projectDir.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}build_screen_apk.ps1';
    if (!await File(scriptPath).exists()) {
      return ApkBuildResult(
        success: false,
        message: 'Could not find scripts/build_screen_apk.ps1 in $trimmedPath',
      );
    }

    final process = await Process.run(
      'powershell',
      [
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-ScreenCode',
        screen.loginCode,
        '-ScreenPassword',
        screen.password,
        '-ScreenName',
        screen.name,
      ],
      workingDirectory: projectDir.path,
    );

    final stdoutText = (process.stdout ?? '').toString().trim();
    final stderrText = (process.stderr ?? '').toString().trim();
    final combinedLog = [stdoutText, stderrText]
        .where((part) => part.isNotEmpty)
        .join('\n\n');

    final builtApkPath =
        '${projectDir.path}${Platform.pathSeparator}build${Platform.pathSeparator}screen-apks${Platform.pathSeparator}${screen.apkAssetFileName}';

    if (process.exitCode != 0) {
      return ApkBuildResult(
        success: false,
        message: 'APK build failed for ${screen.name}.',
        log: combinedLog,
      );
    }

    return ApkBuildResult(
      success: true,
      message: 'APK built successfully for ${screen.name}.',
      apkPath: builtApkPath,
      log: combinedLog,
    );
  }
}

LocalApkBuilder createLocalApkBuilderImpl() => IoLocalApkBuilder();
