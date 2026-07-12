import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 's3_signature.dart';
import 's3_exceptions.dart';

/// S3 REST API 客户端
///
/// 实现基础的 S3 操作：
/// - PutObject: 上传对象
/// - GetObject: 下载对象
/// - DeleteObject: 删除对象
/// - HeadObject: 检查对象是否存在
/// - ListObjectsV2: 列出对象
class S3Client {
  final String endpoint;
  final String region;
  final String accessKey;
  final String secretKey;
  final bool useSSL;
  final int? port;

  late final S3SignatureV4 _signer;
  late final String _baseUrl;
  late final http.Client _httpClient;

  S3Client({
    required this.endpoint,
    required this.region,
    required this.accessKey,
    required this.secretKey,
    this.useSSL = true,
    this.port,
  }) {
    _signer = S3SignatureV4(
      accessKey: accessKey,
      secretKey: secretKey,
      region: region,
    );

    final scheme = useSSL ? 'https' : 'http';
    final portStr = port != null ? ':$port' : '';
    _baseUrl = '$scheme://$endpoint$portStr';

    _httpClient = http.Client();
  }

  /// 释放资源
  void dispose() {
    _httpClient.close();
  }

  /// PUT Object - 上传文件
  Future<void> putObject({
    required String bucket,
    required String key,
    required Uint8List data,
    String? contentType,
  }) async {
    final uri = Uri.parse('$_baseUrl/$bucket/${_encodeKey(key)}');

    var headers = <String, String>{
      'Host': endpoint,
      'Content-Type': contentType ?? 'application/octet-stream',
      'Content-Length': '${data.length}',
    };

    // 签名请求（传递字节数组以正确计算 SHA256）
    headers = _signer.sign(
      method: 'PUT',
      uri: uri,
      headers: headers,
      payloadBytes: data,
    );

    try {
      final response = await _httpClient.put(uri, headers: headers, body: data);

      if (response.statusCode != 200 && response.statusCode != 204) {
        _handleError('PutObject', response);
      }
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('PutObject failed: $e',
          originalException: e as Exception?);
    }
  }

  /// GET Object - 下载文件
  Future<Uint8List> getObject({
    required String bucket,
    required String key,
  }) async {
    final uri = Uri.parse('$_baseUrl/$bucket/${_encodeKey(key)}');

    var headers = <String, String>{
      'Host': endpoint,
    };

    headers = _signer.sign(
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    try {
      final response = await _httpClient.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        throw S3ObjectNotFoundException(key);
      } else {
        _handleError('GetObject', response);
        throw S3Exception('GetObject failed');
      }
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('GetObject failed: $e',
          originalException: e as Exception?);
    }
  }

  /// DELETE Object - 删除文件
  Future<void> deleteObject({
    required String bucket,
    required String key,
  }) async {
    final uri = Uri.parse('$_baseUrl/$bucket/${_encodeKey(key)}');

    var headers = <String, String>{
      'Host': endpoint,
    };

    headers = _signer.sign(
      method: 'DELETE',
      uri: uri,
      headers: headers,
    );

    try {
      final response = await _httpClient.delete(uri, headers: headers);

      if (response.statusCode != 204 && response.statusCode != 200) {
        // 404 也算成功（对象已不存在）
        if (response.statusCode != 404) {
          _handleError('DeleteObject', response);
        }
      }
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('DeleteObject failed: $e',
          originalException: e as Exception?);
    }
  }

  /// HEAD Object - 检查文件是否存在
  Future<bool> headObject({
    required String bucket,
    required String key,
  }) async {
    final uri = Uri.parse('$_baseUrl/$bucket/${_encodeKey(key)}');

    var headers = <String, String>{
      'Host': endpoint,
    };

    headers = _signer.sign(
      method: 'HEAD',
      uri: uri,
      headers: headers,
    );

    try {
      final response = await _httpClient.head(uri, headers: headers);
      return response.statusCode == 200;
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } catch (e) {
      // HEAD 请求失败返回 false 而不抛出异常
      return false;
    }
  }

  /// LIST Objects V2 - 列出对象
  Future<List<String>> listObjects({
    required String bucket,
    String? prefix,
  }) async {
    final queryParams = <String, String>{
      'list-type': '2', // ListObjectsV2
    };
    if (prefix != null && prefix.isNotEmpty) {
      queryParams['prefix'] = prefix;
    }

    final uri =
        Uri.parse('$_baseUrl/$bucket').replace(queryParameters: queryParams);

    var headers = <String, String>{
      'Host': endpoint,
    };

    headers = _signer.sign(
      method: 'GET',
      uri: uri,
      headers: headers,
    );

    try {
      final response = await _httpClient.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return _parseListObjectsResponse(response.body);
      } else if (response.statusCode == 404) {
        throw S3BucketNotFoundException(bucket);
      } else {
        _handleError('ListObjects', response);
        return [];
      }
    } on SocketException catch (e) {
      throw S3NetworkException('Network error: ${e.message}',
          originalException: e);
    } catch (e) {
      if (e is S3Exception) rethrow;
      throw S3Exception('ListObjects failed: $e',
          originalException: e as Exception?);
    }
  }

  /// 解析 ListObjects 响应（XML）
  List<String> _parseListObjectsResponse(String xmlBody) {
    try {
      final document = XmlDocument.parse(xmlBody);
      final contents = document.findAllElements('Contents');

      return contents
          .map((element) {
            final keyElement = element.findElements('Key').firstOrNull;
            return keyElement?.innerText;
          })
          .whereType<String>()
          .toList();
    } catch (e) {
      // XML 解析失败，返回空列表
      return [];
    }
  }

  /// URL 编码 Key（保留 /）
  String _encodeKey(String key) {
    return key.split('/').map(Uri.encodeComponent).join('/');
  }

  /// 统一错误处理
  void _handleError(String operation, http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    // 尝试解析 XML 错误信息
    String? errorCode;
    String? errorMessage;
    try {
      final document = XmlDocument.parse(body);
      errorCode = document.findAllElements('Code').firstOrNull?.innerText;
      errorMessage = document.findAllElements('Message').firstOrNull?.innerText;
    } catch (_) {
      // XML 解析失败，使用原始 body
    }

    final message = errorMessage ?? body;

    if (statusCode == 403) {
      if (errorCode == 'InvalidAccessKeyId' ||
          errorCode == 'SignatureDoesNotMatch') {
        throw S3AuthException('Authentication failed: $message');
      } else {
        throw S3PermissionDeniedException('Permission denied: $message');
      }
    } else if (statusCode == 404) {
      throw S3ObjectNotFoundException('Object not found');
    } else {
      throw S3Exception(
        '$operation failed (HTTP $statusCode): $message',
        statusCode: statusCode,
      );
    }
  }
}
