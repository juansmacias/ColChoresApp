import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/pin_hash_service.dart';

@LazySingleton(as: PinHashService)
class PinHashServiceImpl implements PinHashService {
  PinHashServiceImpl(this._uuid);

  final Uuid _uuid;

  @override
  String computeHash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt$pin')).toString();
  }

  @override
  String generateSalt() => _uuid.v4();

  @override
  bool verify(String pin, String salt, String storedHash) {
    final computed = computeHash(pin, salt);
    if (computed.length != storedHash.length) {
      return false;
    }

    var diff = 0;
    for (var i = 0; i < computed.length; i++) {
      diff |= computed.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
    }
    return diff == 0;
  }
}
