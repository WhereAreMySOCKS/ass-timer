import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BubbleWindowView extends ConsumerWidget {
  const BubbleWindowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    final bubble = controller.snapshot.bubbles.firstOrNull;
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: bubble == null
            ? const SizedBox.shrink()
            : _BubbleCard(bubble: bubble, controller: controller),
      ),
    );
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({required this.bubble, required this.controller});

  final BubbleItem bubble;
  final AppController controller;

  @override
  Widget build(BuildContext context) => Container(
        width: 300,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        decoration: BoxDecoration(
          color: AppColors.comicPaper,
          border: Border.all(color: AppColors.comicInk, width: 3),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x38000000), blurRadius: 0, offset: Offset(5, 6)),
          ],
        ),
        child: switch (bubble.kind) {
          BubbleKind.reminder => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(controller.reminderTitle,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('是时候做一下${controller.exerciseName}运动了'),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                        child: OutlinedButton(
                            onPressed: controller.skipReminder,
                            child: const Text('稍后提醒'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: FilledButton(
                            onPressed: controller.completeReminder,
                            child: Text(controller.completionTitle))),
                  ],
                ),
              ],
            ),
          BubbleKind.groupEvent => Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                      text: bubble.senderNickname ?? '群友',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' 完成了一次${controller.exerciseName}！'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          BubbleKind.chatMessage => InkWell(
              onTap: () => controller.openControlCenter(
                ControlRoute.chat,
                groupId: bubble.groupId,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(bubble.senderNickname ?? '新消息',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(bubble.message ?? '',
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
        },
      );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
