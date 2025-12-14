import 'package:flutter_test/flutter_test.dart';
import 'package:nerd_herd/models/user_profile.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('UserProfile', () {
    test('fromJson creates valid profile with all fields', () {
      final json = {
        'user_id': 'test-user-123',
        'university_id': 'uni-456',
        'is_tutor': true,
        'current_classes': ['CS101', 'MATH200'],
        'intent_tag': 'Studying Calculus',
        'full_name': 'John Doe',
        'avatar_url': 'https://example.com/avatar.jpg',
        'lat': 40.7128,
        'lng': -74.0060,
        'last_updated': '2024-01-01T12:00:00Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.userId, 'test-user-123');
      expect(profile.universityId, 'uni-456');
      expect(profile.isTutor, true);
      expect(profile.currentClasses, ['CS101', 'MATH200']);
      expect(profile.intentTag, 'Studying Calculus');
      expect(profile.fullName, 'John Doe');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.location, isNotNull);
      expect(profile.location!.latitude, 40.7128);
      expect(profile.location!.longitude, -74.0060);
      expect(profile.lastUpdated, isNotNull);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'user_id': 'test-user-123',
        'is_tutor': false,
        'current_classes': [],
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.userId, 'test-user-123');
      expect(profile.universityId, isNull);
      expect(profile.isTutor, false);
      expect(profile.currentClasses, isEmpty);
      expect(profile.intentTag, isNull);
      expect(profile.fullName, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.location, isNull);
    });

    test('fromJson handles missing location gracefully', () {
      final json = {
        'user_id': 'test-user-123',
        'is_tutor': false,
        'current_classes': [],
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.location, isNull);
    });

    test('fromJson parses location with long instead of lng', () {
      final json = {
        'user_id': 'test-user-123',
        'is_tutor': false,
        'current_classes': [],
        'lat': 40.7128,
        'long': -74.0060, // Using 'long' instead of 'lng'
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.location, isNotNull);
      expect(profile.location!.latitude, 40.7128);
      expect(profile.location!.longitude, -74.0060);
    });

    test('toJson serializes correctly', () {
      final profile = UserProfile(
        userId: 'test-user-123',
        universityId: 'uni-456',
        isTutor: true,
        currentClasses: ['CS101', 'MATH200'],
        intentTag: 'Studying Calculus',
        fullName: 'John Doe',
        avatarUrl: 'https://example.com/avatar.jpg',
        location: const LatLng(40.7128, -74.0060),
      );

      final json = profile.toJson();

      expect(json['user_id'], 'test-user-123');
      expect(json['university_id'], 'uni-456');
      expect(json['is_tutor'], true);
      expect(json['current_classes'], ['CS101', 'MATH200']);
      expect(json['intent_tag'], 'Studying Calculus');
      expect(json['full_name'], 'John Doe');
      expect(json['avatar_url'], 'https://example.com/avatar.jpg');
      expect(json['lat'], 40.7128);
      expect(json['long'], -74.0060);
      expect(json['last_updated'], isNotNull);
    });

    test('toJson handles null location', () {
      final profile = UserProfile(
        userId: 'test-user-123',
        isTutor: false,
        currentClasses: const [],
      );

      final json = profile.toJson();

      expect(json.containsKey('lat'), false);
      expect(json.containsKey('long'), false);
    });

    test('roundtrip serialization preserves data', () {
      final original = UserProfile(
        userId: 'test-user-123',
        universityId: 'uni-456',
        isTutor: true,
        currentClasses: const ['CS101'],
        intentTag: 'Studying',
        fullName: 'John Doe',
        avatarUrl: 'https://example.com/avatar.jpg',
        location: const LatLng(40.7128, -74.0060),
      );

      final json = original.toJson();
      final deserialized = UserProfile.fromJson(json);

      expect(deserialized.userId, original.userId);
      expect(deserialized.universityId, original.universityId);
      expect(deserialized.isTutor, original.isTutor);
      expect(deserialized.currentClasses, original.currentClasses);
      expect(deserialized.intentTag, original.intentTag);
      expect(deserialized.fullName, original.fullName);
      expect(deserialized.avatarUrl, original.avatarUrl);
      expect(deserialized.location!.latitude, original.location!.latitude);
      expect(deserialized.location!.longitude, original.location!.longitude);
    });
  });
}
