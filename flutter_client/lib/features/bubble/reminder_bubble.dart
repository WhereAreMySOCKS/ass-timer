import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/window/bubble_layout.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:flutter/material.dart';

const Color _toastSurface = Color(0xFFFFFCF5);
const Color _toastBorder = Color(0xFFE4D6C1);
const Color _toastShadow = Color(0x24000000);
const Color _accent = Color(0xFF12AA98);
const Color _accentPressed = Color(0xFF078777);
const Color _accentSoft = Color(0xFFE6F7F4);
const Color _secondaryText = Color(0xFF756B61);
const Color _quietFill = Color(0xFFFFF8EA);
const Color _quietBorder = Color(0xFFD9C8AE);
const Color _warn = Color(0xFFFF6A5F);

const Key _reminderActionsKey = ValueKey<String>('reminder-actions');
const Key _primaryActionKey = ValueKey<String>('reminder-primary-action');
const Key _secondaryActionKey = ValueKey<String>('reminder-secondary-action');

class ReminderBubble extends StatelessWidget {
  const ReminderBubble({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ReminderBubbleContent(
        obedient: controller.snapshot.config.appMode == AppMode.obedient,
        reminderTitle: controller.reminderTitle,
        exerciseName: controller.exerciseName,
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
    super.key,
  });

  final bool obedient;
  final String reminderTitle;
  final String exerciseName;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final spec = obedient
        ? _ToastSpec.obedient()
        : _ToastSpec.standard(
            reminderTitle: reminderTitle,
            exerciseName: exerciseName,
          );

    return _ReminderToast(
      spec: spec,
      onComplete: onComplete,
      onSkip: onSkip,
    );
  }
}

class _ToastSpec {
  const _ToastSpec({
    required this.size,
    required this.padding,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titleSize,
    required this.subtitleSize,
    required this.buttonHeight,
    required this.primaryWidth,
    required this.secondaryWidth,
    required this.compact,
  });

  factory _ToastSpec.standard({
    required String reminderTitle,
    required String exerciseName,
  }) =>
      _ToastSpec(
        size: normalBubbleContentSize,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        icon: Icons.notifications_rounded,
        iconColor: _warn,
        title: reminderTitle,
        subtitle: '是时候做$exerciseName运动了',
        titleSize: 15,
        subtitleSize: 12.5,
        buttonHeight: 30,
        primaryWidth: 72,
        secondaryWidth: 72,
        compact: false,
      );

  factory _ToastSpec.obedient() => const _ToastSpec(
        size: obedientBubbleContentSize,
        padding: EdgeInsets.fromLTRB(11, 10, 11, 10),
        icon: Icons.spa_rounded,
        iconColor: _accent,
        title: '该放松了',
        subtitle: '缓一口气',
        titleSize: 15,
        subtitleSize: 12,
        buttonHeight: 28,
        primaryWidth: 64,
        secondaryWidth: 64,
        compact: true,
      );

  final Size size;
  final EdgeInsets padding;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final double titleSize;
  final double subtitleSize;
  final double buttonHeight;
  final double primaryWidth;
  final double secondaryWidth;
  final bool compact;
}

class _ReminderToast extends StatelessWidget {
  const _ReminderToast({
    required this.spec,
    required this.onComplete,
    required this.onSkip,
  });

  final _ToastSpec spec;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: spec.size.width,
        height: spec.size.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _toastSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _toastBorder, width: 1.2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _toastShadow,
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Row(
              children: <Widget>[
                Container(width: 5, color: spec.iconColor),
                Expanded(
                  child: Padding(
                    padding: spec.padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _ToastHeader(spec: spec),
                        SizedBox(height: spec.compact ? 7 : 8),
                        _ReminderActions(
                          onComplete: onComplete,
                          onSkip: onSkip,
                          height: spec.buttonHeight,
                          primaryWidth: spec.primaryWidth,
                          secondaryWidth: spec.secondaryWidth,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ToastHeader extends StatelessWidget {
  const _ToastHeader({required this.spec});

  final _ToastSpec spec;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: spec.compact ? 28 : 30,
            height: spec.compact ? 28 : 30,
            decoration: BoxDecoration(
              color: spec.iconColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              spec.icon,
              color: spec.iconColor,
              size: spec.compact ? 16 : 17,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.comicInk,
                    fontSize: spec.titleSize,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: spec.subtitleSize,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _ReminderActions extends StatelessWidget {
  const _ReminderActions({
    required this.onComplete,
    required this.onSkip,
    required this.height,
    required this.primaryWidth,
    required this.secondaryWidth,
  });

  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final double height;
  final double primaryWidth;
  final double secondaryWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final preferredWidth =
              primaryWidth > secondaryWidth ? primaryWidth : secondaryWidth;
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : preferredWidth * 2 + gap;
          final buttonWidth =
              ((availableWidth - gap) / 2).clamp(0, preferredWidth);

          return Row(
            key: _reminderActionsKey,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ToastActionButton(
                buttonKey: _primaryActionKey,
                label: '收到',
                width: buttonWidth.toDouble(),
                height: height,
                filled: true,
                onTap: onComplete,
              ),
              const SizedBox(width: gap),
              _ToastActionButton(
                buttonKey: _secondaryActionKey,
                label: '等会',
                width: buttonWidth.toDouble(),
                height: height,
                filled: false,
                onTap: onSkip,
              ),
            ],
          );
        },
      );
}

class _ToastActionButton extends StatelessWidget {
  const _ToastActionButton({
    this.buttonKey,
    required this.label,
    required this.width,
    required this.height,
    required this.filled,
    required this.onTap,
  });

  final Key? buttonKey;
  final String label;
  final double width;
  final double height;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(9);
    final foreground = filled ? Colors.white : AppColors.comicInk;
    final background = filled ? _accent : _quietFill;
    final border =
        filled ? BorderSide.none : const BorderSide(color: _quietBorder);

    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          key: buttonKey,
          width: width,
          height: height,
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: border,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: RoundedRectangleBorder(borderRadius: radius),
              splashColor: (filled ? Colors.white : _accent)
                  .withValues(alpha: filled ? 0.16 : 0.08),
              highlightColor: (filled ? _accentPressed : _accentSoft)
                  .withValues(alpha: filled ? 0.28 : 0.7),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
