import 'package:family_chores_app/features/pin/data/services/pin_hash_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  final service = PinHashServiceImpl(const Uuid());

  test('generateSalt returns a non-empty unique value', () {
    final first = service.generateSalt();
    final second = service.generateSalt();

    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
    expect(first, isNot(second));
  });

  test('verify returns true for the original pin and false for a different pin',
      () {
    const pin = '1234';
    final salt = service.generateSalt();
    final hash = service.computeHash(pin, salt);

    expect(service.verify(pin, salt, hash), isTrue);
    expect(service.verify('9999', salt, hash), isFalse);
  });
}
