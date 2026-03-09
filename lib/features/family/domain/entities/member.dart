import 'package:equatable/equatable.dart';

import '../../../../core/enums/age_group.dart';
import '../../../../core/enums/member_role.dart';

class Member extends Equatable {
  const Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.role,
    required this.age,
    required this.avatarSeed,
    required this.accentColor,
    required this.createdAt,
    this.remoteId,
    this.userId,
    this.points = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.hasPin = false,
  });

  final String id;
  final String? remoteId;
  final String familyId;
  final String name;
  final MemberRole role;
  final int age;
  final String avatarSeed;
  final String accentColor;
  final String? userId;
  final int points;
  final int currentStreak;
  final int longestStreak;
  final bool hasPin;
  final DateTime createdAt;

  AgeGroup get ageGroup {
    if (age <= 4) {
      return AgeGroup.toddler;
    }
    if (age <= 12) {
      return AgeGroup.child;
    }
    if (age <= 17) {
      return AgeGroup.teen;
    }
    return AgeGroup.adult;
  }

  bool get isParent => role == MemberRole.parent;
  bool get isChild => role == MemberRole.child;

  @override
  List<Object?> get props => [
        id,
        remoteId,
        familyId,
        name,
        role,
        age,
        avatarSeed,
        accentColor,
        userId,
        points,
        currentStreak,
        longestStreak,
        hasPin,
        createdAt,
      ];
}
