import 'package:flutter/widgets.dart';

/// Native window content sizes for reminder toasts.
///
/// The host and the Flutter widget share these values so the transparent
/// secondary window never clips the toast shadow or button row.
const double bubbleTailExtent = 10;
const Size normalBubbleContentSize = Size(272, 116);
const Size obedientBubbleContentSize = Size(216, 96);
