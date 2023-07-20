import "dart:convert";

import "package:allocate/model/task/subtask.dart";
import "package:equatable/equatable.dart";
import "package:isar/isar.dart";

import "../../util/enums.dart";
import "../../util/interfaces/copyable.dart";

part "todo.g.dart";

// TODO: refactor constructor -> take all logic out and place in provider class.
// Then this can be built.

@Collection(inheritance: false)
class ToDo with EquatableMixin implements Copyable<ToDo> {
  Id id = Isar.autoIncrement;

  @Index()
  int? groupID;
  @Index()
  int groupIndex = -1;
  @Index()
  int customViewIndex = -1;

  @Enumerated(EnumType.ordinal)
  final TaskType taskType;

  final List<SubTask> subTasks;

  @Index()
  String name;
  String description;
  @Index()
  int weight;
  // Stored in seconds.
  int expectedDuration;
  @Index()
  int realDuration;

  @Enumerated(EnumType.ordinal)
  Priority priority;
  @Index()
  bool completed = false;
  DateTime dueDate;

  @Index()
  bool myDay;

  bool repeatable;
  @Enumerated(EnumType.ordinal)
  Frequency frequency;
  List<bool> repeatDays;
  int repeatSkip;
  @Index()
  bool isSynced = false;
  @Index()
  bool toDelete = false;

  ToDo({
    this.groupID,
    required this.taskType,
    required this.name,
    this.description = "",
    this.weight = 0,
    required this.expectedDuration,
    required this.realDuration,
    this.priority = Priority.low,
    required this.dueDate,
    this.myDay = false,
    this.repeatable = false,
    this.frequency = Frequency.once,
    required this.repeatDays,
    this.repeatSkip = 1,
    required this.subTasks,
  });

  // -> From Entitiy.
  ToDo.fromEntity({required Map<String, dynamic> entity})
      : id = entity["id"] as Id,
        groupID = entity["groupID"] as int,
        groupIndex = entity["groupIndex"] as int,
        customViewIndex = entity["customViewIndex"] as int,
        taskType = TaskType.values[entity["taskType"]],
        name = entity["name"] as String,
        description = entity["description"] as String,
        weight = entity["weight"] as int,
        expectedDuration = entity["expectedDuration"] as int,
        realDuration = entity["realDuration"] as int,
        priority = Priority.values[entity["priority"]],
        dueDate = DateTime.parse(entity["dueDate"]),
        myDay = entity["myDay"] as bool,
        repeatable = entity["repeatable"] as bool,
        frequency = Frequency.values[entity["frequency"]],
        repeatDays = entity["repeatDays"],
        repeatSkip = entity["repeatSkip"] as int,
        subTasks = (jsonDecode(entity["subTasks"])["subTasks"]! as List)
            .map((st) => SubTask.fromEntity(entity: st))
            .toList(),
        isSynced = entity["isSynced"] as bool,
        toDelete = entity["toDelete"] as bool;

  Map<String, dynamic> toEntity() => {
        "id": id,
        "groupID": groupID,
        "groupIndex": groupIndex,
        "customViewIndex": customViewIndex,
        "taskType": taskType.index,
        "name": name,
        "description": description,
        "weight": weight,
        "expectedDuration": expectedDuration,
        "realDuration": realDuration,
        "priority": priority.index,
        "dueDate": dueDate.toIso8601String(),
        "myDay": myDay,
        "repeatable": repeatable,
        "frequency": frequency.index,
        "repeatDays": repeatDays,
        "repeatSkip": repeatSkip,
        "subTasks": jsonEncode(subTasks.map((st) => st.toEntity())),
        "isSynced": isSynced,
        "toDelete": toDelete
      };

  @override
  ToDo copy() => ToDo(
      taskType: taskType,
      name: name,
      description: description,
      weight: weight,
      expectedDuration: expectedDuration,
      realDuration: realDuration,
      priority: priority,
      dueDate: dueDate,
      repeatable: repeatable,
      frequency: frequency,
      repeatDays: List.from(repeatDays),
      repeatSkip: repeatSkip,
      subTasks: List.from(subTasks));

  @override
  ToDo copyWith({
    TaskType? taskType,
    String? name,
    String? description,
    int? weight,
    int? expectedDuration,
    int? realDuration,
    Priority? priority,
    DateTime? dueDate,
    bool? myDay,
    bool? repeatable,
    Frequency? frequency,
    List<bool>? repeatDays,
    int? repeatSkip,
    List<SubTask>? subTasks,
  }) =>
      ToDo(
          taskType: taskType ?? this.taskType,
          name: name ?? this.name,
          description: description ?? this.description,
          weight: weight ?? this.weight,
          expectedDuration: expectedDuration ?? this.expectedDuration,
          realDuration: realDuration ?? this.realDuration,
          priority: priority ?? this.priority,
          dueDate: dueDate ?? this.dueDate,
          myDay: myDay ?? false,
          repeatable: repeatable ?? this.repeatable,
          repeatDays: List.from(repeatDays ?? this.repeatDays),
          repeatSkip: repeatSkip ?? this.repeatSkip,
          subTasks: List.from(subTasks ?? this.subTasks));
  @ignore
  @override
  List<Object?> get props => [
        id,
        customViewIndex,
        groupID,
        groupIndex,
        name,
        description,
        weight,
        expectedDuration,
        priority,
        completed,
        dueDate,
        myDay,
        repeatable,
        frequency,
        repeatDays,
        repeatSkip,
        isSynced,
        toDelete
      ];
}
