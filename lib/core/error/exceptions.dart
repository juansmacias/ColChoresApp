sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;
}

final class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
  });
}

final class SyncException extends AppException {
  const SyncException({
    required super.message,
    super.code,
  });
}

final class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
  });
}

final class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
  });
}

final class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
  });
}
