import "package:mocktail/mocktail.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseService get instance => _instance;

  // These cannot be static for testing
  // May also not need to be static at all.
  // static late final SupabaseClient _supabaseClient;
  // static SupabaseClient get supabaseClient => _supabaseClient;

  late SupabaseClient _supabaseClient;
  SupabaseClient get supabaseClient => _supabaseClient;
  init(
      {required String supabaseUrl,
      required String anonKey,
      bool mock = false}) async {
    if (mock) {
      _supabaseClient = FakeSupabase();
      return;
    }

    await Supabase.initialize(
        url: supabaseUrl, anonKey: anonKey, authCallbackUrlHostname: "login");
    _supabaseClient = Supabase.instance.client;
  }

  SupabaseService._internal();
}

// NOTE: This will need some tweaking when actually testing supabase.
class FakeSupabase extends Fake implements SupabaseClient {
  @override
  get auth => FakeGoTrue();
}

class FakeGoTrue extends Fake implements GoTrueClient {
  final _user = User(
    id: "id",
    appMetadata: {},
    userMetadata: {},
    aud: "aud",
    createdAt: DateTime.now().toIso8601String(),
  );
  @override
  Future<AuthResponse> signInWithPassword(
      {String? email,
      String? phone,
      required String password,
      String? captchaToken}) async {
    return AuthResponse(session: null, user: _user);
  }

  @override
  Session? get currentSession => null;
}
