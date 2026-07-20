import 'dart:io';

import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/widgets/app_components.dart';
import 'package:ass_timer_flutter/features/onboarding/circular_interval_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _OnboardingStep { profile, timing, group }

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _nicknameController = TextEditingController();
  final _groupController = TextEditingController();
  final _inviteController = TextEditingController();
  _OnboardingStep _step = _OnboardingStep.profile;
  String? _avatarPath;
  int _intervalSeconds = 2400;
  bool _createGroup = true;

  @override
  void dispose() {
    _nicknameController.dispose();
    _groupController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Row(
        children: <Widget>[
          _Sidebar(step: _step),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : context.visualTokens.transitionDuration,
                    child: switch (_step) {
                      _OnboardingStep.profile => _profile(controller),
                      _OnboardingStep.timing => _timing(),
                      _OnboardingStep.group => _group(controller),
                    },
                  ),
                ),
                const Divider(height: 1),
                _footer(controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profile(AppController controller) => ListView(
        key: const ValueKey('profile'),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
        children: <Widget>[
          const AppPageTitle(
            '认识一下',
            subtitle: '先留个称呼和头像，群里的损友才知道该喊谁。',
          ),
          const SizedBox(height: 22),
          AppCard(
            child: Row(
              children: <Widget>[
                Semantics(
                  button: true,
                  label: '选择头像',
                  child: InkWell(
                    onTap: controller.isBusy ? null : _pickAvatar,
                    borderRadius: BorderRadius.circular(52),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.accentSoft,
                      foregroundImage: _avatarPath == null
                          ? null
                          : FileImage(File(_avatarPath!)),
                      child: _avatarPath == null
                          ? const Icon(Icons.add_a_photo_rounded, size: 28)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '怎么称呼你',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nicknameController,
                        autofocus: true,
                        maxLength: 12,
                        decoration: const InputDecoration(
                          hintText: '2–12 个字符',
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _avatarPath == null ? '点左边选张头像。' : '行，认住你了。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _timing() => Padding(
        key: const ValueKey('timing'),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppPageTitle(
              '定个节奏',
              subtitle: '拖一圈选提醒间隔。先舒服地坚持，比一上来较劲靠谱。',
            ),
            const Spacer(),
            Center(
              child: CircularIntervalPicker(
                seconds: _intervalSeconds,
                onChanged: (value) => setState(() => _intervalSeconds = value),
              ),
            ),
            const Spacer(),
            const AppInlineNotice(message: '之后随时能在“提醒”里改。'),
          ],
        ),
      );

  Widget _group(AppController controller) => ListView(
        key: const ValueKey('group'),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
        children: <Widget>[
          const AppPageTitle(
            '找个搭子',
            subtitle: '建个群，或者拿 6 位邀请码进去。互相监督，少装死。',
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment(
                        value: true,
                        label: Text('创建群组'),
                        icon: Icon(Icons.group_add_outlined)),
                    ButtonSegment(
                        value: false,
                        label: Text('加入群组'),
                        icon: Icon(Icons.login_outlined)),
                  ],
                  selected: <bool>{_createGroup},
                  onSelectionChanged: controller.isBusy
                      ? null
                      : (selection) =>
                          setState(() => _createGroup = selection.first),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller:
                      _createGroup ? _groupController : _inviteController,
                  maxLength: _createGroup ? 50 : 6,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: _createGroup ? '群组名称' : '6 位邀请码',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (controller.snapshot.lastError != null) ...<Widget>[
                  const SizedBox(height: 10),
                  AppInlineNotice(
                    message: controller.snapshot.lastError!,
                    tone: AppFeedbackTone.danger,
                  ),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _footer(AppController controller) {
    final canContinue = switch (_step) {
      _OnboardingStep.profile =>
        _nicknameController.text.trim().length >= 2 && _avatarPath != null,
      _OnboardingStep.timing => true,
      _OnboardingStep.group => _createGroup
          ? _groupController.text.trim().isNotEmpty
          : _inviteController.text.trim().length == 6,
    };
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
        child: Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _step == _OnboardingStep.profile || controller.isBusy
                  ? null
                  : _back,
              icon: const Icon(Icons.chevron_left),
              label: const Text('返回'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: !canContinue || controller.isBusy
                  ? null
                  : () => _continue(controller),
              child: controller.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_step == _OnboardingStep.group ? '完成' : '继续'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    const typeGroup = XTypeGroup(
      label: '图片',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp'],
      uniformTypeIdentifiers: <String>['public.image'],
    );
    final file =
        await openFile(acceptedTypeGroups: const <XTypeGroup>[typeGroup]);
    if (file != null && mounted) setState(() => _avatarPath = file.path);
  }

  Future<void> _continue(AppController controller) async {
    try {
      switch (_step) {
        case _OnboardingStep.profile:
          await controller.createProfile(
            _nicknameController.text,
            _avatarPath!,
          );
          setState(() => _step = _OnboardingStep.timing);
        case _OnboardingStep.timing:
          setState(() => _step = _OnboardingStep.group);
        case _OnboardingStep.group:
          if (_createGroup) {
            await controller.createGroup(_groupController.text);
          } else {
            await controller.joinGroup(_inviteController.text);
          }
          await controller.completeOnboarding(_intervalSeconds);
      }
    } on Object {
      // Controller exposes a localized inline error and resets busy state.
    }
  }

  void _back() => setState(() {
        _step = _OnboardingStep.values[_step.index - 1];
      });
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.sidebar,
        child: SizedBox(
          width: 180,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '该提肛了',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 4, 6, 18),
                  child: Text('三步就完事',
                      style: TextStyle(
                          color: AppColors.secondaryText, fontSize: 12)),
                ),
                for (final value in _OnboardingStep.values)
                  _StepRow(
                      value: value,
                      active: value == step,
                      complete: value.index < step.index),
                const Spacer(),
                Center(
                  child: Image.asset(
                    'assets/sprites/得意.png',
                    width: 102,
                    height: 118,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    '放心，不会很严肃。',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow(
      {required this.value, required this.active, required this.complete});

  final _OnboardingStep value;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final labels = <_OnboardingStep, String>{
      _OnboardingStep.profile: '认识一下',
      _OnboardingStep.timing: '定个节奏',
      _OnboardingStep.group: '找个搭子',
    };
    final icons = <_OnboardingStep, IconData>{
      _OnboardingStep.profile: Icons.account_circle_outlined,
      _OnboardingStep.timing: Icons.timer_outlined,
      _OnboardingStep.group: Icons.group_outlined,
    };
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.surface : Colors.transparent,
        border:
            Border.all(color: active ? AppColors.border : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(complete ? Icons.check_circle : icons[value],
              size: 18,
              color: active ? AppColors.accent : AppColors.secondaryText),
          const SizedBox(width: 10),
          Text(labels[value]!,
              style: TextStyle(
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400)),
        ],
      ),
    );
  }
}
