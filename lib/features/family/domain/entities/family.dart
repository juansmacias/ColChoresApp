import 'package:equatable/equatable.dart';

class Family extends Equatable {
  const Family({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.remoteId,
    this.inviteCode,
    this.inviteCodeExpiresAt,
  });

  final String id;
  final String? remoteId;
  final String name;
  final String createdBy;
  final String? inviteCode;
  final DateTime? inviteCodeExpiresAt;
  final DateTime createdAt;

  String get syncId => remoteId ?? id;

  @override
  List<Object?> get props => [
        id,
        remoteId,
        name,
        createdBy,
        inviteCode,
        inviteCodeExpiresAt,
        createdAt,
      ];
}
