enum AppFlavor { hybrid, admin, screen }

class AppRuntime {
  static const bool useSupabase = bool.fromEnvironment('USE_SUPABASE');
  static const String appFlavorName = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'hybrid',
  );
  static const String screenCode = String.fromEnvironment('SCREEN_CODE');
  static const String screenPassword = String.fromEnvironment(
    'SCREEN_PASSWORD',
  );
  static const String screenTitle = String.fromEnvironment(
    'SCREEN_TITLE',
    defaultValue: 'Screen Player',
  );

  static AppFlavor get appFlavor {
    switch (appFlavorName.toLowerCase()) {
      case 'admin':
        return AppFlavor.admin;
      case 'screen':
        return AppFlavor.screen;
      default:
        return AppFlavor.hybrid;
    }
  }
}
