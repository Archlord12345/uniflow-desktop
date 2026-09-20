import 'package:flutter/material.dart';

import '../widgets/motion.dart';

/// Notifications éphémères du design system (`Toast.tsx`). Le moteur est
/// `showFeedback` (coche ou croix animée, glissement depuis le bas) ; ces
/// raccourcis fixent le vocabulaire : `Toast.success`, `Toast.error`,
/// `Toast.info`.
class Toast {
  Toast._();

  static void success(BuildContext context, String message, {String? detail}) =>
      showFeedback(context, message: message, detail: detail, success: true);

  static void error(BuildContext context, String message, {String? detail}) =>
      showFeedback(context, message: message, detail: detail, success: false);

  static void info(BuildContext context, String message, {String? detail}) =>
      showFeedback(context,
          message: message,
          detail: detail,
          success: true,
          duration: const Duration(seconds: 4));
}
