import 'dart:convert';

import 'package:drift/drift.dart';

/// Represents a single subtask within a task's checklist.
/// Serialized as JSON and stored in the tasks table's subtasks TEXT column.
class SubtaskModel {
  const SubtaskModel({
    required this.title,
    required this.completed,
  });

  factory SubtaskModel.fromJson(Map<String, dynamic> json) => SubtaskModel(
        title: json['title'] as String,
        completed: json['completed'] as bool,
      );

  final String title;
  final bool completed;

  Map<String, dynamic> toJson() => {
        'title': title,
        'completed': completed,
      };

  SubtaskModel copyWith({String? title, bool? completed}) => SubtaskModel(
        title: title ?? this.title,
        completed: completed ?? this.completed,
      );
}

/// Drift TypeConverter for `List<SubtaskModel>` stored as JSON TEXT.
class SubtaskListConverter extends TypeConverter<List<SubtaskModel>, String> {
  const SubtaskListConverter();

  @override
  List<SubtaskModel> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>)
          .map((e) => SubtaskModel.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  String toSql(List<SubtaskModel> value) =>
      jsonEncode(value.map((s) => s.toJson()).toList());
}
