abstract class PinHashService {
  String generateSalt();

  String computeHash(String pin, String salt);

  bool verify(String pin, String salt, String storedHash);
}
