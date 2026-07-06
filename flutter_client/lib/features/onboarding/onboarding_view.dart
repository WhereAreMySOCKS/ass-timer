import 'dart:io';

import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
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
      body: Row(
        children: <Widget>[
          _Sidebar(step: _step),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
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

  Widget _profile(AppController controller) => Center(
        key: const ValueKey('profile'),
        child: SizedBox(
          width: 480,
          child: Row(
            children: <Widget>[
              Semantics(
                button: true,
                label: '选择头像',
                child: InkWell(
                  onTap: controller.isBusy ? null : _pickAvatar,
                  borderRadius: BorderRadius.circular(52),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.accentSoft,
                    foregroundImage: _avatarPath == null
                        ? null
                        : FileImage(File(_avatarPath!)),
                    child: _avatarPath == null
                        ? const Icon(Icons.add_a_photo_outlined, size: 30)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('昵称',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nicknameController,
                      autofocus: true,
                      maxLength: 12,
                      decoration: const InputDecoration(
                        hintText: '2-12 个字符',
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _avatarPath == null ? '请选择头像' : '头像已选择',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _timing() => Center(
        key: const ValueKey('timing'),
        child: CircularIntervalPicker(
          seconds: _intervalSeconds,
          onChanged: (value) => setState(() => _intervalSeconds = value),
        ),
      );

  Widget _group(AppController controller) => Center(
        key: const ValueKey('group'),
        child: SizedBox(
          width: 420,
          child: AppCard(
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
                  Text(
                    controller.snapshot.lastError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
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
          width: 146,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('该提肛了',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 4, 6, 18),
                  child: Text('初始化',
                      style: TextStyle(
                          color: AppColors.secondaryText, fontSize: 12)),
                ),
                for (final value in _OnboardingStep.values)
                  _StepRow(
                      value: value,
                      active: value == step,
                      complete: value.index < step.index),
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
      _OnboardingStep.profile: '资料',
      _OnboardingStep.timing: '间隔',
      _OnboardingStep.group: '群组',
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
        color:
            active ? Colors.white.withValues(alpha: 0.9) : Colors.transparent,
        border:
            Border.all(color: active ? AppColors.border : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
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
