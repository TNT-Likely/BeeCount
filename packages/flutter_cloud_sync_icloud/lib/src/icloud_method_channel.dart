import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Method Channel for iCloud native communication
class ICloudMethodChannel {
  static const MethodChannel _channel =
      MethodChannel('com.beecount.app/icloud');

  /// Check if iCloud is available
  /// Returns false if there's any error (including plugin not registered)
  Future<bool> isICloudAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isICloudAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint(
          'iCloud: PlatformException in isICloudAvailable: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('iCloud: Plugin not registered: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('iCloud: Error in isICloudAvailable: $e');
      return false;
    }
  }

  /// Initialize iCloud container
  /// Throws exception if initialization fails
  Future<void> initializeContainer() async {
    try {
      await _channel.invokeMethod('initializeContainer');
    } on PlatformException catch (e) {
      debugPrint(
          'iCloud: PlatformException in initializeContainer: ${e.message}');
      throw Exception('iCloud container initialization failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('iCloud: Plugin not registered: ${e.message}');
      throw Exception('iCloud plugin not available: ${e.message}');
    } catch (e) {
      debugPrint('iCloud: Error in initializeContainer: $e');
      throw Exception('iCloud container initialization failed: $e');
    }
  }

  /// Upload file to iCloud
  Future<void> uploadFile({
    required String path,
    required String data,
    Map<String, String>? metadata,
  }) async {
    await _channel.invokeMethod('uploadFile', {
      'path': path,
      'data': data,
      'metadata': metadata,
    });
  }

  /// Download file from iCloud
  Future<String?> downloadFile({required String path}) async {
    return await _channel.invokeMethod<String>('downloadFile', {
      'path': path,
    });
  }

  /// Delete file from iCloud
  Future<void> deleteFile({required String path}) async {
    await _channel.invokeMethod('deleteFile', {
      'path': path,
    });
  }

  /// List files in directory
  Future<List<Map<String, dynamic>>> listFiles({required String path}) async {
    final result = await _channel.invokeMethod<List>('listFiles', {
      'path': path,
    });
    return result?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ??
        [];
  }

  /// Check if file exists
  Future<bool> fileExists({required String path}) async {
    final result = await _channel.invokeMethod<bool>('fileExists', {
      'path': path,
    });
    return result ?? false;
  }

  /// Get file metadata
  Future<Map<String, dynamic>?> getFileMetadata({required String path}) async {
    final result = await _channel.invokeMethod<Map>('getFileMetadata', {
      'path': path,
    });
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  /// Get iCloud account info
  Future<Map<String, dynamic>?> getICloudAccountInfo() async {
    final result = await _channel.invokeMethod<Map>('getICloudAccountInfo');
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  /// Get detailed iCloud diagnostics
  Future<Map<String, dynamic>> getICloudDiagnostics() async {
    try {
      final result = await _channel.invokeMethod<Map>('getICloudDiagnostics');
      return result != null ? Map<String, dynamic>.from(result) : {};
    } on PlatformException catch (e) {
      debugPrint(
          'iCloud: PlatformException in getICloudDiagnostics: ${e.message}');
      return {'error': e.message};
    } on MissingPluginException catch (e) {
      debugPrint('iCloud: Plugin not registered: ${e.message}');
      return {'error': 'Plugin not registered'};
    } catch (e) {
      debugPrint('iCloud: Error in getICloudDiagnostics: $e');
      return {'error': e.toString()};
    }
  }
}
