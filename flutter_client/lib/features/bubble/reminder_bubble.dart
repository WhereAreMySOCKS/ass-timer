import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/widgets/speech_bubble.dart';
import 'package:ass_timer_flutter/core/window/bubble_layout.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/material.dart';

const Key _reminderActionsKey = ValueKey<String>('reminder-actions');
const Key _primaryActionKey = ValueKey<String>('reminder-primary-action');
const Key _secondaryActionKey = ValueKey<String>('reminder-secondary-action');

SpeechBubbleTail speechBubbleTailForDockSide(PetDockSide? side) =>
    switch (side) {
      PetDockSide.left => SpeechBubbleTail.left,
      PetDockSide.right => SpeechBubbleTail.right,
      null => SpeechBubbleTail.bottom,
    };

class ReminderBubble extends StatelessWidget {
  const ReminderBubble({
    required this.controller,
    required this.tail,
    super.key,
  });

  final AppController controller;
  final SpeechBubbleTail tail;

  @override
  Widget build(BuildContext context) => ReminderBubbleContent(
        obedient: controller.snapshot.config.appMode == AppMode.obedient,
        reminderTitle: controller.reminderTitle,
        exerciseName: controller.exerciseName,
        tail: tail,
        onComplete: controller.completeReminder,
        onSkip: controller.skipReminder,
      );
}

@visibleForTesting
class ReminderBubbleContent extends StatelessWidget {
  const ReminderBubbleContent({
    required this.obedient,
    required this.reminderTitle,
    required this.exerciseName,
    required this.onComplete,
    required this.onSkip,
    this.tail = SpeechBubbleTail.bottom,
    super.key,
  });

  final bool obedient;
  final String reminderTitle;
  final String exerciseName;
  final SpeechBubbleTail tail;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final size = obedient ? obedientBubbleContentSize : normalBubbleContentSize;
    final horizontalTail =
        tail == SpeechBubbleTail.left || tail == SpeechBubbleTail.right;
    final cardWidth = size.width - (horizontalTail ? bubbleTailExtent : 0);
    final cardHeight =
        size.height - (tail == SpeechBubbleTail.bottom ? bubbleTailExtent : 0);
    final highTextScale = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: SpeechBubble(
        tail: tail,
        width: cardWidth,
        height: cardHeight,
        semanticLabel: '$reminderTitle，是时候做$exerciseName运动了',
        padding: obedient
            ? const EdgeInsets.fromLTRB(11, 14, 11, 5)
            : const EdgeInsets.fromLTRB(13, 11, 13, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ReminderHeader(
              obedient: obedient,
              title: reminderTitle,
              subtitle: obedient ? '缓一口气，别绷太紧。' : '该做$exerciseName运动了。',
              hideSubtitle: highTextScale,
            ),
            SizedBox(height: obedient ? 5 : 8),
            _ReminderActions(
              compact: obedient,
              onComplete: onComplete,
              onSkip: onSkip,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderHeader extends StatelessWidget {
  const _ReminderHeader({
    required this.obedient,
    required this.title,
    required this.subtitle,
    required this.hideSubtitle,
  });

  final bool obedient;
  final String title;
  final String subtitle;
  final bool hideSubtitle;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Container(
            width: obedient ? 28 : 32,
            height: obedient ? 28 : 32,
            decoration: BoxDecoration(
              color: obedient ? AppColors.accentSoft : AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              obedient ? Icons.spa_rounded : Icons.notifications_rounded,
              color: obedient ? AppColors.accent : AppColors.coral,
              size: obedient ? 16 : 18,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: obedient ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                if (!hideSubtitle) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: obedient ? 11.5 : 12,
                      fontWeight: FontWeight.w500,
                      height: 1.05,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
}

class _ReminderActions extends StatelessWidget {
  const _ReminderActions({
    required this.compact,
    required this.onComplete,
    required this.onSkip,
  });

  final bool compact;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Row(
        key: _reminderActionsKey,
        children: <Widget>[
          Expanded(
            child: _BubbleAction(
              buttonKey: _primaryActionKey,
              label: '完成了',
              height: compact ? 29 : 32,
              filled: true,
              onTap: onComplete,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BubbleAction(
              buttonKey: _secondaryActionKey,
              label: '晚点再说',
              height: compact ? 29 : 32,
              filled: false,
              onTap: onSkip,
            ),
          ),
        ],
      );
}

class _BubbleAction extends StatelessWidget {
  const _BubbleAction({
    required this.buttonKey,
    required this.label,
    required this.height,
    required this.filled,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final double height;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(9);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        key: buttonKey,
        height: height,
        child: Material(
          color: filled ? AppColors.accent : AppColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: filled
                ? BorderSide.none
                : const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
