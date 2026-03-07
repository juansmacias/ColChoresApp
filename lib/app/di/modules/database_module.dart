import 'dart:io';

import 'package:drift/native.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';

@module
abstract class DatabaseModule {
  @preResolve
  @singleton
  Future<AppDatabase> get database async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'family_chores.db'));
    return AppDatabase(NativeDatabase(file));
  }
}
