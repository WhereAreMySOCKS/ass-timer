import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppFeedbackTone { neutral, success, warning, danger }

class AppInlineNotice extends StatelessWidget {
  const AppInlineNotice({
    required this.message,
    super.key,
    this.tone = AppFeedbackTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppFeedbackTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (tone) {
      AppFeedbackTone.neutral => (
          AppColors.muted,
          AppColors.secondaryText,
          Icons.info_outline_rounded,
        ),
      AppFeedbackTone.success => (
          AppColors.accentSoft,
          AppColors.accent,
          Icons.check_circle_outline_rounded,
        ),
      AppFeedbackTone.warning => (
          AppColors.warningSoft,
          AppColors.warning,
          Icons.schedule_rounded,
        ),
      AppFeedbackTone.danger => (
          AppColors.dangerSoft,
          AppColors.danger,
          Icons.error_outline_rounded,
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius:
              BorderRadius.circular(context.visualTokens.controlRadius),
          border: Border.all(color: foreground.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

class AppPageTitle extends StatelessWidget {
  const AppPageTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 5),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(dialogContext).pop(false),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: destructive
                              ? AppColors.dangerSoft
                              : AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          destructive
                              ? Icons.warning_amber_rounded
                              : Icons.help_outline_rounded,
                          color:
                              destructive ? AppColors.danger : AppColors.accent,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(dialogContext)
                              .dialogTheme
                              .titleTextStyle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton(
                        autofocus: true,
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: destructive
                            ? FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              )
                            : null,
                        child: Text(confirmLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
