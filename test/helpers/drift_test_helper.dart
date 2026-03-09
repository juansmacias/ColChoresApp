import 'dart:io';

import 'package:drift/native.dart';
import 'package:family_chores_app/core/database/app_database.dart';

abstract class DriftTestHelper {
  DriftTestHelper._();

  static Future<AppDatabase> createInMemoryDatabase() async {
    return AppDatabase(NativeDatabase.memory());
  }

  static Future<AppDatabase> createFileDatabase(String name) async {
    final directory = await Directory.systemTemp.createTemp('chores_app_test_');
    final file = File('${directory.path}/$name.sqlite');
    return AppDatabase(NativeDatabase.createInBackground(file));
  }

  static AppDatabase openFileDatabase(String path) {
    final file = File(path);
    return AppDatabase(NativeDatabase.createInBackground(file));
  }

  static Future<void> closeDatabase(AppDatabase database) async {
    await database.close();
  }
}
