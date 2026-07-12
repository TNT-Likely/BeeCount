import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

/// AWS Signature Version 4 签名算法实现
///
/// 用于对 S3 REST API 请求进行签名认证
/// 参考：https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html
class S3SignatureV4 {
  final String accessKey;
  final String secretKey;
  final String region;
  final String service;

  S3SignatureV4({
    required this.accessKey,
    required this.secretKey,
    required this.region,
    this.service = 's3',
  });

  /// 生成签名的 Authorization Header 和其他必需 headers
  ///
  /// [method] HTTP 方法（GET, PUT, DELETE等）
  /// [uri] 请求的完整 URI
  /// [headers] 原始请求 headers
  /// [payloadBytes] 请求体字节数组（可选）
  ///
  /// 返回包含签名的完整 headers
  Map<String, String> sign({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? payloadBytes,
  }) {
    final now = DateTime.now().toUtc();
    final dateStamp = _formatDateStamp(now);
    final amzDate = _formatAmzDate(now);

    // 1. 准备 headers
    final mutableHeaders = Map<String, String>.from(headers);
    final payloadHash = _sha256HashBytes(payloadBytes ?? []);
    mutableHeaders['x-amz-date'] = amzDate;
    mutableHeaders['x-amz-content-sha256'] = payloadHash;

    // 2. 创建 Canonical Request
    final canonicalRequest = _createCanonicalRequest(
      method: method,
      uri: uri,
      headers: mutableHeaders,
      payloadHash: payloadHash,
    );

    // 3. 创建 String to Sign
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = _createStringToSign(
      amzDate: amzDate,
      credentialScope: credentialScope,
      canonicalRequest: canonicalRequest,
    );

    // 4. 计算签名
    final signature = _calculateSignature(
      secretKey: secretKey,
      dateStamp: dateStamp,
      region: region,
      service: service,
      stringToSign: stringToSign,
    );

    // 5. 添加 Authorization Header
    final signedHeaders = mutableHeaders.keys
        .where((k) =>
            k.toLowerCase().startsWith('x-amz-') ||
            k.toLowerCase() == 'host' ||
            k.toLowerCase() == 'content-type' ||
            k.toLowerCase() == 'content-length')
        .map((k) => k.toLowerCase())
        .toList()
      ..sort();

    mutableHeaders['Authorization'] = 'AWS4-HMAC-SHA256 '
        'Credential=$accessKey/$credentialScope, '
        'SignedHeaders=${signedHeaders.join(';')}, '
        'Signature=$signature';

    return mutableHeaders;
  }

  /// 创建规范请求（Canonical Request）
  String _createCanonicalRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String payloadHash,
  }) {
    // Canonical URI
    final canonicalUri = uri.path.isEmpty ? '/' : uri.path;

    // Canonical Query String
    final sortedParams = uri.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final canonicalQuery = sortedParams
        .map((e) => '${Uri.encodeComponent(e.key)}='
            '${Uri.encodeComponent(e.value)}')
        .join('&');

    // Canonical Headers (只包含签名相关的 headers)
    final signedHeaderKeys = headers.keys
        .where((k) =>
            k.toLowerCase().startsWith('x-amz-') ||
            k.toLowerCase() == 'host' ||
            k.toLowerCase() == 'content-type' ||
            k.toLowerCase() == 'content-length')
        .map((k) => k.toLowerCase())
        .toList()
      ..sort();

    final canonicalHeaders = signedHeaderKeys.map((key) {
      final originalKey = headers.keys.firstWhere(
        (k) => k.toLowerCase() == key,
      );
      return '$key:${headers[originalKey]!.trim()}\n';
    }).join();

    // Signed Headers
    final signedHeaders = signedHeaderKeys.join(';');

    return '$method\n'
        '$canonicalUri\n'
        '$canonicalQuery\n'
        '$canonicalHeaders\n'
        '$signedHeaders\n'
        '$payloadHash';
  }

  /// 创建待签名字符串（String to Sign）
  String _createStringToSign({
    required String amzDate,
    required String credentialScope,
    required String canonicalRequest,
  }) {
    final hashedRequest = _sha256Hash(canonicalRequest);
    return 'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$credentialScope\n'
        '$hashedRequest';
  }

  /// 计算最终签名
  String _calculateSignature({
    required String secretKey,
    required String dateStamp,
    required String region,
    required String service,
    required String stringToSign,
  }) {
    final kDate = _hmacSha256('AWS4$secretKey', dateStamp);
    final kRegion = _hmacSha256Bytes(kDate, region);
    final kService = _hmacSha256Bytes(kRegion, service);
    final kSigning = _hmacSha256Bytes(kService, 'aws4_request');
    final signature = _hmacSha256Bytes(kSigning, stringToSign);
    return hex.encode(signature);
  }

  /// SHA256 哈希（字符串输入）
  String _sha256Hash(String data) {
    return hex.encode(sha256.convert(utf8.encode(data)).bytes);
  }

  /// SHA256 哈希（字节数组输入）
  String _sha256HashBytes(List<int> data) {
    return hex.encode(sha256.convert(data).bytes);
  }

  /// HMAC-SHA256（字符串密钥）
  List<int> _hmacSha256(String key, String data) {
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(data)).bytes;
  }

  /// HMAC-SHA256（字节数组密钥）
  List<int> _hmacSha256Bytes(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  /// 格式化为 AMZ 日期时间格式（20230101T120000Z）
  String _formatAmzDate(DateTime dt) {
    final iso = dt.toIso8601String();
    return iso.replaceAll(RegExp(r'[-:]'), '').split('.')[0] + 'Z';
  }

  /// 格式化为日期戳格式（20230101）
  String _formatDateStamp(DateTime dt) {
    return dt.toIso8601String().split('T')[0].replaceAll('-', '');
  }
}
