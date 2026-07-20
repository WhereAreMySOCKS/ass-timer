import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/widgets/speech_bubble.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/features/bubble/reminder_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BubbleWindowView extends ConsumerWidget {
  const BubbleWindowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final bubble = controller.snapshot.bubbles.firstOrNull;
    final tail = speechBubbleTailForDockSide(controller.snapshot.dockSide);
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : context.visualTokens.transitionDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: bubble == null
              ? const SizedBox.shrink(key: ValueKey<String>('empty-bubble'))
              : _BubbleCard(
                  key: ValueKey<String>(bubble.id),
                  bubble: bubble,
                  controller: controller,
                  tail: tail,
                ),
        ),
      ),
    );
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({
    required this.bubble,
    required this.controller,
    required this.tail,
    super.key,
  });

  final BubbleItem bubble;
  final AppController controller;
  final SpeechBubbleTail tail;

  @override
  Widget build(BuildContext context) {
    if (bubble.kind == BubbleKind.reminder) {
      return ReminderBubble(controller: controller, tail: tail);
    }
    if (bubble.kind == BubbleKind.feedback) {
      return _FeedbackBubbleContent(
        tail: tail,
        message: bubble.message ?? '行，记住了。',
        tone: bubble.feedbackTone ?? BubbleFeedbackTone.success,
      );
    }
    return SpeechBubble(
      width: tail == SpeechBubbleTail.bottom ? 264 : 254,
      tail: tail,
      semanticLabel: bubble.kind == BubbleKind.chatMessage
          ? '${bubble.senderNickname ?? '群友'}发来消息'
          : '群组动态',
      onTap: bubble.kind == BubbleKind.chatMessage
          ? () => controller.openControlCenter(
                ControlRoute.chat,
                groupId: bubble.groupId,
              )
          : null,
      child: switch (bubble.kind) {
        BubbleKind.reminder => const SizedBox.shrink(),
        BubbleKind.feedback => const SizedBox.shrink(),
        BubbleKind.groupEvent => _EventBubbleContent(
            icon: Icons.celebration_rounded,
            iconColor: AppColors.coral,
            title: '${bubble.senderNickname ?? '群友'}完成了一次',
            message: '${controller.exerciseName} +1，群里有人认真了。',
            showChevron: false,
          ),
        BubbleKind.chatMessage => _EventBubbleContent(
            icon: Icons.chat_bubble_rounded,
            iconColor: AppColors.accent,
            title: bubble.senderNickname ?? '新消息',
            message: bubble.message ?? '',
            showChevron: true,
          ),
      },
    );
  }
}

class _FeedbackBubbleContent extends StatelessWidget {
  const _FeedbackBubbleContent({
    required this.tail,
    required this.message,
    required this.tone,
  });

  final SpeechBubbleTail tail;
  final String message;
  final BubbleFeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final success = tone == BubbleFeedbackTone.success;
    final color = success ? AppColors.accent : AppColors.warning;
    return SpeechBubble(
      width: 224,
      tail: tail,
      semanticLabel: message,
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              success ? Icons.check_rounded : Icons.schedule_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventBubbleContent extends StatelessWidget {
  const _EventBubbleContent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.showChevron,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (showChevron) ...<Widget>[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.secondaryText,
            ),
          ],
        ],
      );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
