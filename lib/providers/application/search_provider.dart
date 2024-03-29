import 'package:flutter/foundation.dart';

import '../../util/enums.dart';
import '../../util/interfaces/i_model.dart';
import '../../util/strings.dart';
import '../viewmodels/user_viewmodel.dart';

class SearchProvider<T extends IModel> extends ChangeNotifier {
  bool _rebuild = true;

  String _searchString = "";

  String get searchString => _searchString;

  set searchString(String newString) {
    _searchString = newString;
    notifyListeners();
  }

  bool get rebuild => _rebuild;

  set rebuild(bool rebuild) {
    _rebuild = rebuild;
    if (_rebuild) {
      _model = [];
      _searchString = "";
      notifyListeners();
    }
  }

  late UserViewModel? _userModel;
  List<T> _model = [];

  List<T> get model => _model;

  set model(List<T> newModel) {
    _model = newModel;
    notifyListeners();
  }

  set userModel(UserViewModel? userModel) {
    _userModel = userModel;
    notifyListeners();
  }

  SearchProvider({UserViewModel? userModel}) : _userModel = userModel;

  List<IModel> batchProcess(
      {List<List<IModel>>? models, String searchString = ""}) {
    if (null == models) {
      return [];
    }

    List<IModel> flatten = List.empty(growable: true);
    for (List<IModel> model in models) {
      flatten.addAll(model);
    }
    if (searchString.isNotEmpty) {
      return sortByLevenshtein(model: flatten, searchString: searchString);
    }
    return flatten;
  }

  List<IModel> batchWithFade(
      {List<List<IModel>>? models, String searchString = ""}) {
    if (null == models) {
      return [];
    }
    List<IModel> flatten = List.empty(growable: true);

    for (List<IModel> model in models) {
      for (IModel modelItem in model) {
        if (!(_userModel?.reduceMotion ?? false)) {
          modelItem.fade = Fade.fadeIn;
        }
        flatten.add(modelItem);
      }
    }
    if (searchString.isNotEmpty) {
      return sortByLevenshtein(model: flatten, searchString: searchString);
    }
    return flatten;
  }

  List<IModel> sortByLevenshtein(
      {required List<IModel> model, required String searchString}) {
    return model
      ..sort((m1, m2) => levenshteinDistance(s1: m1.name, s2: searchString)
          .compareTo(levenshteinDistance(s1: m2.name, s2: searchString)));
  }
}
