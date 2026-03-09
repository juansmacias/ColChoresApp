import 'package:cloud_functions/cloud_functions.dart';
import 'package:family_chores_app/features/family/data/datasources/family_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

void main() {
  group('FamilyRemoteDataSource', () {
    late MockFirebaseFunctions functions;
    late MockHttpsCallable callable;
    late FamilyRemoteDataSource dataSource;

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() {
      functions = MockFirebaseFunctions();
      callable = MockHttpsCallable();
      dataSource = FamilyRemoteDataSource(functions);
    });

    test('generateInviteCode should return inviteCode from callable payload',
        () async {
      final result = MockHttpsCallableResult();
      when(() => functions.httpsCallable('generateInviteCode'))
          .thenReturn(callable);
      when(() => result.data)
          .thenReturn(<String, dynamic>{'inviteCode': 'ABC123'});
      when(
        () => callable.call<Map<String, dynamic>>({'familyId': 'family-1'}),
      ).thenAnswer((_) async => result);

      final inviteCode = await dataSource.generateInviteCode('family-1');

      expect(inviteCode, 'ABC123');
    });

    test('validateAndJoinFamily should return family payload from callable',
        () async {
      final result = MockHttpsCallableResult();
      when(() => functions.httpsCallable('validateAndJoinFamily'))
          .thenReturn(callable);
      when(() => result.data).thenReturn(<String, dynamic>{
        'familyId': 'family-1',
        'familyName': 'The Johnsons',
      });
      when(
        () => callable.call<Map<String, dynamic>>({
          'inviteCode': 'ABC123',
          'userId': 'user-1',
          'userName': 'Sofia',
        }),
      ).thenAnswer((_) async => result);

      final payload = await dataSource.validateAndJoinFamily(
        inviteCode: 'ABC123',
        userId: 'user-1',
        userName: 'Sofia',
      );

      expect(payload.familyId, 'family-1');
      expect(payload.familyName, 'The Johnsons');
    });
  });
}
