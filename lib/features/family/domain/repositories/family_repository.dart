import '../../../../core/utils/result.dart';
import '../entities/family.dart';

abstract class FamilyRepository {
  Future<Result<Family>> createFamily({
    required String name,
    required String createdByUid,
    required String createdByName,
  });

  Future<Result<Family>> joinFamily({
    required String inviteCode,
    required String userId,
    required String userName,
  });

  Future<Result<Family?>> getFamilyForUser(String uid);

  Stream<Family?> watchFamily(String familyId);

  Future<Result<Family>> updateFamily({
    required String familyId,
    String? name,
  });

  Future<Result<String>> generateInviteCode(String familyId);
}
