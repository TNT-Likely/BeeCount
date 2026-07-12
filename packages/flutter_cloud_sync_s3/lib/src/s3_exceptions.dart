/// S3 相关异常基类
class S3Exception implements Exception {
  final String message;
  final int? statusCode;
  final Exception? originalException;

  S3Exception(this.message, {this.statusCode, this.originalException});

  @override
  String toString() {
    final parts = ['S3Exception: $message'];
    if (statusCode != null) {
      parts.add('(HTTP $statusCode)');
    }
    if (originalException != null) {
      parts.add('\nCaused by: $originalException');
    }
    return parts.join(' ');
  }
}

/// S3 认证异常（AccessKey 或 SecretKey 无效）
class S3AuthException extends S3Exception {
  S3AuthException(String message, {Exception? originalException})
      : super(message, statusCode: 403, originalException: originalException);
}

/// S3 对象未找到异常
class S3ObjectNotFoundException extends S3Exception {
  final String key;

  S3ObjectNotFoundException(this.key)
      : super('Object not found: $key', statusCode: 404);
}

/// S3 Bucket 未找到异常
class S3BucketNotFoundException extends S3Exception {
  final String bucket;

  S3BucketNotFoundException(this.bucket)
      : super('Bucket not found: $bucket', statusCode: 404);
}

/// S3 网络异常
class S3NetworkException extends S3Exception {
  S3NetworkException(String message, {Exception? originalException})
      : super(message, originalException: originalException);
}

/// S3 权限不足异常
class S3PermissionDeniedException extends S3Exception {
  S3PermissionDeniedException(String message) : super(message, statusCode: 403);
}
