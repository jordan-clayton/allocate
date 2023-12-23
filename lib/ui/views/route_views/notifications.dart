import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../model/task/deadline.dart';
import '../../../model/task/reminder.dart';
import '../../../model/task/todo.dart';
import '../../../providers/deadline_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/todo_provider.dart';
import '../../../util/constants.dart';
import '../../../util/interfaces/i_repeatable.dart';
import '../../widgets/expanded_listtile.dart';
import '../../widgets/listview_header.dart';
import '../../widgets/listviews.dart';
import '../../widgets/paginating_listview.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreen();
}

class _NotificationsScreen extends State<NotificationsScreen> {
  late bool checkDelete;
  late final ToDoProvider toDoProvider;
  late final ReminderProvider reminderProvider;
  late final DeadlineProvider deadlineProvider;

  late final ScrollController mainScrollController;

  late final ScrollPhysics parentScrollPhysics;

  @override
  void initState() {
    super.initState();
    initializeProviders();
    initializeParameters();
    initializeControllers();
  }

  void initializeProviders() {
    toDoProvider = Provider.of<ToDoProvider>(context, listen: false);
    reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
    deadlineProvider = Provider.of<DeadlineProvider>(context, listen: false);
  }

  void initializeParameters() {
    checkDelete = true;
  }

  void initializeControllers() {
    mainScrollController = ScrollController();
    ScrollPhysics scrollPhysics = (Platform.isIOS || Platform.isMacOS)
        ? const BouncingScrollPhysics()
        : const ClampingScrollPhysics();
    parentScrollPhysics = AlwaysScrollableScrollPhysics(parent: scrollPhysics);
  }

  @override
  void dispose() {
    mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool largeScreen = (width >= Constants.largeScreen);
    bool smallScreen = (width <= Constants.smallScreen);

    return Padding(
        padding: const EdgeInsets.all(Constants.innerPadding),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListViewHeader<IRepeatable>(
            header: "Notifications",
            leadingIcon: Icon(Icons.notifications_on_rounded),
            sorter: null,
            showSorter: false,
          ),
          Flexible(
            child: Scrollbar(
              thumbVisibility: true,
              controller: mainScrollController,
              child: ListView(
                  shrinkWrap: true,
                  controller: mainScrollController,
                  physics: parentScrollPhysics,
                  children: [
                    ExpandedListTile(
                      expanded: true,
                      leading: const Icon(Icons.upcoming_rounded),
                      title: const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: Constants.padding),
                        child: AutoSizeText(
                          "Upcoming",
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          minFontSize: Constants.large,
                        ),
                      ),
                      children: [
                        // Deadlines
                        ExpandedListTile(
                            expanded: true,
                            leading: const Icon(Icons.announcement_rounded),
                            title: const AutoSizeText(
                              "Deadlines",
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              minFontSize: Constants.large,
                            ),
                            border: BorderSide.none,
                            children: [
                              PaginatingListview<Deadline>(
                                  items: deadlineProvider.deadlines,
                                  limit: 5,
                                  offset: (deadlineProvider.rebuild)
                                      ? 0
                                      : deadlineProvider.deadlines.length,
                                  listviewBuilder: (
                                          {Key? key,
                                          required BuildContext context,
                                          required List<Deadline> items}) =>
                                      ListViews.immutableDeadlines(
                                        key: key,
                                        context: context,
                                        deadlines: items,
                                        checkDelete: checkDelete,
                                        smallScreen: smallScreen,
                                      ),
                                  query: deadlineProvider.getUpcoming,
                                  paginateButton: true,
                                  rebuildNotifiers: [deadlineProvider],
                                  rebuildCallback: (
                                      {required List<Deadline> items}) {
                                    deadlineProvider.deadlines = items;
                                    deadlineProvider.rebuild = false;
                                  }),
                            ]),
                        // Reminders
                        ExpandedListTile(
                            expanded: true,
                            leading: const Icon(Icons.push_pin_rounded),
                            title: const AutoSizeText(
                              "Reminders",
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              minFontSize: Constants.large,
                            ),
                            border: BorderSide.none,
                            children: [
                              PaginatingListview<Reminder>(
                                  items: reminderProvider.reminders,
                                  limit: 5,
                                  offset: (reminderProvider.rebuild)
                                      ? 0
                                      : reminderProvider.reminders.length,
                                  listviewBuilder: (
                                          {Key? key,
                                          required BuildContext context,
                                          required List<Reminder> items}) =>
                                      ListViews.immutableReminders(
                                        key: key,
                                        context: context,
                                        reminders: items,
                                        checkDelete: checkDelete,
                                        smallScreen: smallScreen,
                                      ),
                                  query: reminderProvider.getUpcoming,
                                  paginateButton: true,
                                  rebuildNotifiers: [reminderProvider],
                                  rebuildCallback: (
                                      {required List<Reminder> items}) {
                                    reminderProvider.reminders = items;
                                    reminderProvider.rebuild = false;
                                  }),
                            ]),
                        // TODOS
                        ExpandedListTile(
                            expanded: true,
                            leading: const Icon(Icons.task_rounded),
                            title: const AutoSizeText(
                              "Tasks",
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              minFontSize: Constants.large,
                            ),
                            border: BorderSide.none,
                            children: [
                              PaginatingListview<ToDo>(
                                  items: toDoProvider.toDos,
                                  limit: 5,
                                  offset: (toDoProvider.rebuild)
                                      ? 0
                                      : toDoProvider.toDos.length,
                                  listviewBuilder: (
                                          {Key? key,
                                          required BuildContext context,
                                          required List<ToDo> items}) =>
                                      ListViews.immutableToDos(
                                        key: key,
                                        context: context,
                                        toDos: items,
                                        checkDelete: checkDelete,
                                        smallScreen: smallScreen,
                                        checkboxAnimateBeforeUpdate: (
                                            {required int index,
                                            required ToDo toDo}) async {
                                          if (mounted) {
                                            setState(() {
                                              items[index] = toDo;
                                            });
                                          }
                                          return await Future.delayed(
                                              const Duration(
                                                  milliseconds: Constants
                                                      .checkboxAnimationTime));
                                        },
                                      ),
                                  query: toDoProvider.getUpcoming,
                                  paginateButton: true,
                                  rebuildNotifiers: [toDoProvider],
                                  rebuildCallback: (
                                      {required List<ToDo> items}) {
                                    toDoProvider.toDos = items;
                                    toDoProvider.rebuild = false;
                                  }),
                            ]),
                      ],
                    ),
                    ExpandedListTile(
                        expanded: true,
                        leading:
                            const Icon(Icons.notification_important_rounded),
                        title: const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: Constants.padding),
                          child: AutoSizeText(
                            "Overdue",
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                            minFontSize: Constants.large,
                          ),
                        ),
                        children: [
                          // Deadlines
                          ExpandedListTile(
                              expanded: true,
                              leading: const Icon(Icons.announcement_rounded),
                              title: const AutoSizeText(
                                "Deadlines",
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                minFontSize: Constants.large,
                              ),
                              border: BorderSide.none,
                              children: [
                                PaginatingListview<Deadline>(
                                    items: deadlineProvider.secondaryDeadlines,
                                    limit: 5,
                                    offset: (deadlineProvider.rebuild)
                                        ? 0
                                        : deadlineProvider
                                            .secondaryDeadlines.length,
                                    listviewBuilder: (
                                            {Key? key,
                                            required BuildContext context,
                                            required List<Deadline> items}) =>
                                        ListViews.immutableDeadlines(
                                          key: key,
                                          context: context,
                                          deadlines: items,
                                          checkDelete: checkDelete,
                                          smallScreen: smallScreen,
                                        ),
                                    query: deadlineProvider.getOverdues,
                                    paginateButton: true,
                                    rebuildNotifiers: [deadlineProvider],
                                    rebuildCallback: (
                                        {required List<Deadline> items}) {
                                      deadlineProvider.secondaryDeadlines =
                                          items;
                                      deadlineProvider.rebuild = false;
                                    }),
                              ]),
                          // Reminders
                          ExpandedListTile(
                              expanded: true,
                              leading: const Icon(Icons.push_pin_rounded),
                              title: const AutoSizeText(
                                "Reminders",
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                minFontSize: Constants.large,
                              ),
                              border: BorderSide.none,
                              children: [
                                PaginatingListview<Reminder>(
                                    items: reminderProvider.secondaryReminders,
                                    limit: 5,
                                    offset: (reminderProvider.rebuild)
                                        ? 0
                                        : reminderProvider
                                            .secondaryReminders.length,
                                    listviewBuilder: (
                                            {Key? key,
                                            required BuildContext context,
                                            required List<Reminder> items}) =>
                                        ListViews.immutableReminders(
                                          key: key,
                                          context: context,
                                          reminders: items,
                                          checkDelete: checkDelete,
                                          smallScreen: smallScreen,
                                        ),
                                    query: reminderProvider.getOverdues,
                                    paginateButton: true,
                                    rebuildNotifiers: [reminderProvider],
                                    rebuildCallback: (
                                        {required List<Reminder> items}) {
                                      reminderProvider.secondaryReminders =
                                          items;
                                      reminderProvider.rebuild = false;
                                    }),
                              ]),
                          // TODOS
                          ExpandedListTile(
                              expanded: true,
                              leading: const Icon(Icons.task_rounded),
                              title: const AutoSizeText(
                                "Tasks",
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                minFontSize: Constants.large,
                              ),
                              border: BorderSide.none,
                              children: [
                                PaginatingListview<ToDo>(
                                    items: toDoProvider.secondaryToDos,
                                    limit: 5,
                                    offset: (toDoProvider.rebuild)
                                        ? 0
                                        : toDoProvider.secondaryToDos.length,
                                    listviewBuilder: (
                                            {Key? key,
                                            required BuildContext context,
                                            required List<ToDo> items}) =>
                                        ListViews.immutableToDos(
                                          key: key,
                                          context: context,
                                          toDos: items,
                                          checkDelete: checkDelete,
                                          smallScreen: smallScreen,
                                          checkboxAnimateBeforeUpdate: (
                                              {required int index,
                                              required ToDo toDo}) async {
                                            if (mounted) {
                                              setState(() {
                                                items[index] = toDo;
                                              });
                                            }
                                            return await Future.delayed(
                                                const Duration(
                                                    milliseconds: Constants
                                                        .checkboxAnimationTime));
                                          },
                                        ),
                                    query: toDoProvider.getOverdues,
                                    paginateButton: true,
                                    rebuildNotifiers: [toDoProvider],
                                    rebuildCallback: (
                                        {required List<ToDo> items}) {
                                      toDoProvider.secondaryToDos = items;
                                      toDoProvider.rebuild = false;
                                    }),
                              ]),
                        ]),
                  ]),
            ),
          )
        ]));
  }
}
