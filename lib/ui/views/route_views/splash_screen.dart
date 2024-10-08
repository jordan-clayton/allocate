import 'dart:developer';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../../../providers/application/layout_provider.dart';
import '../../../providers/model/deadline_provider.dart';
import '../../../providers/model/group_provider.dart';
import '../../../providers/model/reminder_provider.dart';
import '../../../providers/model/routine_provider.dart';
import '../../../providers/model/subtask_provider.dart';
import '../../../providers/model/todo_provider.dart';
import '../../../providers/model/user_provider.dart';
import '../../../services/application_service.dart';
import '../../../services/isar_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/repeatable_service.dart';
import '../../../services/supabase_service.dart';
import '../../../util/constants.dart';
import '../../../util/exceptions.dart';
import '../../app_router.dart';
import '../../widgets/tiles.dart';
import 'loading_screen.dart';

@RoutePage()
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<SplashScreen> createState() => _SplashScreen();
}

class _SplashScreen extends State<SplashScreen> {
  late final LayoutProvider layoutProvider;
  late final UserProvider userProvider;
  late final ToDoProvider toDoProvider;
  late final RoutineProvider routineProvider;
  late final ReminderProvider reminderProvider;
  late final DeadlineProvider deadlineProvider;
  late final GroupProvider groupProvider;
  late final SubtaskProvider subtaskProvider;

  @override
  void initState() {
    super.initState();
    layoutProvider = Provider.of<LayoutProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    toDoProvider = Provider.of<ToDoProvider>(context, listen: false);
    routineProvider = Provider.of<RoutineProvider>(context, listen: false);
    reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
    deadlineProvider = Provider.of<DeadlineProvider>(context, listen: false);
    groupProvider = Provider.of<GroupProvider>(context, listen: false);
    subtaskProvider = Provider.of<SubtaskProvider>(context, listen: false);

    layoutProvider.isMobile = Platform.isIOS || Platform.isAndroid;

    StackRouter router = AutoRouter.of(context);

    // Test this later -> needs to push back to home if somehow popped.
    if (userProvider.initialized) {
      router.navigate(HomeRoute(
          index: ApplicationService.instance.initialPageIndex ??
              widget.initialIndex));
      return;
    }

    init().then((_) {
      // ROUTE TO HOME PAGE, send the initial index.
      // Unless it has been set by NavigatorService
      router.navigate(HomeRoute(
          index: ApplicationService.instance.initialPageIndex ??
              widget.initialIndex));
    }).catchError((e, stacktrace) async {
      log(e.toString(), stackTrace: stacktrace);
      // Might make sense to push to an error screen and close.
      // TODO: implement a gui toast for errors.
      if (e is Exception) {
        await Tiles.displayError(e: e);
      }

      if (e is PostgrestException) {
        router.navigate(HomeRoute(
            index: ApplicationService.instance.initialPageIndex ??
                widget.initialIndex));
        return;
      }

      if (layoutProvider.isMobile) {
        SystemNavigator.pop();
      } else {
        await windowManager.destroy();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> init() async {
    if ((Constants.supabaseURL.isEmpty || Constants.supabaseAnnonKey.isEmpty) &&
        !Constants.offlineOnly) {
      throw BuildFailureException("App not configured");
    }

    await Future.wait(
      [
        IsarService.instance.init(),
        SupabaseService.instance.init(
            supabaseUrl: Constants.supabaseURL,
            anonKey: Constants.supabaseAnnonKey,
            client: Constants.offlineOnly ? FakeSupabase() : null),
      ],
    ).then((_) async {
      await Future.wait([
        toDoProvider.init(),
        routineProvider.init(),
        subtaskProvider.init(),
        reminderProvider.init(),
        deadlineProvider.init(),
        groupProvider.init(),
        userProvider.init(),
        NotificationService.instance.init(),
      ]);

      if (userProvider.newDay) {
        await dayReset();
      }
      userProvider.viewModel?.lastOpened = DateTime.now();
    });
  }

  Future<void> dayReset() async {
    await Future.wait([
      toDoProvider.dayReset(),
      routineProvider.dayReset(),
      subtaskProvider.dayReset(),
      reminderProvider.dayReset(),
      deadlineProvider.dayReset(),
      groupProvider.dayReset(),
      userProvider.dayReset(),
    ]).catchError((e) async {
      await Tiles.displayError(e: e);
      return [];
    });

    await RepeatableService.instance.generateNextRepeats();
  }

  @override
  Widget build(BuildContext context) {
    layoutProvider.size = MediaQuery.sizeOf(context);
    layoutProvider.isTablet = layoutProvider.isMobile &&
        (layoutProvider.size.shortestSide > Constants.smallScreen);
    return (Platform.isWindows)
        ? const PopScope(
            canPop: false, child: DragToResizeArea(child: LoadingScreen()))
        : const PopScope(canPop: false, child: LoadingScreen());
  }
}
