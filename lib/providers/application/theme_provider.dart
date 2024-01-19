import 'dart:io';

import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

import '../../util/constants.dart';
import '../../util/enums.dart';
import '../viewmodels/user_viewmodel.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;
  ThemeData? _hiLight;
  ThemeData? _hiDark;

  late Color _primarySeed;
  Color? _secondarySeed;
  Color? _tertiarySeed;

  late FlexTones Function(Brightness brightness) _flexTone;

  late ThemeType _themeType;
  late ToneMapping _toneMapping;
  late Effect _windowEffect;

  late bool _useUltraHighContrast;
  late bool _reduceMotion;

  late double _scaffoldOpacity;
  late double _sidebarOpacity;
  late bool _useTransparency;

  // Make private as necessary.
  late List<Color> recentColors;

  UserViewModel? userViewModel;

  ThemeData? get lightTheme => _lightTheme;

  ThemeData? get darkTheme => _darkTheme;

  ThemeData? get highContrastLight => _hiLight;

  ThemeData? get highContrastDark => _hiDark;

  Color get primarySeed => _primarySeed;

  set primarySeed(Color newColor) {
    _primarySeed = newColor;
    userViewModel?.primarySeed = newColor.value;
    generateThemes();
    notifyListeners();
  }

  Color? get secondarySeed => _secondarySeed;

  //Notifies.
  set secondarySeed(Color? newColor) {
    _secondarySeed = newColor;
    userViewModel?.secondarySeed = newColor?.value;
    generateThemes();
    notifyListeners();
  }

  Color? get tertiarySeed => _tertiarySeed;

  //Notifies.
  set tertiarySeed(Color? newColor) {
    _tertiarySeed = newColor;
    userViewModel?.tertiarySeed = newColor?.value;
    generateThemes();
    notifyListeners();
  }

  ThemeType get themeType => _themeType;

  //Notifies.
  set themeType(ThemeType newThemeType) {
    _themeType = newThemeType;
    userViewModel?.themeType = newThemeType;
    notifyListeners();
  }

  ToneMapping get toneMapping => _toneMapping;

  set toneMapping(ToneMapping newToneMapping) {
    _toneMapping = newToneMapping;
    userViewModel?.toneMapping = newToneMapping;
    _setToneMapping(tone: _toneMapping);
    generateThemes();
    notifyListeners();
  }

  Effect get windowEffect => _windowEffect;

  set windowEffect(Effect newEffect) {
    _windowEffect = newEffect;
    userViewModel?.windowEffect = newEffect;
    _setWindowEffect(effect: _windowEffect);
    notifyListeners();
  }

  bool get useUltraHighContrast => _useUltraHighContrast;

  set useUltraHighContrast(bool hiContrast) {
    _useUltraHighContrast = hiContrast;
    userViewModel?.useUltraHighContrast = hiContrast;
    generateThemes();
    notifyListeners();
  }

  bool get reduceMotion => _reduceMotion;

  set reduceMotion(bool reduceMotion) {
    _reduceMotion = reduceMotion;
    userViewModel?.reduceMotion = reduceMotion;
    notifyListeners();
  }

  bool get useTransparency => _useTransparency;

  set useTransparency(bool transparency) {
    bool changed = (transparency ^ _useTransparency);
    _useTransparency = transparency;
    if (changed) {
      notifyListeners();
    }
  }

  double get scaffoldOpacity => (_useTransparency) ? _scaffoldOpacity : 1.0;

  // Because these are continuous & modified by slider, updating the user in a separate setter
  set scaffoldOpacitySavePref(double newOpacity) {
    userViewModel?.scaffoldOpacity = newOpacity;
    scaffoldOpacity = newOpacity;
    notifyListeners();
  }

  set scaffoldOpacity(double newOpacity) {
    _scaffoldOpacity = newOpacity;
    notifyListeners();
  }

  double get sidebarOpacity => (_useTransparency) ? _sidebarOpacity : 1.0;

  set sidebarOpacitySavePref(double newOpacity) {
    userViewModel?.sidebarOpacity = newOpacity;
    sidebarOpacity = newOpacity;
    notifyListeners();
  }

  set sidebarOpacity(double newOpacity) {
    _sidebarOpacity = newOpacity;
    notifyListeners();
  }

  double get sidebarElevation =>
      (Effect.disabled == _windowEffect || Effect.transparent == _windowEffect)
          ? 1
          : 0;

  void setUser({UserViewModel? newUser}) {
    userViewModel = newUser;
    notifyListeners();
  }

  ThemeProvider({this.userViewModel}) {
    init();
  }

  // Generate according to user params.
  void init() {
    // Get colors
    _primarySeed =
        Color(userViewModel?.primarySeed ?? Constants.defaultPrimaryColorSeed);
    _secondarySeed = (null != userViewModel?.secondarySeed)
        ? Color(userViewModel!.secondarySeed!)
        : null;
    _tertiarySeed = (null != userViewModel?.tertiarySeed)
        ? Color(userViewModel!.tertiarySeed!)
        : null;

    _themeType = userViewModel?.themeType ?? ThemeType.system;
    _toneMapping = userViewModel?.toneMapping ?? ToneMapping.system;
    _windowEffect = userViewModel?.windowEffect ?? Effect.disabled;
    _useUltraHighContrast = userViewModel?.useUltraHighContrast ?? false;
    _reduceMotion = userViewModel?.reduceMotion ?? false;
    _scaffoldOpacity =
        userViewModel?.scaffoldOpacity ?? Constants.defaultScaffoldOpacity;
    _sidebarOpacity =
        userViewModel?.sidebarOpacity ?? Constants.defaultSidebarOpacity;
    _useTransparency = null != userViewModel?.windowEffect &&
        Effect.disabled != userViewModel?.windowEffect;

    recentColors = List.empty(growable: true);

    // Get tonemapping.
    _setToneMapping(tone: _toneMapping);

    // Generate Themes.
    generateThemes();

    // Set the window effect for desktop. Runs asynchronously, should be set by the time
    // the splash screen is done.
    if (!Platform.isIOS || !Platform.isAndroid) {
      _setWindowEffect(effect: _windowEffect);
    }
  }

  void generateThemes() {
    _lightTheme = ThemeData(
      colorScheme: SeedColorScheme.fromSeeds(
          brightness: Brightness.light,
          primaryKey: _primarySeed,
          secondaryKey: _secondarySeed,
          tertiaryKey: _tertiarySeed,
          tones: _flexTone(Brightness.light)),
      useMaterial3: true,
    );
    _darkTheme = ThemeData(
      colorScheme: SeedColorScheme.fromSeeds(
          brightness: Brightness.dark,
          primaryKey: _primarySeed,
          secondaryKey: _secondarySeed,
          tertiaryKey: _tertiarySeed,
          tones: _flexTone(Brightness.dark)),
      useMaterial3: true,
    );
    _hiDark = ThemeData(
      colorScheme: SeedColorScheme.fromSeeds(
          brightness: Brightness.dark,
          primaryKey: _primarySeed,
          secondaryKey: _secondarySeed,
          tertiaryKey: _tertiarySeed,
          tones: (userViewModel?.useUltraHighContrast ?? false)
              ? FlexTones.ultraContrast(Brightness.dark)
              : FlexTones.highContrast(Brightness.dark)),
      useMaterial3: true,
    );

    _hiLight = ThemeData(
      colorScheme: SeedColorScheme.fromSeeds(
          brightness: Brightness.light,
          primaryKey: _primarySeed,
          secondaryKey: _secondarySeed,
          tertiaryKey: _tertiarySeed,
          tones: (userViewModel?.useUltraHighContrast ?? false)
              ? FlexTones.ultraContrast(Brightness.light)
              : FlexTones.highContrast(Brightness.light)),
      useMaterial3: true,
    );
  }

  // Doesn't notify.
  FlexTones Function(Brightness brightness) getToneMapping(
      {ToneMapping? tone = ToneMapping.system}) {
    tone = tone ?? ToneMapping.system;
    return switch (tone) {
      ToneMapping.system => FlexTones.material,
      ToneMapping.soft => FlexTones.soft,
      ToneMapping.vivid => FlexTones.vivid,
      ToneMapping.jolly => FlexTones.jolly,
      ToneMapping.candy => FlexTones.candyPop,
      ToneMapping.monochromatic => FlexTones.oneHue,
      ToneMapping.high_contrast => FlexTones.highContrast,
      ToneMapping.ultra_high_contrast => FlexTones.ultraContrast,
    };
  }

  // Doesn't notify.
  void _setToneMapping({ToneMapping? tone = ToneMapping.system}) {
    _flexTone = getToneMapping(tone: tone);
  }

  Brightness getBrightness() {
    return switch (_themeType) {
      ThemeType.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
      ThemeType.light => Brightness.light,
      ThemeType.dark => Brightness.dark,
    };
  }

  Future<void> _setWindowEffect({Effect effect = Effect.disabled}) async {
    if (Platform.isIOS || Platform.isAndroid) {
      return;
    }

    _useTransparency = (Effect.disabled != effect);

    if (Platform.isLinux) {
      return;
    }

    await _setWinMacWindow(effect: WindowEffect.sidebar);
  }

  Future<void> _setWinMacWindow({
    effect = WindowEffect.transparent,
  }) async {
    Brightness brightness = getBrightness();
    Color backgroundColor = (Platform.isMacOS)
        ? Colors.transparent
        : (brightness == Brightness.light)
            ? Constants.windowsDefaultLight
            : Constants.windowsDefaultDark;

    Window.setEffect(
      effect: effect,
      color: backgroundColor,
      dark: brightness == Brightness.dark,
    );

    if (Platform.isMacOS && _themeType != ThemeType.system) {
      await Window.overrideMacOSBrightness(
        dark: brightness == Brightness.dark,
      );
    }
  }
}
