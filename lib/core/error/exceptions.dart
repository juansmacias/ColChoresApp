// Data-layer exceptions. These are caught by repositories and
// converted into Failure instances for the domain layer.

class NetworkException implements Exception {
  const NetworkException([this.message = 'Network error occurred']);
  final String message;
}

class DatabaseException implements Exception {
  const DatabaseException([this.message = 'Database error occurred']);
  final String message;
}

class AuthException implements Exception {
  const AuthException([this.message = 'Authentication failed']);
  final String message;
}

class SyncException implements Exception {
  const SyncException([this.message = 'Sync operation failed']);
  final String message;
}

class NotFoundException implements Exception {
  const NotFoundException([this.message = 'Resource not found']);
  final String message;
}
