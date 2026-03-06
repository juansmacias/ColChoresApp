import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

@singleton
class IdGenerator {
  const IdGenerator(this._uuid);

  final Uuid _uuid;

  String generate() => _uuid.v4();
}
