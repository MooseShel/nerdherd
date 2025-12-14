import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nerd_herd/providers/auth_provider.dart';
import 'package:nerd_herd/providers/supabase_provider.dart';

// Generate Mocks
@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
])
import 'auth_provider_test.mocks.dart';

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(mockSupabase.auth).thenReturn(mockAuth);
  });

  test('authStateProvider emits user from supabase auth stream', () async {
    // Arrange
    final mockUser = MockUser();
    when(mockUser.id).thenReturn('test-user-id');

    // Simulate auth state change
    // We need to construct a valid AuthState or mock the stream
    // Since AuthState is a concrete class, we can try to instantiate it or simple mock the stream return
    // But onAuthStateChange returns Stream<AuthState>.
    // Let's mock the stream.

    // NOTE: AuthState constructor might be const or require params.
    // Ideally we stream data.
    // For simplicity in this first pass, we mock the stream to return a session with user.

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
        supabaseProvider.overrideWithValue(mockSupabase),
      ],
    );

    // Act
    final userStream = container.read(authStateProvider.stream);

    // Assert
    expect(userStream, emits(mockUser));
  });

  test('currentUserId returns id when user is present', () async {
    final mockUser = MockUser();
    when(mockUser.id).thenReturn('123');

    // Mock the authStateProvider to return a value immediately
    // Or simpler: verify currentUserId depends on authState

    final container = ProviderContainer(overrides: [
      // We can override the authStateProvider directly if we want to test currentUserId in isolation
      authStateProvider.overrideWith((ref) => Stream.value(mockUser)),
    ]);

    // Wait for the stream to emit
    await container.read(authStateProvider.future);

    expect(container.read(currentUserIdProvider), '123');
  });
}
