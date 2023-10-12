import 'package:another_flushbar/flushbar.dart';
import "package:auto_route/auto_route.dart";
import 'package:auto_size_text/auto_size_text.dart';
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import '../../../model/task/group.dart';
import '../../../providers/deadline_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/todo_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../util/constants.dart';
import '../../widgets/desktop_drawer_wrapper.dart';
import '../../widgets/flushbars.dart';
import '../../widgets/padded_divider.dart';
import '../sub_views/create_group.dart';
import '../sub_views/update_group.dart';

@RoutePage()
class HomeScreen extends StatefulWidget {
  final int? index;

  const HomeScreen({Key? key, this.index}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreen> {
  late int selectedPageIndex;

  late final ToDoProvider toDoProvider;
  late final RoutineProvider routineProvider;
  late final ReminderProvider reminderProvider;
  late final DeadlineProvider deadlineProvider;
  late final UserProvider userProvider;
  late final GroupProvider groupProvider;

  late Future<List<Group>> groupFuture;

  late bool navLoading;

  late final ScrollController navScrollController;

  late final ScrollPhysics scrollPhysics;

  // I haven't fully thought this through yet.
  int get myDayTotal =>
      toDoProvider.myDayWeight + routineProvider.routineWeight;

  @override
  void initState() {
    super.initState();
    initializeProviders();
    initializeParams();
    initializeControllers();
  }

  void initializeProviders() {
    toDoProvider = Provider.of<ToDoProvider>(context, listen: false);
    routineProvider = Provider.of<RoutineProvider>(context, listen: false);
    reminderProvider = Provider.of<ReminderProvider>(context, listen: false);
    deadlineProvider = Provider.of<DeadlineProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    groupProvider = Provider.of<GroupProvider>(context, listen: false);

    toDoProvider.addListener(rebuildToDo);
    routineProvider.addListener(rebuildRoutine);
    groupProvider.addListener(rebuildGroup);
    deadlineProvider.addListener(rebuildDeadline);
    reminderProvider.addListener(rebuildReminder);
    resetProviders();
  }

  void resetProviders() {
    rebuildToDo();
    rebuildRoutine();
    rebuildDeadline();
    rebuildReminder();
    // TODO: Figure this out.
    // userProvider.rebuild = true
    rebuildGroup();
  }

  void rebuildGroup() {
    groupProvider.rebuild = true;
    resetNavGroups();
  }

  void rebuildReminder() {
    reminderProvider.rebuild = true;
  }

  void rebuildDeadline() {
    deadlineProvider.rebuild = true;
  }

  void rebuildRoutine() {
    routineProvider.rebuild = true;
  }

  void rebuildToDo() {
    toDoProvider.rebuild = true;
    // These are asynchronous, but can happen in the background - navGroups calls setState
    toDoProvider
        .setMyDayWeight()
        .whenComplete(() => userProvider.myDayTotal = myDayTotal);
    resetNavGroups();
  }

  void initializeParams() {
    selectedPageIndex = widget.index ?? 0;
    navLoading = false;
    groupFuture = groupProvider.mostRecent(grabToDos: true);
  }

  void initializeControllers() {
    navScrollController = ScrollController();
    scrollPhysics =
        const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());
  }

  Future<void> resetNavGroups() async {
    setState(() {
      navLoading = true;
    });

    return Future.delayed(
        const Duration(milliseconds: 100),
        () async => await groupProvider
            .mostRecent(grabToDos: true)
            .then((groups) => setState(() {
                  groupProvider.recentGroups = groups;
                  navLoading = false;
                })));
  }

  @override
  void dispose() {
    navScrollController.dispose();
    toDoProvider.removeListener(rebuildToDo);
    routineProvider.removeListener(rebuildRoutine);
    groupProvider.removeListener(rebuildGroup);
    deadlineProvider.removeListener(rebuildDeadline);
    reminderProvider.removeListener(rebuildReminder);
    super.dispose();
  }

  // TODO: Refactor this to the const widget
  Widget buildDrainBar({required BuildContext context}) {
    int maxBandwidth =
        userProvider.curUser?.bandwidth ?? Constants.maxBandwidth;
    double offset = myDayTotal.toDouble() / maxBandwidth.toDouble();
    return Transform.scale(
      scale: 0.75,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 100, maxHeight: 50),
        child: Stack(alignment: Alignment.center, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Constants.padding),
            child: Container(
              decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignCenter),
                  shape: BoxShape.rectangle,
                  borderRadius: const BorderRadius.all(Radius.circular(10))),
              child: Padding(
                padding: const EdgeInsets.all(Constants.halfPadding),
                child: LinearProgressIndicator(
                    color: (offset < 0.8) ? null : Colors.redAccent,
                    minHeight: 50,
                    value: 1 - offset,
                    // Possibly remove
                    borderRadius: const BorderRadius.all(Radius.circular(10))),
              ),
            ),
          ),
          Align(
              alignment: Alignment.centerRight,
              child: Container(
                  height: 40,
                  width: 8,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                    color: Theme.of(context).colorScheme.outline,
                  ))),
          AutoSizeText("${maxBandwidth - userProvider.myDayTotal}",
              minFontSize: Constants.large,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: Constants.hugeHeaderStyle),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //TODO: refactor the media query ALL SCREENS to avoid running twice;
    double width = MediaQuery.of(context).size.width;

    bool largeScreen = (width >= Constants.largeScreen);
    bool smallScreen = (width <= Constants.smallScreen);

    return (largeScreen)
        ? buildDesktop(context: context, largeScreen: largeScreen)
        : buildMobile(context: context, largeScreen: largeScreen);
  }

  Widget buildDesktop(
      {required BuildContext context, bool largeScreen = true}) {
    return Row(children: [
      // This is a workaround for a standard navigation drawer
      // until m3 spec is fully implemented in flutter.
      DesktopDrawerWrapper(
          drawer: buildNavigationDrawer(
              context: context, largeScreen: largeScreen)),
      const VerticalDivider(
        width: 1,
      ),

      Expanded(
          child: Scaffold(
              appBar: buildAppBar(context: context),
              body: SafeArea(
                  child: Constants.viewRoutes[selectedPageIndex].view)))
    ]);
  }

  Widget buildMobile(
      {required BuildContext context, bool largeScreen = false}) {
    return Scaffold(
        appBar: buildAppBar(context: context),
        drawer:
            buildNavigationDrawer(context: context, largeScreen: largeScreen),
        body: SafeArea(child: Constants.viewRoutes[selectedPageIndex].view));
  }

  AppBar buildAppBar({required BuildContext context}) {
    return AppBar(
      title: buildDrainBar(context: context),
      centerTitle: true,
    );
  }

  NavigationDrawer buildNavigationDrawer(
      {required BuildContext context, bool largeScreen = false}) {
    return NavigationDrawer(
        onDestinationSelected: (index) {
          setState(() {
            resetProviders();
            selectedPageIndex = index;
          });

          if (!largeScreen) {
            Navigator.pop(context);
          }
        },
        selectedIndex: selectedPageIndex,
        children: [
          // User name bar
          // Possible stretch Goal: add user images?
          Padding(
            padding: const EdgeInsets.all(Constants.innerPadding),
            child: ListTile(
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                      Radius.circular(Constants.roundedCorners))),
              leading: CircleAvatar(
                  child: Text(
                      "${userProvider.curUser?.userName[0].toUpperCase()}")),
              // Possible TODO: Refactor this to take a first/last name?
              title: Text("${userProvider.curUser?.userName}"),
              // Possible TODO: Refactor this to use an enum.
              subtitle: (null !=
                      SupabaseService
                          .instance.supabaseClient.auth.currentSession)
                  ? const Text("Online")
                  : const Text("Offline"),
              onTap: () {
                setState(() {
                  resetProviders();
                  selectedPageIndex =
                      Constants.viewRoutes.indexOf(Constants.settingsScreen);
                });
                if (!largeScreen) {
                  Navigator.pop(context);
                }
              },
              // TODO: refactor this to search anchor
              trailing: IconButton(
                icon: const Icon(Icons.search_outlined),
                selectedIcon: const Icon(Icons.search),
                onPressed: () {
                  Flushbar? alert;
                  alert = Flushbars.createError(
                    context: context,
                    message: "Feature not implemented yet, coming soon!",
                    dismissCallback: () => alert?.dismiss(),
                  );
                  alert.show(context);
                },
              ),
            ),
          ),
          const PaddedDivider(padding: Constants.innerPadding),

          ...Constants.viewRoutes
              .map((view) => view.destination ?? const SizedBox.shrink()),
          const PaddedDivider(padding: Constants.innerPadding),
          // Drop down menu for Groups.
          // Future TODO: Factor rounded rectangle shape to constants class.
          // This Card is a workaround until The ExpansionTile inkwell bug is fixed.
          Card(
            clipBehavior: Clip.hardEdge,
            elevation: 0,
            color: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(Constants.roundedCorners)),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                  horizontal: Constants.innerPadding + Constants.padding),
              shape: const RoundedRectangleBorder(),
              collapsedShape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(Constants.circular))),
              leading: const Icon(Icons.table_view_outlined),
              title: const Text(
                "Groups",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              children: [
                // Tile for "See all groups"
                ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: Constants.padding + Constants.innerPadding),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                            Radius.circular(Constants.roundedCorners))),
                    leading: const Icon(Icons.workspaces_outlined),
                    title: const AutoSizeText(
                      "All Groups",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    onTap: () {
                      setState(() {
                        resetProviders();
                        selectedPageIndex =
                            Constants.viewRoutes.indexOf(Constants.groupScreen);
                      });
                      if (!largeScreen) {
                        Navigator.pop(context);
                      }
                    }),

                ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: Constants.padding + Constants.innerPadding),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                            Radius.circular(Constants.roundedCorners))),
                    leading: const Icon(Icons.add_rounded),
                    title: const AutoSizeText(
                      "Add New",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                    onTap: () async {
                      return await showDialog(
                          barrierDismissible: false,
                          useRootNavigator: false,
                          context: context,
                          builder: (BuildContext context) =>
                              const CreateGroupScreen());
                    }),

                buildNavGroupTile(physics: scrollPhysics),
              ],
            ),
          )
        ]);
  }

  ListView buildNavGroupTile(
      {ScrollPhysics physics = const NeverScrollableScrollPhysics()}) {
    return ListView(
        physics: physics,
        controller: navScrollController,
        shrinkWrap: true,
        children: [
          Consumer<GroupProvider>(builder:
              (BuildContext context, GroupProvider value, Widget? child) {
            return ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: value.recentGroups.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal:
                              Constants.padding + Constants.innerPadding),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                              Radius.circular(Constants.roundedCorners))),
                      leading:
                          const Icon(Icons.playlist_add_check_circle_outlined),
                      title: AutoSizeText(value.recentGroups[index].name,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          minFontSize: Constants.small),
                      onTap: () async {
                        value.curGroup = value.recentGroups[index];
                        return await showDialog(
                            barrierDismissible: false,
                            useRootNavigator: false,
                            context: context,
                            builder: (BuildContext context) =>
                                const UpdateGroupScreen());
                      },
                      trailing: (value.recentGroups[index].toDos.isNotEmpty)
                          ? AutoSizeText(
                              "${value.recentGroups[index].toDos.length}",
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              minFontSize: Constants.small)
                          : null);
                });
          }),
          (navLoading)
              ? const Padding(
                  padding: EdgeInsets.all(Constants.padding),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink()
        ]);
  }
}
