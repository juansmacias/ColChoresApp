import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class DeepLinkRedirectCubit extends Cubit<Uri?> {
  DeepLinkRedirectCubit() : super(null);

  void clearPendingLink() => emit(null);

  bool get hasPendingLink => state != null;

  void setPendingLink(Uri uri) => emit(uri);
}
