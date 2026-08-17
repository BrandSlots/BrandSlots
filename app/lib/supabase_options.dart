class SupabaseOptions {
  static const url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://pvjehnhbcyoieklzdzky.supabase.co');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2amVobmhiY3lvaWVrbHpkemt5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3ODAyMTksImV4cCI6MjEwMjM1NjIxOX0.63mOFs3D3BuBh3JVaFrNY5mZrV9HU5NbiP__F-NYy4I');
}
