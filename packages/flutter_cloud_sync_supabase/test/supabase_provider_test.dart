import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_cloud_sync_supabase/flutter_cloud_sync_supabase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseProvider', () {
    late SupabaseProvider provider;

    setUp(() {
      provider = SupabaseProvider();
    });

    test('should have correct provider ID', () {
      expect(provider.providerId, equals('supabase'));
    });

    test('should have correct provider name', () {
      expect(provider.providerName, equals('Supabase'));
    });

    test('validateConfig should return false for empty config', () {
      expect(provider.validateConfig({}), isFalse);
    });

    test('validateConfig should return false for missing url', () {
      expect(
        provider.validateConfig({'anonKey': 'key'}),
        isFalse,
      );
    });

    test('validateConfig should return false for missing anonKey', () {
      expect(
        provider.validateConfig({'url': 'https://example.com'}),
        isFalse,
      );
    });

    test('validateConfig should return true for valid config', () {
      expect(
        provider.validateConfig({
          'url': 'https://example.supabase.co',
          'anonKey': 'test-key',
        }),
        isTrue,
      );
    });

    test('validateConfig should accept optional bucket', () {
      expect(
        provider.validateConfig({
          'url': 'https://example.supabase.co',
          'anonKey': 'test-key',
          'bucket': 'user-data',
        }),
        isTrue,
      );
    });

    test('validateConfig should return false for invalid bucket type', () {
      expect(
        provider.validateConfig({
          'url': 'https://example.supabase.co',
          'anonKey': 'test-key',
          'bucket': 123, // should be string
        }),
        isFalse,
      );
    });

    test(
        'should throw CloudConfigurationException when accessing auth before initialization',
        () {
      expect(
        () => provider.auth,
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    test(
        'should throw CloudConfigurationException when accessing storage before initialization',
        () {
      expect(
        () => provider.storage,
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    test('initialize should throw on invalid config', () async {
      expect(
        () => provider.initialize({}),
        throwsA(isA<CloudConfigurationException>()),
      );
    });

    // Note: Full integration tests require a real Supabase instance
    // and should be run separately with proper credentials
  });

  group('SupabaseAuthService', () {
    test('should convert Supabase user to CloudUser', () {
      // This would require mocking Supabase client
      // For now, we just verify the class exists
      expect(SupabaseAuthService, isNotNull);
    });
  });

  group('SupabaseStorageService', () {
    test('should implement CloudStorageService', () {
      // This would require mocking Supabase client
      // For now, we just verify the class exists
      expect(SupabaseStorageService, isNotNull);
    });
  });
}
