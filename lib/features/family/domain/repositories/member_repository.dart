import '../../../../core/enums/member_role.dart';
import '../../../../core/utils/result.dart';
import '../entities/member.dart';

abstract class MemberRepository {
  Future<Result<Member>> createMember({
    required String familyId,
    required String name,
    required int age,
    required MemberRole role,
    required String avatarSeed,
    required String accentColor,
    String? userId,
  });

  Future<Result<Member>> updateMember({
    required String memberId,
    String? name,
    int? age,
    String? avatarSeed,
    String? accentColor,
  });

  Future<Result<void>> deleteMember(String memberId);

  Future<Result<List<Member>>> getMembersForFamily(String familyId);

  Stream<List<Member>> watchMembersForFamily(String familyId);

  Future<Result<Member?>> getMember(String memberId);

  Future<Result<Member?>> getMemberForUser(String uid);
}
