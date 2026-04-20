import 'package:flutter/material.dart';

class ColorManager {
  static const _scaffoldBackgroundLight = Color(0xFFF5F5F5);
  static const _scaffoldBackgroundDark = Color(0xFF121212);

  static Color scaffoldBackground(Brightness brightness) {
    if (brightness == Brightness.light) {
      return _scaffoldBackgroundLight;
    } else {
      return _scaffoldBackgroundDark;
    }
  }

  static const _surfaceLight = Colors.white;
  static const _surfaceDark = Color(0xFF1E1E1E);

  static Color surface(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _surfaceLight;
    } else {
      return _surfaceDark;
    }
  }

  static const _primaryTextLight = Color(0xFF212121);
  static const _primaryTextDark = Colors.white;

  static Color primaryText(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _primaryTextLight;
    } else {
      return _primaryTextDark;
    }
  }

  static const _secondaryTextLight = Color(0xFF757575);
  static const _secondaryTextDark = Color(0xFFB0B0B0);

  static Color secondaryText(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _secondaryTextLight;
    } else {
      return _secondaryTextDark;
    }
  }

  static Color tagBackground(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _borderLight;
    } else {
      return _surfaceDark;
    }
  }

  static const _borderLight = Color(0xFFE0E0E0);
  static const _borderDark = Color(0xFF424242);

  static Color border(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _borderLight;
    } else {
      return _borderDark;
    }
  }

  static const _selectedLight = Color(0xFFBBDEFB);
  static const _selectedDark = Color(0xFF0d47a1);

  static Color selected(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _selectedLight;
    } else {
      return _selectedDark;
    }
  }

  static const _runningLight = Color(0xFFC8E6C9);
  static const _runningDark = Color(0xFF1b5e20);

  static Color running(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _runningLight;
    } else {
      return _runningDark;
    }
  }

  static const _buttonStopLight = Color(0xFFBDBDBD);
  static const _buttonStopDark = Color(0xFF424242);

  static Color buttonStop(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _buttonStopLight;
    } else {
      return _buttonStopDark;
    }
  }

  static const _formTitleLight = Colors.blue;
  static const _formTitleDark = Color(0xFFBBDEFB);

  static Color formTitle(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _formTitleLight;
    } else {
      return _formTitleDark;
    }
  }

  static const _secondaryButtonBackgroundLight = Color(0xFFEEEEEE);
  static const _secondaryButtonBackgroundDark = Color(0xFF2a2a2a);

  static Color secondaryButtonBackground(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return _secondaryButtonBackgroundLight;
    } else {
      return _secondaryButtonBackgroundDark;
    }
  }
}
