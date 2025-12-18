import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nerd_herd/providers/auth_provider.dart' as app_auth;

// Generate Mocks
@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
])
import 'auth_provider_test.mocks.dart';
import 'package:nerd_herd/services/logger_service.dart';
import 'package:logger/logger.dart';

class SilentOutput extends LogOutput {
  @override
  void output(OutputEvent event) {}
}

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    logger.initialize(output: SilentOutput());
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(mockSupabase.auth).thenReturn(mockAuth);
  });

  test('authStateProvider emits user from supabase auth stream', () async {
    // Arrange
    final mockUser = MockUser();
    when(mockUser.id).thenReturn('test-user-id');

    final session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: mockUser,
    );

    final authStateEvent = AuthState(AuthChangeEvent.signedIn, session);

    when(mockAuth.onAuthStateChange).thenAnswer(
      (_) => Stream.value(authStateEvent),
    );

    final container = ProviderContainer(
      overrides: [
        app_auth.supabaseClientProvider.overrideWithValue(mockSupabase),
      ],
    );

    // Act
    final user = await container.read(app_auth.authStateProvider.future);

    // Assert
    expect(user, mockUser);
  });
}
