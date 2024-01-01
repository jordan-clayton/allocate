import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../model/task/routine.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../util/constants.dart';
import '../../../util/enums.dart';
import '../../widgets/listview_header.dart';
import '../../widgets/listviews.dart';
import '../../widgets/paginating_listview.dart';
import '../../widgets/tiles.dart';
import '../sub_views/create_routine.dart';

class RoutinesListScreen extends StatefulWidget {
  const RoutinesListScreen({super.key});

  @override
  State<RoutinesListScreen> createState() => _RoutinesListScreen();
}

class _RoutinesListScreen extends State<RoutinesListScreen> {
  late final RoutineProvider routineProvider;
  late final UserProvider userProvider;

  @override
  void initState() {
    super.initState();
    initializeProviders();
  }

  void initializeProviders() {
    routineProvider = Provider.of<RoutineProvider>(context, listen: false);
    if (routineProvider.rebuild) {
      routineProvider.routines = [];
    }

    userProvider = Provider.of<UserProvider>(context, listen: false);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onFetch({List<Routine>? items}) {
    if (null == items) {
      return;
    }
    for (Routine routine in items) {
      routine.fade = Fade.fadeIn;
    }
  }

  Future<void> onRemove({Routine? item}) async {
    if (null == item) {
      return;
    }

    if (routineProvider.routines.length < 2) {
      return;
    }

    if (mounted) {
      setState(() => item.fade = Fade.fadeOut);
      await Future.delayed(const Duration(milliseconds: Constants.fadeOutTime));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Constants.padding),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListViewHeader<Routine>(
            outerPadding: const EdgeInsets.all(Constants.padding),
            header: "Routines",
            sorter: routineProvider.sorter,
            leadingIcon: const Icon(Icons.repeat_rounded),
            onChanged: ({SortMethod? sortMethod}) {
              if (null == sortMethod) {
                return;
              }
              if (mounted) {
                setState(() {
                  routineProvider.sortMethod = sortMethod;
                });
              }
            }),
        Tiles.createNew(
          outerPadding:
              const EdgeInsets.symmetric(vertical: Constants.halfPadding),
          context: context,
          onTap: () async => await showDialog(
            barrierDismissible: false,
            context: context,
            builder: (BuildContext context) => const CreateRoutineScreen(),
          ),
        ),
        Flexible(
          child: PaginatingListview<Routine>(
              items: routineProvider.routines,
              query: routineProvider.getRoutinesBy,
              offset: (routineProvider.rebuild)
                  ? 0
                  : routineProvider.routines.length,
              limit: Constants.minLimitPerQuery,
              rebuildNotifiers: [routineProvider],
              rebuildCallback: ({required List<Routine> items}) {
                routineProvider.routines = items;
                routineProvider.rebuild = false;
              },
              getAnimationKey: () => ValueKey(
                  routineProvider.sorter.sortMethod.index *
                          (routineProvider.sorter.descending ? -1 : 1) +
                      (routineProvider.routines.isEmpty ? 0 : 1)),
              onFetch: (userProvider.curUser?.reduceMotion ?? false)
                  ? null
                  : onFetch,
              onRemove: (userProvider.curUser?.reduceMotion ?? false)
                  ? null
                  : onRemove,
              listviewBuilder: ({
                Key? key,
                required BuildContext context,
                required List<Routine> items,
                Future<void> Function({Routine? item})? onRemove,
              }) {
                if (routineProvider.sortMethod == SortMethod.none) {
                  return ListViews.reorderableRoutines(
                    key: key,
                    context: context,
                    routines: items,
                    checkDelete: userProvider.curUser?.checkDelete ?? true,
                    onRemove: onRemove,
                  );
                }
                return ListViews.immutableRoutines(
                  key: key,
                  context: context,
                  routines: items,
                  checkDelete: userProvider.curUser?.checkDelete ?? true,
                  onRemove: onRemove,
                );
              }),
        ),
      ]),
    );
  }
}
