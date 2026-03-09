import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

@module
abstract class NetworkModule {
  @singleton
  Connectivity get connectivity => Connectivity();

  // TODO(phase-2): Register FirebaseAuth and FirebaseFirestore here
}
