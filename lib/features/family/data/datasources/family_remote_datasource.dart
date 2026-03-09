import 'package:cloud_functions/cloud_functions.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FamilyRemoteDataSource {
  FamilyRemoteDataSource(this._functions);

  final FirebaseFunctions _functions;

  Future<String> generateInviteCode(String familyId) async {
    final callable = _functions.httpsCallable('generateInviteCode');
    final response = await callable.call<Map<String, dynamic>>(
      {'familyId': familyId},
    );
    return response.data['inviteCode'] as String;
  }

  Future<String> validateAndJoinFamily({
    required String inviteCode,
    required String userId,
    required String userName,
  }) async {
    final callable = _functions.httpsCallable('validateAndJoinFamily');
    final response = await callable.call<Map<String, dynamic>>(
      {
        'inviteCode': inviteCode,
        'userId': userId,
        'userName': userName,
      },
    );
    return response.data['familyId'] as String;
  }
}
