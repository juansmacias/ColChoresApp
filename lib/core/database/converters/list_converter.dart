import 'dart:convert';

import 'package:drift/drift.dart';

/// Converts `List<String>` to/from a JSON TEXT column in SQLite.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
