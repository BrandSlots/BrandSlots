import 'app_repository.dart';
import 'app_store.dart';
import 'local_app_repository.dart';
import 'supabase_app_repository.dart';

class RepositoryFactory {
  static AppRepository create() {
    const useSupabase = bool.fromEnvironment('USE_SUPABASE');
    if (useSupabase) return SupabaseAppRepository();
    return LocalAppRepository(AppStore());
  }

  static AppRepository createSupabase() => SupabaseAppRepository();
}
