import "dart:convert";

import "package:allocate/model/task/subtask.dart";
import "package:isar/isar.dart";

import "../../util/enums.dart";
import "../../util/interfaces/copyable.dart";

part "routine.g.dart";

// TODO: implement a subtask sorting object and serialization.

@collection
class Routine implements Copyable<Routine> {
  static const int maxTasksPerRoutine = 10;
  static const int lowerBound = 1;
  static const int upperBound = 10;
  static const int maxTaskWeight = 5;
  static const int maxRoutineWeight = maxTaskWeight * maxTasksPerRoutine;

  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.ordinal)
  RoutineTime routineTime;

  @Index()
  String name;

  @Index()
  int weight;

  int expectedDuration;

  @Index()
  int realDuration;

  final List<SubTask> routineTasks;

  @Index()
  int? customViewIndex;

  @Index()
  bool isSynced = false;

  @Index()
  bool toDelete = false;

  Routine(
      {required this.routineTime,
      required this.name,
      this.weight = 0,
      Duration expectedDuration = const Duration(hours: 1),
      int? realDuration,
      List<SubTask>? routineTasks})
      : expectedDuration = expectedDuration.inSeconds,
        //This is explicitly calculated by the service.
        realDuration = realDuration ?? expectedDuration.inSeconds,
        routineTasks = routineTasks ?? List.empty(growable: true);

  Routine.fromEntity({required Map<String, dynamic> entity})
      : id = entity["id"] as Id,
        routineTime = RoutineTime.values[entity["routineTime"]],
        name = entity["name"] as String,
        weight = entity["weight"] as int,
        expectedDuration = entity["expectedDuration"],
        realDuration = entity["realDuration"],
        routineTasks =
            (jsonDecode(entity["routineTasks"])["routineTasks"] as List)
                .map((rt) => SubTask.fromEntity(entity: rt))
                .toList(),
        customViewIndex = entity["customViewIndex"] as int?,
        isSynced = true,
        toDelete = false;

  Map<String, dynamic> toEntity() => {
        "id": id,
        "routineTime": routineTime.index,
        "name": name,
        "weight": weight,
        "expectedDuration": expectedDuration,
        "realDuration": realDuration,
        "routineTasks": jsonEncode(routineTasks.map((rt) => rt.toEntity())),
        "customViewIndex": customViewIndex
      };

  @override
  Routine copy() => Routine(
      name: name,
      routineTime: routineTime,
      weight: weight,
      expectedDuration: Duration(seconds: expectedDuration),
      routineTasks: List.from(routineTasks));

  @override
  Routine copyWith({
    String? name,
    RoutineTime? routineTime,
    int? weight,
    Duration? expectedDuration,
    List<SubTask>? routineTasks,
  }) =>
      Routine(
          name: name ?? this.name,
          routineTime: routineTime ?? this.routineTime,
          weight: weight ?? this.weight,
          expectedDuration:
              expectedDuration ?? Duration(seconds: this.expectedDuration),
          routineTasks: (null != routineTasks)
              ? List.from(routineTasks)
              : List.from(this.routineTasks));

  @override
  List<Object> get props => [
        id,
        routineTime,
        name,
        weight,
        expectedDuration,
        routineTasks,
        customViewIndex.toString(),
        isSynced,
        toDelete
      ];
}
