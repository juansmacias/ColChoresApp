import 'package:get_it/get_it.dart';

final GetIt getIt = GetIt.instance;

void setupTestDependencies() {
  getIt.reset();
  // TODO: Register mock implementations as features are built
  // Example:
  // getIt.registerSingleton<TaskRepository>(MockTaskRepository());
}

void tearDownTestDependencies() {
  getIt.reset();
}
