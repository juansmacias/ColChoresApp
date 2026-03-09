import 'package:injectable/injectable.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_connection.dart';

@module
abstract class DatabaseModule {
  @preResolve
  @singleton
  Future<AppDatabase> get database async {
    final executor = await openDatabaseConnection();
    return AppDatabase(executor);
  }
}
