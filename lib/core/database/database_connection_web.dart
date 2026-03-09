// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

Future<QueryExecutor> openDatabaseConnectionImpl() async {
  final storage = await DriftWebStorage.indexedDbIfSupported(
    'family_chores',
  );

  return WebDatabase.withStorage(
    storage,
  );
}
