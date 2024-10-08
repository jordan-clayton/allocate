import 'package:another_flushbar/flushbar.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:provider/provider.dart';

import '../../model/calendar_event.dart';
import '../../model/task/deadline.dart';
import '../../model/task/group.dart';
import '../../model/task/reminder.dart';
import '../../model/task/routine.dart';
import '../../model/task/subtask.dart';
import '../../model/task/todo.dart';
import '../../providers/application/event_provider.dart';
import '../../providers/model/deadline_provider.dart';
import '../../providers/model/group_provider.dart';
import '../../providers/model/reminder_provider.dart';
import '../../providers/model/routine_provider.dart';
import '../../providers/model/subtask_provider.dart';
import '../../providers/model/todo_provider.dart';
import '../../providers/viewmodels/deadline_viewmodel.dart';
import '../../providers/viewmodels/group_viewmodel.dart';
import '../../providers/viewmodels/reminder_viewmodel.dart';
import '../../providers/viewmodels/routine_viewmodel.dart';
import '../../providers/viewmodels/subtask_viewmodel.dart';
import '../../providers/viewmodels/todo_viewmodel.dart';
import '../../services/application_service.dart';
import '../../util/constants.dart';
import '../../util/enums.dart';
import '../../util/interfaces/i_model.dart';
import '../../util/numbers.dart';
import '../blurred_dialog.dart';
import '../views/sub_views/create_routine.dart';
import '../views/sub_views/create_todo.dart';
import '../views/sub_views/update_deadline.dart';
import '../views/sub_views/update_group.dart';
import '../views/sub_views/update_reminder.dart';
import '../views/sub_views/update_routine.dart';
import '../views/sub_views/update_subtask.dart';
import '../views/sub_views/update_todo.dart';
import 'battery_meter.dart';
import 'dialogs/check_delete_dialog.dart';
import 'dialogs/date_range_dialog.dart';
import 'dialogs/date_time_dialog.dart';
import 'dialogs/duration_dialog.dart';
import 'dialogs/frequency_dialog.dart';
import 'dialogs/time_dialog.dart';
import 'expanded_listtile.dart';
import 'flushbars.dart';
import 'handle_repeatable_modal.dart';
import 'listtile_widgets.dart';
import 'listviews.dart';
import 'paginating_listview.dart';
import 'search_recents_bar.dart';
import 'subtask_quick_entry.dart';
import 'subtitles.dart';

abstract class Tiles {
  /// ListView Tiles
  static Widget toDoListTile(
      {required BuildContext context,
      required int index,
      required ToDo toDo,
      bool smallScreen = false,
      Future<void> Function({required ToDo toDo, required int index})?
          checkboxAnimateBeforeUpdate,
      Future<void> Function({ToDo? item})? onRemove,
      bool showHandle = false,
      bool checkDelete = false}) {
    ToDoProvider toDoProvider = Provider.of(context, listen: false);
    // This is not an ideal solution, but it is to maintain a proper count
    // of linked ToDos.
    GroupProvider groupProvider = Provider.of(context, listen: false);
    EventProvider eventProvider = Provider.of(context, listen: false);

    return ListTile(
        // tileColor: (toDo.myDay)
        //     ? Theme.of(context)
        //         .colorScheme
        //         .primaryContainer
        //         .withOpacity(Constants.tabBarOpacity)
        //     : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Constants.padding),
        key: ValueKey(toDo.id),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        leading: ListTileWidgets.checkbox(
            outerPadding:
                const EdgeInsets.symmetric(horizontal: Constants.halfPadding),
            scale: 1.1,
            completed: toDo.completed,
            onChanged: (bool? value) async {
              toDo.completed = value!;

              if (null != checkboxAnimateBeforeUpdate) {
                await checkboxAnimateBeforeUpdate(toDo: toDo, index: index);
              }

              await toDoProvider.updateToDo(toDo: toDo);
            }),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (Frequency.once != toDo.frequency &&
                RepeatableState.delta != toDo.repeatableState)
              const Padding(
                padding: EdgeInsets.only(right: Constants.halfPadding),
                child: Tooltip(
                    message: "Repeating event",
                    child: Icon(Icons.restart_alt_rounded)),
              ),
            if (RepeatableState.delta == toDo.repeatableState)
              const Padding(
                padding: EdgeInsets.only(right: Constants.halfPadding),
                child: Tooltip(
                    message: "Repeating event: modified",
                    child: Icon(Icons.change_history_rounded)),
              ),
            if (toDo.myDay)
              Padding(
                padding: const EdgeInsets.only(right: Constants.halfPadding),
                child: Icon(
                  Icons.wb_sunny_outlined,
                  size: smallScreen
                      ? Constants.minIconSize
                      : Constants.smIconSize,
                ),
              ),
            Expanded(
              child: AutoSizeText(toDo.name,
                  overflow: TextOverflow.ellipsis,
                  minFontSize: Constants.large,
                  softWrap: false,
                  maxLines: 2),
            ),
          ],
        ),
        subtitle: Subtitles.toDoSubtitle(
            smallScreen: smallScreen,
            context: context,
            groupID: toDo.groupID,
            dueDate: toDo.dueDate,
            priority: toDo.priority,
            onError: () async {
              toDo.groupID = null;
              await toDoProvider.updateToDo(toDo: toDo);
            }),
        onTap: () async {
          Provider.of<ToDoViewModel>(context, listen: false)
              .fromModel(model: toDo);
          await blurredNonDismissible(
              context: context, dialog: const UpdateToDoScreen());
          // await showDialog(
          //     barrierDismissible: false,
          //     useRootNavigator: false,
          //     context: context,
          //     builder: (BuildContext context) {
          //       Provider.of<ToDoViewModel>(context, listen: false)
          //           .fromModel(model: toDo);
          //       return const UpdateToDoScreen();
          //     });
        },
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ListTileWidgets.toDoBatteryRow(toDo: toDo),
          Padding(
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                onPressed: () async {
                  if (!checkDelete) {
                    if (null != onRemove) {
                      return await onRemove(item: toDo).whenComplete(() async {
                        return await deleteToDo(
                            toDo: toDo,
                            context: context,
                            toDoProvider: toDoProvider,
                            groupProvider: groupProvider,
                            eventProvider: eventProvider);
                      });
                    }

                    return await deleteToDo(
                        toDo: toDo,
                        context: context,
                        toDoProvider: toDoProvider,
                        groupProvider: groupProvider,
                        eventProvider: eventProvider);
                  }
                  return await blurredDismissible(
                          context: context,
                          dialog: CheckDeleteDialog(
                              dontAsk: !checkDelete, type: "Task"))
                      // await showDialog<List<bool>?>(
                      //   barrierDismissible: true,
                      //   context: context,
                      //   useRootNavigator: false,
                      //   builder: (BuildContext context) {
                      //     return CheckDeleteDialog(
                      //         dontAsk: !checkDelete, type: "Task");
                      //     // Dialog function.
                      //   })
                      .then((results) async {
                    if (null == results) {
                      return;
                    }
                    toDoProvider.userViewModel?.checkDelete = results[1];
                    if (!results[0]) {
                      return;
                    }

                    if (null != onRemove) {
                      return await onRemove(item: toDo).whenComplete(() async {
                        return await deleteToDo(
                            toDo: toDo,
                            context: context,
                            toDoProvider: toDoProvider,
                            groupProvider: groupProvider,
                            eventProvider: eventProvider);
                      });
                    }

                    return await deleteToDo(
                        toDo: toDo,
                        context: context,
                        toDoProvider: toDoProvider,
                        groupProvider: groupProvider,
                        eventProvider: eventProvider);
                  });
                },
              )),
          if (showHandle)
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle_rounded))
        ]));
  }

  // Helper function to delete ToDos -> migrate to other repeatables.
  static Future<void> deleteToDo({
    required BuildContext context,
    required ToDo toDo,
    ToDoProvider? toDoProvider,
    GroupProvider? groupProvider,
    EventProvider? eventProvider,
  }) async {
    toDoProvider =
        toDoProvider ?? Provider.of<ToDoProvider>(context, listen: false);
    groupProvider =
        groupProvider ?? Provider.of<GroupProvider>(context, listen: false);
    eventProvider =
        eventProvider ?? Provider.of<EventProvider>(context, listen: false);
    // For repeating ToDos.
    if (toDo.frequency != Frequency.once) {
      bool? deleteSingle = await showModalBottomSheet<bool?>(
          showDragHandle: true,
          context: context,
          builder: (BuildContext context) {
            return const HandleRepeatableModal(action: "Delete");
          });

      if (null == deleteSingle) {
        return;
      }

      await toDoProvider
          .handleRepeating(toDo: toDo, single: deleteSingle, delete: true)
          .catchError((e) => displayError(e: e));

      return await eventProvider.updateEventModel(oldModel: toDo);
    }

    await toDoProvider.deleteToDo(toDo: toDo).catchError(
          (e) => displayError(e: e),
        );
    if (null != toDo.groupID) {
      groupProvider.setToDoCount(id: toDo.groupID!);
    }

    return await eventProvider.updateEventModel(oldModel: toDo);
  }

  static Widget toDoMyDayTile({
    required BuildContext context,
    required int index,
    required ToDo toDo,
    bool smallScreen = false,
    Future<void> Function({required ToDo toDo, required int index})?
        checkboxAnimateBeforeUpdate,
    Future<void> Function({ToDo item})? onRemove,
    bool showHandle = false,
  }) {
    ToDoProvider toDoProvider = Provider.of(context, listen: false);
    return ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Constants.padding),
        key: ValueKey(toDo.id ^ index),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        leading: ListTileWidgets.checkbox(
            outerPadding:
                const EdgeInsets.symmetric(horizontal: Constants.halfPadding),
            scale: 1.1,
            completed: toDo.completed,
            onChanged: (bool? value) async {
              toDo.completed = value!;

              if (null != checkboxAnimateBeforeUpdate) {
                await checkboxAnimateBeforeUpdate(toDo: toDo, index: index);
              }

              await toDoProvider.updateToDo(toDo: toDo);
            }),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Frequency.once != toDo.frequency)
              const Icon(Icons.restart_alt_rounded),
            Expanded(
              child: AutoSizeText(toDo.name,
                  overflow: TextOverflow.ellipsis,
                  minFontSize: Constants.large,
                  softWrap: false,
                  maxLines: 2),
            ),
          ],
        ),
        subtitle: Subtitles.toDoSubtitle(
            smallScreen: smallScreen,
            context: context,
            groupID: toDo.groupID,
            dueDate: toDo.dueDate,
            priority: toDo.priority,
            onError: () async {
              toDo.groupID = null;
              await toDoProvider.updateToDo(toDo: toDo);
            }),
        onTap: () async {
          Provider.of<ToDoViewModel>(context, listen: false)
              .fromModel(model: toDo);
          await blurredNonDismissible(
              context: context, dialog: const UpdateToDoScreen());
          // showDialog(
          //     barrierDismissible: false,
          //     useRootNavigator: false,
          //     context: context,
          //     builder: (BuildContext context) {
          //       Provider.of<ToDoViewModel>(context, listen: false)
          //           .fromModel(model: toDo);
          //       return const UpdateToDoScreen();
          //     });
        },
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ListTileWidgets.toDoBatteryRow(toDo: toDo),
          Padding(
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.cloud_off_rounded),
                onPressed: () async {
                  toDo.myDay = false;
                  if (null != onRemove) {
                    await onRemove(item: toDo);
                  }

                  await toDoProvider.updateToDo(toDo: toDo);
                },
              )),
          if (showHandle)
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle_rounded))
        ]));
  }

  static Widget routineListTile(
      {required BuildContext context,
      required int index,
      required Routine routine,
      Future<void> Function({Routine? item})? onRemove,
      bool showHandle = false,
      bool checkDelete = false}) {
    RoutineProvider routineProvider =
        Provider.of<RoutineProvider>(context, listen: false);
    return ListTile(
        contentPadding: const EdgeInsets.only(right: Constants.padding),
        key: ValueKey(routine.id),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        leading: ListTileWidgets.routineIcon(
            currentContext: context,
            outerPadding:
                const EdgeInsets.symmetric(horizontal: Constants.padding),
            times: routineProvider.getRoutineTime(routine: routine),
            handleRoutineTimeChange: ({required int newRoutineTimes}) {
              routineProvider.unsetDailyRoutine(id: routine.id);
              routineProvider.setDailyRoutine(
                  timeOfDay: newRoutineTimes, routine: routine);
            }),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Expanded(
            child: AutoSizeText(routine.name,
                overflow: TextOverflow.ellipsis,
                minFontSize: Constants.large,
                softWrap: false,
                maxLines: 2),
          ),
        ]),
        subtitle: Subtitles.subtaskSubtitle(
            subtaskCount: routineProvider.getSubtaskCount(id: routine.id)),
        onTap: () async {
          Provider.of<RoutineViewModel>(context, listen: false).fromModel(
              model: routine,
              times: routineProvider.getRoutineTime(routine: routine));
          await blurredNonDismissible(
              context: context, dialog: const UpdateRoutineScreen());
          // await showDialog(
          //     barrierDismissible: false,
          //     useRootNavigator: false,
          //     context: context,
          //     builder: (BuildContext context) {
          //       Provider.of<RoutineViewModel>(context, listen: false).fromModel(
          //           model: routine,
          //           times: routineProvider.getRoutineTime(routine: routine));
          //       return const UpdateRoutineScreen();
          //     });
        },
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          ListTileWidgets.routineBatteryRow(routine: routine),
          Padding(
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                onPressed: () async {
                  if (!checkDelete) {
                    if (null != onRemove) {
                      await onRemove(item: routine);
                    }
                    return await routineProvider
                        .deleteRoutine(routine: routine)
                        .catchError((e) => displayError(e: e));
                  }
                  return await blurredDismissible(
                    context: context,
                    dialog: CheckDeleteDialog(
                      dontAsk: !checkDelete,
                      type: "Routine",
                    ),
                  )
                      // showDialog<List<bool>?>(
                      //     barrierDismissible: true,
                      //     useRootNavigator: false,
                      //     context: context,
                      //     builder: (BuildContext context) {
                      //       return CheckDeleteDialog(
                      //           dontAsk: !checkDelete, type: "Routine");
                      //       // Dialog function.
                      //     })
                      .then((results) async {
                    if (null == results) {
                      return;
                    }
                    routineProvider.userViewModel?.checkDelete = results[1];
                    if (!results[0]) {
                      return;
                    }

                    if (null != onRemove) {
                      await onRemove(item: routine);
                    }

                    await routineProvider
                        .deleteRoutine(routine: routine)
                        .catchError((e) => displayError(e: e));
                  });
                },
              )),
          if (showHandle)
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle_rounded))
        ]));
  }

  static Widget deadlineListTile({
    required BuildContext context,
    required int index,
    required Deadline deadline,
    bool smallScreen = false,
    bool showHandle = false,
    bool checkDelete = false,
    Future<void> Function({Deadline? item})? onRemove,
  }) {
    DeadlineProvider deadlineProvider =
        Provider.of<DeadlineProvider>(context, listen: false);
    EventProvider eventProvider = Provider.of(context, listen: false);
    return ListTile(
        contentPadding:
            // Check the padding.
            const EdgeInsets.symmetric(horizontal: Constants.padding),
        key: ValueKey(deadline.id),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        leading: (deadline.warnMe)
            ? ListTileWidgets.deadlineWarnMeIcon(
                currentContext: context,
                outerPadding: const EdgeInsets.symmetric(
                    horizontal: Constants.halfPadding),
                iconPadding: const EdgeInsets.all(Constants.halfPadding))
            : ListTileWidgets.deadlineIcon(
                context: context,
                outerPadding: const EdgeInsets.symmetric(
                    horizontal: Constants.halfPadding),
                iconPadding: const EdgeInsets.all(Constants.halfPadding)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Frequency.once != deadline.frequency &&
                RepeatableState.delta != deadline.repeatableState)
              const Padding(
                padding: EdgeInsets.only(right: Constants.halfPadding),
                child: Tooltip(
                    message: "Repeating event",
                    child: Icon(Icons.restart_alt_rounded)),
              ),
            if (RepeatableState.delta == deadline.repeatableState)
              const Padding(
                padding: EdgeInsets.only(right: Constants.halfPadding),
                child: Tooltip(
                    message: "Repeating event: modified",
                    child: Icon(Icons.change_history_rounded)),
              ),
            Expanded(
              child: AutoSizeText(deadline.name,
                  overflow: TextOverflow.ellipsis,
                  minFontSize: Constants.large,
                  softWrap: false,
                  maxLines: 2),
            ),
          ],
        ),
        subtitle: Subtitles.deadlineSubtitle(
          context: context,
          smallScreen: smallScreen,
          dueDate: deadline.dueDate,
          warnDate: (deadline.warnMe) ? deadline.warnDate : null,
          priority: deadline.priority,
        ),
        onTap: () async {
          Provider.of<DeadlineViewModel>(context, listen: false)
              .fromModel(model: deadline);
          await blurredNonDismissible(
              context: context, dialog: const UpdateDeadlineScreen());
          // await showDialog(
          //     barrierDismissible: false,
          //     useRootNavigator: false,
          //     context: context,
          //     builder: (BuildContext context) {
          //       Provider.of<DeadlineViewModel>(context, listen: false)
          //           .fromModel(model: deadline);
          //       return const UpdateDeadlineScreen();
          //     });
        },
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                onPressed: () async {
                  if (!checkDelete) {
                    if (null != onRemove) {
                      return await onRemove(item: deadline)
                          .whenComplete(() async {
                        return await deleteDeadline(
                          deadline: deadline,
                          context: context,
                          deadlineProvider: deadlineProvider,
                          eventProvider: eventProvider,
                        );
                      });
                    }
                    return await deleteDeadline(
                        deadline: deadline,
                        context: context,
                        deadlineProvider: deadlineProvider,
                        eventProvider: eventProvider);
                  }
                  return await blurredDismissible(
                          context: context,
                          dialog: CheckDeleteDialog(
                            dontAsk: !checkDelete,
                            type: "Deadline",
                          ))
                      // await showDialog<List<bool>?>(
                      //   barrierDismissible: true,
                      //   useRootNavigator: false,
                      //   context: context,
                      //   builder: (BuildContext context) {
                      //     return CheckDeleteDialog(
                      //         dontAsk: !checkDelete, type: "Deadline");
                      //     // Dialog function.
                      //   })
                      .then((results) async {
                    if (null == results) {
                      return;
                    }
                    deadlineProvider.userViewModel?.checkDelete = results[1];
                    if (!results[0]) {
                      return;
                    }

                    if (null != onRemove) {
                      return await onRemove(item: deadline)
                          .whenComplete(() async {
                        return await deleteDeadline(
                          deadline: deadline,
                          context: context,
                          deadlineProvider: deadlineProvider,
                          eventProvider: eventProvider,
                        );
                      });
                    }
                    await deleteDeadline(
                        deadline: deadline,
                        context: context,
                        eventProvider: eventProvider,
                        deadlineProvider: deadlineProvider);
                  });
                },
              )),
          if (showHandle)
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle_rounded))
        ]));
  }

  // Helper function to delete deadlines ->
  static Future<void> deleteDeadline({
    required Deadline deadline,
    required BuildContext context,
    DeadlineProvider? deadlineProvider,
    EventProvider? eventProvider,
  }) async {
    deadlineProvider = deadlineProvider ??
        Provider.of<DeadlineProvider>(context, listen: false);
    eventProvider =
        eventProvider ?? Provider.of<EventProvider>(context, listen: false);
    // For repeating deadlines.
    if (deadline.frequency != Frequency.once) {
      bool? deleteSingle = await showModalBottomSheet<bool?>(
          showDragHandle: true,
          context: context,
          builder: (BuildContext context) {
            return const HandleRepeatableModal(action: "Delete");
          });

      if (null == deleteSingle) {
        return;
      }

      await deadlineProvider
          .handleRepeating(
              deadline: deadline, single: deleteSingle, delete: true)
          .catchError((e) => displayError(e: e));

      return await eventProvider.updateEventModel(oldModel: deadline);
    }

    await deadlineProvider
        .deleteDeadline(deadline: deadline)
        .catchError((e) => displayError(e: e));

    return await eventProvider.updateEventModel(oldModel: deadline);
  }

  static Widget reminderListTile(
      {required BuildContext context,
      required int index,
      required Reminder reminder,
      bool smallScreen = false,
      bool showHandle = false,
      bool checkDelete = false,
      Future<void> Function({Reminder item})? onRemove}) {
    ReminderProvider reminderProvider =
        Provider.of<ReminderProvider>(context, listen: false);
    EventProvider eventProvider = Provider.of(context, listen: false);
    return ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Constants.padding),
        key: ValueKey(reminder.id),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        leading: (Frequency.once != reminder.frequency)
            ? ListTileWidgets.reminderRepeatingIcon(
                currentContext: context,
                outerPadding: const EdgeInsets.symmetric(
                    horizontal: Constants.halfPadding),
                iconPadding: const EdgeInsets.all(Constants.halfPadding))
            : ListTileWidgets.reminderIcon(
                currentContext: context,
                outerPadding: const EdgeInsets.symmetric(
                    horizontal: Constants.halfPadding),
                iconPadding: const EdgeInsets.all(Constants.halfPadding)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Frequency.once != reminder.frequency &&
                RepeatableState.delta != reminder.repeatableState)
              const Padding(
                padding: EdgeInsets.only(right: Constants.halfPadding),
                child: Tooltip(
                    message: "Repeating event",
                    child: Icon(Icons.restart_alt_rounded)),
              ),
            if (RepeatableState.delta == reminder.repeatableState)
              const Padding(
                padding: EdgeInsets.only(right: Constants.halfPadding),
                child: Tooltip(
                    message: "Repeating event: modified",
                    child: Icon(Icons.change_history_rounded)),
              ),
            Expanded(
              child: AutoSizeText(reminder.name,
                  overflow: TextOverflow.ellipsis,
                  minFontSize: Constants.large,
                  softWrap: false,
                  maxLines: 2),
            ),
          ],
        ),
        subtitle: Subtitles.reminderSubtitle(
          smallScreen: smallScreen,
          context: context,
          dueDate: reminder.dueDate,
        ),
        onTap: () async {
          Provider.of<ReminderViewModel>(context, listen: false)
              .fromModel(model: reminder);
          await blurredNonDismissible(
              context: context, dialog: const UpdateReminderScreen());
          // showDialog(
          //     barrierDismissible: false,
          //     useRootNavigator: false,
          //     context: context,
          //     builder: (BuildContext context) {
          //       Provider.of<ReminderViewModel>(context, listen: false)
          //           .fromModel(model: reminder);
          //       return const UpdateReminderScreen();
          //     });
        },
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                onPressed: () async {
                  if (!checkDelete) {
                    if (null != onRemove) {
                      return await onRemove(item: reminder)
                          .whenComplete(() async {
                        return await deleteReminder(
                          reminder: reminder,
                          context: context,
                          reminderProvider: reminderProvider,
                          eventProvider: eventProvider,
                        );
                      });
                    }
                    return await deleteReminder(
                        reminder: reminder,
                        context: context,
                        reminderProvider: reminderProvider,
                        eventProvider: eventProvider);
                  }
                  return await blurredDismissible(
                          context: context,
                          dialog: CheckDeleteDialog(
                              dontAsk: !checkDelete, type: "Reminder"))
                      // await showDialog<List<bool>?>(
                      //   barrierDismissible: true,
                      //   useRootNavigator: false,
                      //   context: context,
                      //   builder: (BuildContext context) {
                      //     return CheckDeleteDialog(
                      //         dontAsk: !checkDelete, type: "Reminder");
                      //     // Dialog function.
                      //   })
                      .then((results) async {
                    if (null == results) {
                      return;
                    }
                    reminderProvider.userViewModel?.checkDelete = results[1];
                    if (!results[0]) {
                      return;
                    }

                    if (null != onRemove) {
                      return await onRemove(item: reminder)
                          .whenComplete(() async {
                        return await deleteReminder(
                            reminder: reminder,
                            context: context,
                            reminderProvider: reminderProvider,
                            eventProvider: eventProvider);
                      });
                    }
                    await deleteReminder(
                        reminder: reminder,
                        context: context,
                        reminderProvider: reminderProvider,
                        eventProvider: eventProvider);
                  });
                },
              )),
          if (showHandle)
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle_rounded))
        ]));
  }

  // Helper function to delete deadlines ->
  static Future<void> deleteReminder({
    required Reminder reminder,
    required BuildContext context,
    ReminderProvider? reminderProvider,
    EventProvider? eventProvider,
  }) async {
    reminderProvider = reminderProvider ??
        Provider.of<ReminderProvider>(context, listen: false);
    EventProvider eventProvider = Provider.of(context, listen: false);

    // For repeating deadlines.
    if (reminder.frequency != Frequency.once) {
      bool? deleteSingle = await showModalBottomSheet<bool?>(
          showDragHandle: true,
          context: context,
          builder: (BuildContext context) {
            return const HandleRepeatableModal(action: "Delete");
          });

      if (null == deleteSingle) {
        return;
      }

      await reminderProvider
          .handleRepeating(
              reminder: reminder, single: deleteSingle, delete: true)
          .catchError((e) => displayError(e: e));

      return await eventProvider.updateEventModel(oldModel: reminder);
    }

    await reminderProvider
        .deleteReminder(reminder: reminder)
        .catchError((e) => displayError(e: e));

    return await eventProvider.updateEventModel(oldModel: reminder);
  }

  static Widget groupListTile(
      {required int index,
      required Group group,
      required BuildContext context,
      void Function({List<ToDo>? items})? onToDoFetch,
      Future<void> Function({ToDo? item})? onToDoRemove,
      Future<void> Function({Group? item})? onRemove,
      bool showHandle = false,
      bool checkDelete = false,
      ScrollPhysics physics = const NeverScrollableScrollPhysics()}) {
    GroupProvider groupProvider =
        Provider.of<GroupProvider>(context, listen: false);
    ToDoProvider toDoProvider =
        Provider.of<ToDoProvider>(context, listen: false);

    return ExpandedListTile(
        key: ValueKey(group.id),
        initiallyExpanded: true,
        leading: ListTileWidgets.groupListViewIcon(onPressed: () async {
          Provider.of<GroupViewModel>(context, listen: false)
              .fromModel(model: group);
          await blurredNonDismissible(
              context: context, dialog: const UpdateGroupScreen());
          // await showDialog(
          //     barrierDismissible: false,
          //     useRootNavigator: false,
          //     context: context,
          //     builder: (BuildContext context) {
          //       Provider.of<GroupViewModel>(context, listen: false)
          //           .fromModel(model: group);
          //       return const UpdateGroupScreen();
          //     });
        }),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                onPressed: () async {
                  if (!checkDelete) {
                    if (null != onRemove) {
                      await onRemove(item: group);
                    }
                    return await groupProvider.deleteGroup(group: group);
                  }
                  return await blurredDismissible(
                          context: context,
                          dialog: CheckDeleteDialog(
                            dontAsk: !checkDelete,
                            type: "Group",
                          ))
                      // await showDialog<List<bool>?>(
                      //   barrierDismissible: true,
                      //   useRootNavigator: false,
                      //   context: context,
                      //   builder: (BuildContext context) {
                      //     return CheckDeleteDialog(
                      //         dontAsk: !checkDelete, type: "Group");
                      //     // Dialog function.
                      //   })
                      .then((results) async {
                    if (null == results) {
                      return;
                    }
                    groupProvider.userViewModel?.checkDelete = results[1];
                    if (!results[0]) {
                      return;
                    }

                    if (null != onRemove) {
                      await onRemove(item: group);
                    }

                    await groupProvider.deleteGroup(group: group);
                  });
                },
              )),
          if (showHandle)
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle_rounded))
        ]),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                minFontSize: Constants.large,
              ),
            ),
          ],
        ),
        subtitle: Subtitles.groupSubtitle(
            toDoCount: groupProvider.getToDoCount(id: group.id)!),
        children: [
          // ValueKey will always be 0, as this list doesn't change ordering.
          // new items will fade in accordingly.
          PaginatingListview<ToDo>(
            items: group.toDos,
            query: (
                {int limit = Constants.minLimitPerQuery,
                int offset = 0}) async {
              return await groupProvider.getToDosByGroupID(
                  id: group.id, limit: limit, offset: offset);
            },
            pullToRefresh: false,
            offset: group.toDos.length,
            onFetch: onToDoFetch,
            onRemove: onToDoRemove,
            rebuildNotifiers: [toDoProvider],
            rebuildCallback: ({required List<ToDo> items}) {
              groupProvider.setToDoCount(id: group.id, count: items.length);
            },
            listviewBuilder: (
                {Key? key,
                required BuildContext context,
                required List<ToDo> items,
                Future<void> Function({ToDo item})? onRemove}) {
              return ListViews.reorderableGroupToDos(
                  key: key,
                  context: context,
                  toDos: items,
                  physics: physics,
                  onChanged: ({ToDo? toDo, bool? value}) async {
                    if (null == toDo) {
                      return;
                    }
                    toDo.completed = value!;
                    await toDoProvider.updateToDo(toDo: toDo);
                  },
                  onTap: ({ToDo? toDo}) async {
                    if (null == toDo) {
                      return;
                    }
                    Provider.of<ToDoViewModel>(context, listen: false)
                        .fromModel(model: toDo);
                    await blurredNonDismissible(
                        context: context, dialog: const UpdateToDoScreen());
                    // await showDialog(
                    //     barrierDismissible: false,
                    //     useRootNavigator: false,
                    //     context: context,
                    //     builder: (BuildContext context) {
                    //       Provider.of<ToDoViewModel>(context, listen: false)
                    //           .fromModel(model: toDo);
                    //
                    //       return const UpdateToDoScreen();
                    //     });
                  },
                  handleRemove: ({ToDo? toDo}) async {
                    if (null == toDo) {
                      return;
                    }
                    if (null != onRemove) {
                      await onRemove(item: toDo);
                    }

                    toDo.groupIndex = -1;
                    toDo.groupID = null;
                    await toDoProvider.updateToDo(toDo: toDo);
                  });
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SearchRecentsBar<ToDo>(
                  dispose: true,
                  border: BorderSide.none,
                  clearOnSelection: true,
                  hintText: "Search Tasks",
                  padding: const EdgeInsets.all(Constants.padding),
                  handleDataSelection: ({required int id}) async {
                    await groupToDoDataSelection(
                        toDoID: id,
                        groupID: group.id,
                        context: context,
                        toDoProvider: toDoProvider);
                  },
                  mostRecent: toDoProvider.mostRecent,
                  search: toDoProvider.searchToDos,
                ),
              ),
            ],
          ),
          addTile(
              title: "New Task",
              onTap: () async {
                await blurredNonDismissible(
                  context: context,
                  dialog: CreateToDoScreen(
                    initialGroup: MapEntry<String, int>(group.name, group.id),
                  ),
                );
                // await showDialog(
                //     barrierDismissible: false,
                //     useRootNavigator: false,
                //     context: context,
                //     builder: (BuildContext context) => CreateToDoScreen(
                //           initialGroup:
                //               MapEntry<String, int>(group.name, group.id),
                //         ));
              })
        ]);
  }

  // Helper method for groupListTile.
  static Future<void> groupToDoDataSelection(
      {required int toDoID,
      required int groupID,
      required BuildContext context,
      ToDoProvider? toDoProvider}) async {
    toDoProvider =
        toDoProvider ?? Provider.of<ToDoProvider>(context, listen: false);
    ToDo? toDo = await toDoProvider.getToDoByID(id: toDoID).catchError((_) {
      Flushbar? error;

      error = Flushbars.createError(
        message: "Error with Task Retrieval",
        context: context,
        dismissCallback: () => error?.dismiss(),
      );

      error.show(context);
      return null;
    });

    if (null == toDo) {
      return;
    }
    if (groupID == toDo.groupID) {
      return;
    }
    toDo.groupID = groupID;
    await toDoProvider.updateToDo(toDo: toDo);
  }

  static Widget navDrawerGroupTile({
    required BuildContext context,
    required Group group,
    EdgeInsetsGeometry innerTilePadding =
        const EdgeInsets.symmetric(horizontal: Constants.doublePadding),
  }) {
    GroupProvider groupProvider =
        Provider.of<GroupProvider>(context, listen: false);
    return ListTile(
      contentPadding: innerTilePadding,
      leading: const Icon(Icons.collections_bookmark_outlined),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(Constants.semiCircular))),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: AutoSizeText(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              minFontSize: Constants.large,
            ),
          ),
        ],
      ),
      onTap: () async {
        Provider.of<GroupViewModel>(context, listen: false)
            .fromModel(model: group);
        await blurredNonDismissible(
            context: context, dialog: const UpdateGroupScreen());
        // await showDialog(
        //     barrierDismissible: false,
        //     useRootNavigator: false,
        //     context: context,
        //     builder: (BuildContext context) {
        //       Provider.of<GroupViewModel>(context, listen: false)
        //           .fromModel(model: group);
        //       return const UpdateGroupScreen();
        //     });
      },
      trailing: Subtitles.groupSubtitle(
          toDoCount: groupProvider.getToDoCount(id: group.id)!),
    );
  }

  /// Checkboxes
  static Widget checkboxListTile({
    Key? key,
    EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
    Widget? title,
    required void Function(bool? value) onChanged,
    void Function()? onTap,
    bool value = false,
    Widget? trailing,
  }) =>
      ListTile(
          leading: ListTileWidgets.checkbox(
            completed: value,
            onChanged: onChanged,
          ),
          onTap: onTap,
          contentPadding: contentPadding,
          key: key,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.semiCircular))),
          title: title,
          trailing: trailing);

  static Widget subtaskCheckboxTile(
          {required int index,
          required Subtask subtask,
          required void Function(bool? value) onChanged,
          void Function()? onTap,
          void Function()? onRemoved,
          bool showHandle = false}) =>
      checkboxListTile(
          key: ValueKey(subtask.id),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: Constants.padding),
          onChanged: onChanged,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: AutoSizeText(subtask.name,
                    overflow: TextOverflow.ellipsis,
                    minFontSize: Constants.large,
                    softWrap: false,
                    maxLines: 2),
              ),
            ],
          ),
          onTap: onTap,
          value: subtask.completed,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Constants.batteryIcons[subtask.weight * 2]!,
              AutoSizeText(
                "${subtask.weight}",
                overflow: TextOverflow.visible,
                minFontSize: Constants.large,
                softWrap: false,
                maxLines: 1,
              ),
              Padding(
                padding: EdgeInsets.zero,
                child: IconButton(
                    visualDensity: VisualDensity.adaptivePlatformDensity,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: onRemoved),
              ),
              if (showHandle)
                ReorderableDragStartListener(
                    index: index, child: const Icon(Icons.drag_handle_rounded))
            ],
          ));

  static Widget toDoCheckTile({
    required int index,
    required ToDo toDo,
    bool showHandle = false,
    required void Function(bool?) onChanged,
    void Function()? onTap,
    void Function()? handleRemove,
  }) {
    return checkboxListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Constants.doublePadding),
        key: ValueKey(toDo.id),
        value: toDo.completed,
        onChanged: onChanged,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText(toDo.name,
                  overflow: TextOverflow.ellipsis,
                  minFontSize: Constants.large,
                  softWrap: false,
                  maxLines: 2),
            ),
          ],
        ),
        onTap: onTap,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Constants.batteryIcons[(toDo.taskType == TaskType.small)
                ? toDo.weight
                : remap(
                        x: toDo.weight,
                        inMin: 0,
                        inMax: Constants.medianWeight,
                        outMin: 0,
                        outMax: 5)
                    .toInt()]!,
            Flexible(
              child: AutoSizeText(
                "${toDo.weight}",
                overflow: TextOverflow.visible,
                minFontSize: Constants.large,
                softWrap: false,
                maxLines: 1,
              ),
            ),
          ]),
          Padding(
              padding: EdgeInsets.zero,
              child: IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: handleRemove,
              )),
          if (showHandle)
            ReorderableDragStartListener(
                index: index, child: const Icon(Icons.drag_handle_rounded))
        ]));
  }

  // SUBTASK EXPANSION TILES
  static Widget subtasksTile({
    Widget? leading,
    Widget? trailing,
    String? title,
    required BuildContext context,
    required int id,
    int limit = Constants.maxNumTasks,
    required List<Subtask> subtasks,
    required ValueNotifier<int> subtaskCount,
    Future<void> Function({Subtask? item})? onRemove,
    MenuController? subtasksAnchorController,
    void Function()? onAnchorOpen,
    void Function()? onAnchorClose,
    void Function({bool expanded})? onExpansionChanged,
    bool initiallyExpanded = false,
    ScrollPhysics physics = const NeverScrollableScrollPhysics(),
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    SubtaskViewModel? vm,
  }) {
    SubtaskProvider subtaskProvider =
        Provider.of<SubtaskProvider>(context, listen: false);
    return ExpandedListTile(
        initiallyExpanded: initiallyExpanded,
        onExpansionChanged: onExpansionChanged,
        leading: leading,
        outerPadding: outerPadding,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText(title ?? "Steps",
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  minFontSize: Constants.small),
            ),
          ],
        ),
        subtitle: Subtitles.subtaskSubtitle(subtaskCount: subtaskCount),
        trailing: trailing,
        children: [
          ListViews.reorderableSubtasks(
              physics: physics,
              context: context,
              subtasks: subtasks,
              itemCount: subtasks.length,
              onTap: ({Subtask? subtask}) async {
                if (null == subtask) {
                  return;
                }
                Provider.of<SubtaskViewModel>(context, listen: false)
                    .fromModel(model: subtask);
                await blurredNonDismissible(
                    context: context, dialog: const UpdateSubtaskScreen());
              },
              onChanged: ({bool? value, Subtask? subtask}) async {
                if (null == subtask) {
                  return;
                }
                subtask.completed = value!;
                await subtaskProvider
                    .updateSubtask(subtask: subtask)
                    .catchError((e) => displayError(e: e));
              },
              onRemoved: ({Subtask? subtask}) async {
                if (null == subtask) {
                  return;
                }

                if (null != onRemove) {
                  await onRemove(item: subtask);
                }

                await subtaskProvider
                    .deleteSubtask(subtask: subtask)
                    .catchError((e) => displayError(e: e));
              },
              onReorder: (int oldIndex, int newIndex) async {
                await subtaskProvider
                    .reorderSubtasks(
                        subtasks: subtasks,
                        oldIndex: oldIndex,
                        newIndex: newIndex)
                    .catchError((e) {
                  displayError(e: e);
                  return subtasks;
                });
              }),
          if (subtasks.length < limit)
            SubtaskQuickEntry(
              viewModel: vm,
              taskID: id,
              outerPadding: const EdgeInsets.all(Constants.padding),
              innerPadding: const EdgeInsets.symmetric(
                  horizontal: Constants.doublePadding),
              hintText: "Add step",
              menuController: subtasksAnchorController,
              onOpen: onAnchorOpen,
              onClose: onAnchorClose,
            )
        ]);
  }

  // MYDAY ROUTINE EXPANSION TILES

  static Widget emptyRoutineTile({
    required BuildContext context,
    int times = 0,
    bool initiallyExpanded = false,
    void Function({bool expanded})? onExpansionChanged,
  }) {
    RoutineProvider routineProvider =
        Provider.of<RoutineProvider>(context, listen: false);

    String type = switch (times) {
      1 => "Morning",
      2 => "Afternoon",
      4 => "Evening",
      _ => "",
    };

    return ExpandedListTile(
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      leading: ListTileWidgets.myDayRoutineIcon(times: times, onPressed: null),
      title: Padding(
        padding: const EdgeInsets.symmetric(vertical: Constants.padding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText("$type Routine",
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  minFontSize: Constants.large),
            ),
          ],
        ),
      ),
      children: [
        SearchRecentsBar<Routine>(
          border: BorderSide.none,
          clearOnSelection: true,
          dispose: true,
          handleDataSelection: ({required int id}) async {
            Routine? routine = await routineProvider.getRoutineByID(id: id);
            if (null == routine) {
              return;
            }
            routineProvider.setDailyRoutine(timeOfDay: times, routine: routine);
          },
          mostRecent: routineProvider.mostRecent,
          search: routineProvider.searchRoutines,
          hintText: "Search Routines",
        ),
        addTile(
            title: "New Routine",
            onTap: () async {
              await blurredNonDismissible(
                  context: context, dialog: CreateRoutineScreen(times: times));
              // await showDialog(
              //     context: context,
              //     barrierDismissible: false,
              //     useRootNavigator: false,
              //     builder: (BuildContext context) {
              //       Provider.of<RoutineViewModel>(context, listen: false)
              //           .initRoutineTimes = times;
              //       return const CreateRoutineScreen();
              //     });
            }),
      ],
    );
  }

  static Widget filledRoutineTile({
    required BuildContext context,
    required Routine routine,
    Future<void> Function({Subtask? item})? onSubtaskRemove,
    void Function({bool expanded})? onExpansionChanged,
    ScrollPhysics physics = const NeverScrollableScrollPhysics(),
    int times = 0,
    int vmIndex = 0,
    bool initiallyExpanded = false,
  }) {
    RoutineProvider routineProvider =
        Provider.of<RoutineProvider>(context, listen: false);
    return subtasksTile(
      vm: routineProvider.dailyRoutineTaskViewModels[vmIndex],
      id: routine.id,
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      subtaskCount: routineProvider.getSubtaskCount(id: routine.id),
      subtasks: routine.subtasks,
      context: context,
      onRemove: onSubtaskRemove,
      leading: ListTileWidgets.myDayRoutineIcon(
          times: times,
          routine: routine,
          onPressed: () async {
            Provider.of<RoutineViewModel>(context, listen: false).fromModel(
                model: routine,
                times: routineProvider.getRoutineTime(routine: routine));
            await blurredNonDismissible(
                context: context, dialog: const UpdateRoutineScreen());
            // await showDialog(
            //     context: context,
            //     barrierDismissible: false,
            //     useRootNavigator: false,
            //     builder: (BuildContext context) {
            //       Provider.of<RoutineViewModel>(context, listen: false)
            //           .fromModel(
            //               model: routine,
            //               times:
            //                   routineProvider.getRoutineTime(routine: routine));
            //       return const UpdateRoutineScreen();
            //     });
          }),
      title: routine.name,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "Reset routine",
              onPressed: () async => await routineProvider
                  .resetRoutineSubtasks(routine: routine)
                  .catchError((e) => displayError(e: e))),
          IconButton(
            tooltip: "Remove routine",
            icon: const Icon(Icons.remove_circle_outline_rounded),
            onPressed: () {
              switch (times) {
                case 1:
                  routineProvider.curMorning = null;
                  break;
                case 2:
                  routineProvider.curAfternoon = null;
                  break;
                case 4:
                  routineProvider.curEvening = null;
                  break;
                default:
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  static Widget trashTile({
    required BuildContext context,
    required IModel model,
    bool smallScreen = false,
    bool showCategory = false,
    void Function()? onTap,
    void Function()? restoreModel,
    void Function()? deleteModel,
    Future<void> Function({IModel? item})? onRemove,
  }) =>
      ListTile(
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        leading: IconButton.outlined(
          tooltip: "Restore item",
          icon: const Icon(Icons.settings_backup_restore_rounded),
          onPressed: () async {
            if (null != onRemove) {
              await onRemove(item: model);
            }
            if (null != restoreModel) {
              restoreModel();
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText(
                  "${(showCategory) ? "${toBeginningOfSentenceCase(model.modelType.name)}: " : ""}${model.name}",
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  minFontSize: Constants.large),
            ),
          ],
        ),
        subtitle: switch (model.modelType) {
          ModelType.task => Subtitles.toDoSubtitle(
              groupID: (model as ToDo).groupID,
              dueDate: model.dueDate,
              smallScreen: smallScreen,
              context: context,
              onError: () async {
                model.groupID = null;
                await Provider.of<ToDoProvider>(context, listen: false)
                    .updateToDo(toDo: model);
              },
              priority: model.priority),
          ModelType.routine => Subtitles.subtaskSubtitle(
              subtaskCount: Provider.of<RoutineProvider>(context, listen: false)
                  .getSubtaskCount(id: model.id),
            ),
          ModelType.deadline => Subtitles.deadlineSubtitle(
              context: context,
              dueDate: (model as Deadline).dueDate,
              smallScreen: smallScreen,
              warnDate: model.warnDate,
              priority: model.priority,
            ),
          ModelType.reminder => Subtitles.reminderSubtitle(
              context: context,
              dueDate: (model as Reminder).dueDate,
              smallScreen: smallScreen,
            ),
          ModelType.group => Subtitles.groupSubtitle(
              toDoCount: Provider.of<GroupProvider>(context, listen: false)
                  .getToDoCount(id: model.id)!,
            ),
          _ => null,
        },
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ModelType.task == model.modelType)
              ListTileWidgets.toDoBatteryRow(toDo: model as ToDo),
            if (ModelType.routine == model.modelType)
              ListTileWidgets.routineBatteryRow(routine: model as Routine),
            IconButton(
              tooltip: "Delete permanently",
              icon: const Icon(Icons.delete_forever_rounded),
              onPressed: () async {
                if (null != onRemove) {
                  await onRemove(item: model);
                }
                if (null != deleteModel) {
                  deleteModel();
                }
              },
            ),
          ],
        ),
      );

  /// Model Parameter Tiles
  // NAME
  static Widget nameTile({
    required BuildContext context,
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    EdgeInsetsGeometry textFieldPadding = EdgeInsets.zero,
    Widget? leading,
    String? hintText = "",
    String? errorText,
    String? labelText,
    TextEditingController? controller,
    required void Function() handleClear,
    void Function(String)? onChanged,
    required void Function() onEditingComplete,
  }) =>
      Padding(
        padding: outerPadding,
        child: Row(
          children: [
            if (null != leading) leading,
            Expanded(
              child: Padding(
                padding: textFieldPadding,
                child: AutoSizeTextField(
                  maxLines: 1,
                  minFontSize: Constants.huge,
                  decoration: InputDecoration(
                    suffixIcon: (controller?.text.isNotEmpty ?? false)
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: handleClear)
                        : null,
                    contentPadding:
                        const EdgeInsets.all(Constants.doublePadding),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                            Radius.circular(Constants.semiCircular)),
                        borderSide: BorderSide(
                          width: 2,
                          color: Theme.of(context).colorScheme.outlineVariant,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )),
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(
                            Radius.circular(Constants.semiCircular)),
                        borderSide: BorderSide(
                          strokeAlign: BorderSide.strokeAlignOutside,
                        )),
                    hintText: hintText,
                    errorText: errorText,
                    labelText: labelText,
                  ),
                  onTap: () {
                    Scrollable.ensureVisible(context,
                        duration: Constants.scrollDuration,
                        curve: Constants.scrollCurve);
                  },
                  controller: controller,
                  onEditingComplete: () {
                    onEditingComplete();
                    FocusScope.of(context).unfocus();
                  },
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      );

  // WEIGHT
  static Widget weightTile({
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    EdgeInsetsGeometry batteryPadding = EdgeInsets.zero,
    required double weight,
    required double max,
    Widget? slider,
    BoxConstraints constraints = const BoxConstraints(),
  }) =>
      Column(children: [
        Padding(
          padding: outerPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: AutoSizeText("Energy Drain: ",
                    minFontSize: Constants.medium,
                    maxLines: 1,
                    softWrap: true,
                    style: Constants.hugeHeaderStyle),
              ),
              Flexible(
                child: Padding(
                  padding: batteryPadding,
                  child: BatteryMeter(
                    weight: weight,
                    max: max,
                    constraints: constraints,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (null != slider) slider,
      ]);

  // WEIGHT SLIDERS
  static Widget weightSlider(
          {required double weight,
          int? divisions = Constants.maxTaskWeight,
          double max = Constants.maxTaskWeightDouble,
          void Function(double? value)? handleWeightChange,
          void Function(double? value)? onChangeEnd}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Icon(Icons.battery_full),
          Expanded(
            child: Slider(
              value: weight,
              min: 0.0,
              max: max,
              label:
                  "${weight.toInt()} ${(weight > (Constants.maxTaskWeight / 2).floor()) ? Constants.lowBattery : Constants.fullBattery}",
              divisions: divisions,
              onChanged: handleWeightChange,
              onChangeEnd: onChangeEnd,
            ),
          ),
          const Icon(Icons.battery_1_bar),
        ],
      );

  // TODO: Add keybind to set via number key on focus.
  static Widget weightAnchor({
    required double weight,
    double max = Constants.maxTaskWeightDouble,
    int? divisions = Constants.maxTaskWeight,
    MenuController? controller,
    bool subtask = false,
    void Function(double? value)? handleWeightChange,
    void Function(double? value)? onChangeEnd,
    void Function()? onOpen,
    void Function()? onClose,
  }) {
    return MenuAnchor(
        onOpen: onOpen,
        onClose: onClose,
        style: const MenuStyle(
            alignment: AlignmentDirectional(-10, 1.1),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                    Radius.circular(Constants.semiCircular))))),
        controller: controller,
        menuChildren: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
            child: weightSlider(
                weight: weight,
                max: max,
                divisions: divisions,
                handleWeightChange: handleWeightChange,
                onChangeEnd: onChangeEnd),
          )
        ],
        builder:
            (BuildContext context, MenuController controller, Widget? child) {
          return IconButton(
              icon: (subtask)
                  ? Constants.batteryIcons[weight.toInt() * 2]!
                  : Constants.batteryIcons[weight.toInt()]!,
              onPressed: () {
                if (controller.isOpen) {
                  return controller.close();
                }
                controller.open();
              });
        });
  }

  // DESCRIPTION
  static Widget descriptionTile(
          {TextEditingController? controller,
          EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
          String hintText = "Description",
          int maxLines = Constants.mobileMaxLinesBeforeScroll,
          int minLines = Constants.mobileMinLines,
          double? minFontSize,
          bool isDense = false,
          required BuildContext context,
          required void Function() onEditingComplete}) =>
      Padding(
        padding: outerPadding,
        child: AutoSizeTextField(
            controller: controller,
            maxLines: maxLines,
            minLines: minLines,
            onChanged: (_) {
              Scrollable.ensureVisible(context,
                  duration: Constants.scrollDuration,
                  curve: Constants.scrollCurve);
            },
            onTap: () {
              Scrollable.ensureVisible(context,
                  duration: Constants.scrollDuration,
                  curve: Constants.scrollCurve);
            },
            minFontSize: minFontSize ?? Constants.large,
            decoration: InputDecoration(
              isDense: isDense,
              contentPadding: const EdgeInsets.all(Constants.doublePadding),
              hintText: hintText,
              enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(
                      Radius.circular(Constants.roundedCorners)),
                  borderSide: BorderSide(
                    width: 2,
                    color: Theme.of(context).colorScheme.outlineVariant,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  )),
              border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                      Radius.circular(Constants.roundedCorners)),
                  borderSide: BorderSide(
                    strokeAlign: BorderSide.strokeAlignOutside,
                  )),
            ),
            onEditingComplete: onEditingComplete),
      );

  // DURATION
  static Widget durationTile(
      {int expectedDuration = 0,
      int realDuration = 0,
      required BuildContext context,
      EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
      required void Function() handleClear,
      required void Function(int? value) handleUpdate}) {
    return Padding(
      padding: outerPadding,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: Constants.doublePadding),
        leading: const Icon(Icons.timer_outlined),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        title: (expectedDuration > 0)
            ? Row(
                children: [
                  Flexible(
                    child: Tooltip(
                      message: "Expected",
                      child: AutoSizeText(
                          Duration(seconds: expectedDuration)
                              .toString()
                              .split(".")
                              .first,
                          overflow: TextOverflow.visible,
                          minFontSize: Constants.large,
                          maxLines: 1,
                          softWrap: false),
                    ),
                  ),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: Constants.padding),
                    child: Icon(
                      Icons.timer_rounded,
                    ),
                  ),
                  Flexible(
                    child: Tooltip(
                      message: "Projected",
                      child: AutoSizeText(
                          Duration(seconds: realDuration)
                              .toString()
                              .split(".")
                              .first,
                          overflow: TextOverflow.visible,
                          minFontSize: Constants.large,
                          maxLines: 1,
                          softWrap: true),
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: AutoSizeText("Expected Duration: ",
                        overflow: TextOverflow.visible,
                        minFontSize: Constants.small,
                        maxLines: 2,
                        softWrap: true),
                  ),
                ],
              ),
        trailing: (expectedDuration > 0)
            ? IconButton(
                icon: const Icon(Icons.clear_rounded), onPressed: handleClear)
            : null,
        onTap: () async => await blurredDismissible<int?>(
                context: context,
                dialog: DurationDialog(duration: expectedDuration))
            // showDialog<int>(
            //     useRootNavigator: false,
            //     context: context,
            //     builder: (BuildContext context) =>
            //         DurationDialog(duration: expectedDuration))
            .then(handleUpdate),
      ),
    );
  }

  // START-DUE DATES
  static Widget dateRangeTile({
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    required BuildContext context,
    DateTime? startDate,
    DateTime? dueDate,
    required void Function() handleClear,
    required void Function(
            {bool? checkClose, DateTime? newStart, DateTime? newDue})
        handleUpdate,
  }) =>
      Padding(
        padding: outerPadding,
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: Constants.doublePadding),
          leading: const Icon(Icons.today_rounded),
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.semiCircular))),
          title: (null == startDate && null == dueDate)
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: AutoSizeText(
                        "Add Dates",
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        maxLines: 2,
                        minFontSize: Constants.small,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    (null == startDate)
                        ? const Flexible(
                            child: AutoSizeText(
                              "Start?",
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              maxLines: 2,
                              minFontSize: Constants.small,
                            ),
                          )
                        : Flexible(
                            child: Tooltip(
                            message: "Start Date",
                            child: AutoSizeText(
                                Jiffy.parseFromDateTime(startDate)
                                    .toLocal()
                                    .format(
                                      pattern: "MMM d",
                                    ),
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                maxLines: 1,
                                minFontSize: Constants.huge),
                          )),
                    (null == dueDate)
                        ? const Flexible(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: Constants.padding),
                              child: Icon(Icons.today_rounded),
                            ),
                          )
                        : const Flexible(
                            child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: Constants.padding),
                            child: Icon(Icons.event_rounded),
                          )),
                    (null == dueDate)
                        ? const Flexible(
                            child: AutoSizeText(
                              "Due?",
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              maxLines: 2,
                              minFontSize: Constants.small,
                            ),
                          )
                        : Flexible(
                            child: Tooltip(
                              message: "Due Date",
                              child: AutoSizeText(
                                  Jiffy.parseFromDateTime(dueDate)
                                      .toLocal()
                                      .format(pattern: "MMM d"),
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  maxLines: 1,
                                  minFontSize: Constants.huge),
                            ),
                          )
                  ],
                ),
          trailing: (startDate != null || dueDate != null)
              ? IconButton(
                  icon: const Icon(Icons.clear), onPressed: handleClear)
              : null,
          onTap: () async {
            await blurredDismissible<List<DateTime?>?>(
                    context: context,
                    dialog:
                        DateRangeDialog(startDate: startDate, dueDate: dueDate))
                // await showDialog<List<DateTime?>?>(
                //     useRootNavigator: false,
                //     context: context,
                //     builder: (BuildContext context) {
                //       return DateRangeDialog(
                //           startDate: startDate, dueDate: dueDate);
                //     })
                .then((newDates) {
              if (null == newDates) {
                return handleUpdate(newStart: startDate, newDue: dueDate);
              }
              return handleUpdate(
                  newStart: newDates[0], newDue: newDates[1], checkClose: true);
            });
          },
        ),
      );

  // TIME
  static Widget timeTile({
    TimeOfDay? startTime,
    TimeOfDay? dueTime,
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    required BuildContext context,
    required void Function() handleClear,
    required void Function(
            {bool checkClose, TimeOfDay? newStart, TimeOfDay? newDue})
        handleUpdate,
  }) =>
      Padding(
        padding: outerPadding,
        child: ListTile(
            contentPadding:
                const EdgeInsets.only(left: Constants.doublePadding),
            leading: const Icon(Icons.schedule_rounded),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.all(Radius.circular(Constants.semiCircular))),
            title: (null == startTime && null == dueTime)
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AutoSizeText(
                        "Add Times",
                        overflow: TextOverflow.visible,
                        minFontSize: Constants.large,
                        maxLines: 2,
                        softWrap: true,
                      ),
                    ],
                  )
                : Row(children: [
                    (null == startTime)
                        ? const Flexible(
                            child: AutoSizeText(
                            "Start?",
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            maxLines: 1,
                            minFontSize: Constants.huge,
                          ))
                        : Flexible(
                            child: AutoSizeText(
                            startTime.format(context).toString(),
                            softWrap: false,
                            overflowReplacement: AutoSizeText(
                              startTime
                                  .format(context)
                                  .toString()
                                  .replaceAll("M", ""),
                              minFontSize: Constants.huge,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                            ),
                            maxLines: 1,
                            minFontSize: Constants.huge,
                          )),
                    (null == dueTime)
                        ? const Flexible(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: Constants.padding),
                              child: Icon(Icons.history_toggle_off_rounded),
                            ),
                          )
                        : const Flexible(
                            child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: Constants.padding),
                            child: Icon(Icons.schedule_rounded),
                          )),
                    (null == dueTime)
                        ? const Flexible(
                            child: AutoSizeText(
                              "Due?",
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              maxLines: 1,
                              minFontSize: Constants.huge,
                            ),
                          )
                        : Flexible(
                            child: AutoSizeText(
                              dueTime.format(context).toString(),
                              softWrap: false,
                              overflowReplacement: AutoSizeText(
                                dueTime
                                    .format(context)
                                    .toString()
                                    .replaceAll("M", ""),
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                minFontSize: Constants.huge,
                              ),
                              maxLines: 1,
                              minFontSize: Constants.huge,
                            ),
                          ),
                  ]),
            onTap: () async {
              await blurredDismissible<List<TimeOfDay?>?>(
                      context: context,
                      dialog:
                          TimeDialog(startTime: startTime, dueTime: dueTime))
                  // await showDialog<List<TimeOfDay?>?>(
                  //     useRootNavigator: false,
                  //     context: context,
                  //     builder: (BuildContext context) {
                  //       return TimeDialog(startTime: startTime, dueTime: dueTime);
                  //     })
                  .then((newTimes) {
                if (null == newTimes) {
                  return handleUpdate(newStart: startTime, newDue: dueTime);
                }
                return handleUpdate(
                    newStart: newTimes[0],
                    newDue: newTimes[1],
                    checkClose: true);
              });
            },
            trailing: (startTime != null || dueTime != null)
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: handleClear,
                  )
                : null),
      );

  // SINGLE DATETIME TILE
  static Widget singleDateTimeTile({
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    required BuildContext context,
    Widget? leading,
    DateTime? date,
    TimeOfDay? time,
    bool useAlertIcon = false,
    bool showDate = false,
    String unsetDateText = "",
    String unsetTimeText = "",
    String dialogHeader = "",
    required void Function() handleClear,
    required void Function(
            {bool? checkClose, DateTime? newDate, TimeOfDay? newTime})
        handleUpdate,
  }) =>
      Padding(
        padding: outerPadding,
        child: ListTile(
            contentPadding:
                const EdgeInsets.only(left: Constants.doublePadding),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.all(Radius.circular(Constants.semiCircular))),
            leading: (useAlertIcon)
                ? ListTileWidgets.alertIconButton(
                    warn: showDate,
                    onTap: () async {
                      await blurredDismissible<Map<String, dynamic>?>(
                              context: context,
                              dialog: DateTimeDialog(
                                header: dialogHeader,
                                date: date,
                                time: time,
                              ))
                          // await showDialog<Map<String, dynamic>?>(
                          //     useRootNavigator: false,
                          //     context: context,
                          //     builder: (BuildContext context) {
                          //       return DateTimeDialog(
                          //         header: dialogHeader,
                          //         date: date,
                          //         time: time,
                          //       );
                          //     })
                          .then((newDateTime) {
                        if (null == newDateTime) {
                          return handleUpdate(newDate: date, newTime: time);
                        }
                        return handleUpdate(
                            newDate: newDateTime["date"],
                            newTime: newDateTime["time"],
                            checkClose: true);
                      });
                    })
                : leading,
            title: (showDate && null != date)
                ? Row(children: [
                    Flexible(
                      child: AutoSizeText(
                        Jiffy.parseFromDateTime(date).format(pattern: "MMM d"),
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        maxLines: 1,
                        minFontSize: Constants.huge,
                      ),
                    ),
                    (null != time)
                        ? const Flexible(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: Constants.padding),
                              child: Icon(Icons.schedule_outlined),
                            ),
                          )
                        : const Flexible(
                            child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: Constants.padding),
                            child: Icon(Icons.history_toggle_off_outlined),
                          )),
                    (null != time)
                        ? Flexible(
                            child: AutoSizeText(
                              time.format(context).toString(),
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              maxLines: 1,
                              minFontSize: Constants.huge,
                            ),
                          )
                        : Flexible(
                            child: AutoSizeText(
                              unsetTimeText,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              minFontSize: Constants.medium,
                              maxLines: 1,
                            ),
                          ),
                  ])
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: AutoSizeText(
                          unsetDateText,
                          overflow: TextOverflow.visible,
                          softWrap: true,
                          minFontSize: Constants.medium,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
            onTap: () async {
              await blurredDismissible<Map<String, dynamic>?>(
                      context: context,
                      dialog: DateTimeDialog(
                        header: dialogHeader,
                        date: date,
                        time: time,
                      ))
                  // await showDialog<Map<String, dynamic>?>(
                  //     useRootNavigator: false,
                  //     context: context,
                  //     builder: (BuildContext context) {
                  //       return DateTimeDialog(
                  //         header: dialogHeader,
                  //         date: date,
                  //         time: time,
                  //       );
                  //     })
                  .then((newDateTime) {
                if (null == newDateTime) {
                  return handleUpdate(newDate: date, newTime: time);
                }
                return handleUpdate(
                    newDate: newDateTime["date"],
                    newTime: newDateTime["time"],
                    checkClose: true);
              });
            },
            trailing: (showDate && null != date)
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: handleClear,
                  )
                : null),
      );

  // REPEATABLE
  static Widget repeatableTile({
    required BuildContext context,
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    required Frequency frequency,
    required Set<int> weekdays,
    DateTime? startDate,
    required int repeatSkip,
    required void Function(
            {bool? checkClose,
            required Frequency newFreq,
            required Set<int> newWeekdays,
            required int newSkip})
        handleUpdate,
    required void Function() handleClear,
  }) {
    return Padding(
      padding: outerPadding,
      child: ListTile(
          contentPadding: const EdgeInsets.only(left: Constants.doublePadding),
          leading: const Icon(Icons.event_repeat_rounded),
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.semiCircular))),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              (frequency == Frequency.once)
                  ? const Expanded(
                      child: AutoSizeText("Set Recurring?",
                          overflow: TextOverflow.visible,
                          minFontSize: Constants.small,
                          maxLines: 2,
                          softWrap: true),
                    )
                  : Expanded(
                      child: AutoSizeText(
                          toBeginningOfSentenceCase(frequency.name)!,
                          overflow: TextOverflow.visible,
                          minFontSize: Constants.small,
                          maxLines: 1,
                          softWrap: false),
                    ),
            ],
          ),
          onTap: () async {
            await blurredDismissible(
                    context: context,
                    dialog: FrequencyDialog(
                      frequency: frequency,
                      weekdays: weekdays,
                      repeatSkip: repeatSkip,
                      startDate: startDate,
                    ))
                // await showDialog<Map<String, dynamic>?>(
                //     context: context,
                //     useRootNavigator: false,
                //     builder: (BuildContext context) {
                //       return FrequencyDialog(
                //         frequency: frequency,
                //         weekdays: weekdays,
                //         repeatSkip: repeatSkip,
                //         startDate: startDate,
                //       );
                //     })
                .then((newFrequency) {
              if (null == newFrequency) {
                return handleUpdate(
                  newFreq: frequency,
                  newWeekdays: weekdays,
                  newSkip: repeatSkip,
                );
              }
              return handleUpdate(
                newFreq: newFrequency["frequency"],
                newWeekdays: newFrequency["weekdays"],
                newSkip: newFrequency["repeatSkip"],
                checkClose: true,
              );
            });
          },
          trailing: (frequency != Frequency.once)
              ? IconButton(
                  icon: const Icon(Icons.clear), onPressed: handleClear)
              : null),
    );
  }

  // PRIORITY
  static Widget priorityTile({
    required BuildContext context,
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    required Priority priority,
    required void Function(Set<Priority> newSelection) onSelectionChanged,
    bool mobile = false,
  }) =>
      Padding(
        padding: outerPadding,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(children: [
                Expanded(
                    child: AutoSizeText("Priority",
                        style: Constants.headerStyle,
                        maxLines: 1,
                        softWrap: true,
                        textAlign: TextAlign.center,
                        minFontSize: Constants.medium))
              ]),
              SegmentedButton<Priority>(
                  selectedIcon: const Icon(Icons.flag_circle_rounded),
                  style: ButtonStyle(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.adaptivePlatformDensity,
                    side: WidgetStatePropertyAll<BorderSide>(BorderSide(
                      width: 2,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    )),
                  ),
                  segments: Priority.values
                      .map((Priority type) => ButtonSegment<Priority>(
                          tooltip: toBeginningOfSentenceCase(type.name),
                          icon: Constants.priorityIcon[type],
                          value: type,
                          label: (!mobile)
                              ? Text(
                                  toBeginningOfSentenceCase(type.name),
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                )
                              : Text(
                                  toBeginningOfSentenceCase(
                                      type.name.replaceAll("medium", "med.")),
                                )))
                      .toList(growable: false),
                  selected: <Priority>{priority},
                  onSelectionChanged: onSelectionChanged)
            ]),
      );

  // MY DAY
  static Widget myDayTile(
      {required bool myDay,
      required bool canAdd,
      required void Function() toggleMyDay}) {
    String title = "";
    Widget leading;

    if (myDay) {
      title = "Added to my Day";
      leading = IconButton.filledTonal(
        icon: const Icon(Icons.wb_sunny_rounded),
        onPressed: toggleMyDay,
      );
    } else if (canAdd) {
      title = "Add to my Day?";
      leading = IconButton.outlined(
          icon: const Icon(Icons.wb_sunny_outlined), onPressed: toggleMyDay);
    } else {
      title = "Don't overload yourself, you deserve a rest.";
      leading = const Icon(Icons.block_rounded);
    }
    return ListTile(
        leading: leading,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText(
                title,
                overflow: TextOverflow.visible,
                softWrap: true,
                minFontSize: Constants.medium,
                maxLines: 2,
              ),
            ),
          ],
        ),
        onTap: (canAdd || myDay) ? toggleMyDay : null);
  }

  // EVENTS
  static Widget eventTile(
      {required CalendarEvent event,
      required BuildContext context,
      // Add padding later if needed
      bool smallScreen = false}) {
    return ListTile(
      leading: ListTileWidgets.eventIcon(
          type: event.model.modelType,
          currentContext: context,
          outerPadding:
              const EdgeInsets.symmetric(horizontal: Constants.halfPadding),
          iconPadding: const EdgeInsets.all(Constants.halfPadding)),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(Constants.semiCircular))),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: AutoSizeText(
              event.model.name,
              minFontSize: Constants.large,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          ),
        ],
      ),
      onTap: () async {
        late Widget dialog;
        switch (event.model.modelType) {
          case ModelType.task:
            Provider.of<ToDoViewModel>(context, listen: false)
                .fromModel(model: event.model as ToDo);
            dialog = const UpdateToDoScreen();
            break;
          case ModelType.deadline:
            Provider.of<DeadlineViewModel>(context, listen: false)
                .fromModel(model: event.model as Deadline);
            dialog = const UpdateDeadlineScreen();
            break;
          case ModelType.reminder:
            Provider.of<ReminderViewModel>(context, listen: false)
                .fromModel(model: event.model as Reminder);
            dialog = const UpdateReminderScreen();
            break;
          default:
            return;
        }
        await blurredNonDismissible(context: context, dialog: dialog);

        // await showDialog(
        //     barrierDismissible: false,
        //     useRootNavigator: false,
        //     context: context,
        //     builder: (BuildContext context) => dialog);
      },
      subtitle: Subtitles.eventSubtitle(
        context: context,
        model: event.model,
        smallScreen: smallScreen,
      ),
      trailing: (Frequency.once != event.model.frequency &&
              RepeatableState.delta != event.model.repeatableState)
          ? const Tooltip(
              message: "Repeating event",
              child: Icon(Icons.restart_alt_rounded))
          : (RepeatableState.delta == event.model.repeatableState)
              ? const Tooltip(
                  message: "Repeating event: modified",
                  child: Icon(Icons.change_history_rounded))
              : null,
    );
  }

  /// SEARCH

  static Widget historyTile({
    Widget? trailing,
    String title = "",
    void Function()? onTap,
  }) =>
      ListTile(
          leading: const Icon(Icons.history_rounded),
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.semiCircular))),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: AutoSizeText(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
          onTap: onTap,
          trailing: trailing);

  // I am unsure about a leading widget atm.
  static Widget searchItemTile({
    Widget? leading,
    Widget? trailing,
    String title = "",
    void Function()? onTap,
  }) =>
      ListTile(
        leading: leading,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
        onTap: onTap,
      );

  /// BOILERPLATE.

  // BASIC CREATE LISTTILE
  static Widget createNew({
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    required void Function() onTap,
    required BuildContext context,
  }) =>
      Padding(
        padding: outerPadding,
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(Icons.add_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: AutoSizeText(
                  "Create New",
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  maxLines: 1,
                  minFontSize: Constants.large,
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.all(Constants.padding),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular)),
          ),
          onTap: onTap,
        ),
      );

  // BASIC ADD BUTTON
  static Widget addTile({
    required void Function() onTap,
    required String title,
  }) =>
      ListTile(
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(Constants.semiCircular))),
        leading: const Icon(Icons.add_rounded),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AutoSizeText(title,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  minFontSize: Constants.large),
            ),
          ],
        ),
        onTap: onTap,
      );

  // FETCH
  static Widget fetchTile({
    required void Function() onTap,
  }) =>
      ListTile(
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.semiCircular))),
          leading: const Icon(Icons.redo_rounded),
          title: const Row(mainAxisSize: MainAxisSize.min, children: [
            Expanded(
              child: AutoSizeText(
                "Load more",
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                minFontSize: Constants.large,
              ),
            ),
          ]),
          onTap: onTap);

  static Widget resetTile({
    required void Function() onTap,
  }) =>
      ListTile(
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.semiCircular))),
          leading: const Icon(Icons.refresh_rounded),
          title: const Row(mainAxisSize: MainAxisSize.min, children: [
            Expanded(
              child: AutoSizeText(
                "Reset",
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                minFontSize: Constants.large,
              ),
            ),
          ]),
          onTap: onTap);

  // CREATE/UPDATE
  static Widget createButton({
    String label = "Create",
    bool loading = false,
    EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
    required Future<void> Function() handleCreate,
  }) =>
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: outerPadding,
          child: FilledButton.icon(
              label: (loading)
                  ? const Text("Working", overflow: TextOverflow.ellipsis)
                  : Text(label, overflow: TextOverflow.ellipsis),
              icon: (loading)
                  ? ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxHeight: 28, maxWidth: 28),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Transform.scale(
                              scale: 0.65,
                              child: const CircularProgressIndicator())),
                    )
                  : const Icon(Icons.add_rounded),
              onPressed: (loading) ? null : handleCreate),
        ),
      );

// DELETE
  static Widget deleteButton(
          {EdgeInsetsGeometry outerPadding = EdgeInsets.zero,
          required Future<void> Function() handleDelete,
          bool loading = false}) =>
      Padding(
        padding: outerPadding,
        child: FilledButton.tonalIcon(
            label: (loading)
                ? const Text("Working", overflow: TextOverflow.ellipsis)
                : const Text("Delete", overflow: TextOverflow.ellipsis),
            icon: (loading)
                ? ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 28, maxWidth: 28),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Transform.scale(
                            scale: 0.65,
                            child: const CircularProgressIndicator())),
                  )
                : const Icon(Icons.delete_forever_rounded),
            onPressed: (loading) ? null : handleDelete),
      );

// COMBINATION UPDATE & DELETE
  static Widget updateAndDeleteButtons({
    EdgeInsetsGeometry updateButtonPadding = EdgeInsets.zero,
    EdgeInsetsGeometry deleteButtonPadding = EdgeInsets.zero,
    required Future<void> Function() handleUpdate,
    required Future<void> Function() handleDelete,
    bool updateLoading = false,
    bool deleteLoading = false,
  }) =>
      Align(
        alignment: Alignment.centerRight,
        child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              deleteButton(
                  loading: deleteLoading,
                  outerPadding: deleteButtonPadding,
                  handleDelete: handleDelete),
              createButton(
                  loading: updateLoading,
                  label: "Update",
                  outerPadding: updateButtonPadding,
                  handleCreate: handleUpdate)
            ]),
      );

  // ERRORS:
  static Future<void> displayError({Exception? e}) async {
    if (null == e) {
      return;
    }

    BuildContext? context =
        ApplicationService.instance.globalNavigatorKey.currentState?.context;
    // If there's no context, assume there is no scrn.
    if (null == context) {
      return;
    }

    // LayoutProvider lp = Provider.of<LayoutProvider>(context, listen: false);
    //
    // double maxWidth = lp.width;
    // double? offset;
    // if (lp.drawerOpened && (!lp.isMobile || lp.isTablet)) {
    //   maxWidth -= lp.navDrawerWidth;
    //   offset = lp.navDrawerWidth;
    // }

    await displayFlushbar(
        context: context,
        flushbar: Flushbars.createError(
          // maxWidth: maxWidth,
          // leftMarginOffset: offset,
          context: context,
          message: e.toString(),
        ));
  }

  static Future<void> displayAlert({String message = ""}) async {
    BuildContext? context =
        ApplicationService.instance.globalNavigatorKey.currentState?.context;
    // If there's no context, assume there is no scrn.
    if (null == context) {
      return;
    }

    // LayoutProvider lp = Provider.of<LayoutProvider>(context, listen: false);
    //
    // double maxWidth = lp.width;
    // double? offset;
    // if (lp.drawerOpened && (!lp.isMobile || lp.isTablet)) {
    //   maxWidth -= lp.navDrawerWidth;
    //   offset = lp.navDrawerWidth;
    // }

    await displayFlushbar(
        context: context,
        flushbar: Flushbars.createAlert(
          // maxWidth: maxWidth,
          // leftMarginOffset: offset,
          context: context,
          message: message,
        ));
  }

  static Future<void> displayFlushbar(
      {required BuildContext context, required Flushbar flushbar}) async {
    await flushbar.show(context);
  }
}
