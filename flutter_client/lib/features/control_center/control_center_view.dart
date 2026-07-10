import 'dart:async';
import 'dart:io';

import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/features/onboarding/circular_interval_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

class ControlCenterView extends ConsumerStatefulWidget {
  const ControlCenterView({super.key, this.initialRoute});

  final ControlRoute? initialRoute;

  @override
  ConsumerState<ControlCenterView> createState() => _ControlCenterViewState();
}

class _ControlCenterViewState extends ConsumerState<ControlCenterView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(appControllerProvider);
      unawaited(controller.refreshGroups());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final route = controller.controlRoute;
    if (route == ControlRoute.chat) {
      return _SecondaryWindowScaffold(
        controller: controller,
        child: _ChatPane(controller: controller, standalone: true),
      );
    }
    if (route == ControlRoute.leaderboard) {
      return _SecondaryWindowScaffold(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: _LeaderboardPane(controller: controller, standalone: true),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: <Widget>[
          _SettingsTabBar(
            selected: route,
            onSelected: controller.selectControlRoute,
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                if (controller.snapshot.lastError != null)
                  MaterialBanner(
                    content: Text(controller.snapshot.lastError!),
                    leading: const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                    ),
                    actions: const <Widget>[SizedBox.shrink()],
                  ),
                Expanded(
                  child: switch (route) {
                    ControlRoute.timer => _TimerPane(controller: controller),
                    ControlRoute.groups => Padding(
                        padding: const EdgeInsets.all(16),
                        child: _GroupsPane(controller: controller),
                      ),
                    ControlRoute.media => _MediaPane(controller: controller),
                    ControlRoute.about => _AboutPane(controller: controller),
                    ControlRoute.chat ||
                    ControlRoute.leaderboard =>
                      const SizedBox.shrink(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryWindowScaffold extends StatelessWidget {
  const _SecondaryWindowScaffold({
    required this.controller,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final AppController controller;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: <Widget>[
            if (controller.snapshot.lastError != null)
              MaterialBanner(
                content: Text(controller.snapshot.lastError!),
                leading: const Icon(Icons.wifi_off, color: AppColors.danger),
                actions: const <Widget>[SizedBox.shrink()],
              ),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
          ],
        ),
      );
}

class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({required this.selected, required this.onSelected});

  final ControlRoute selected;
  final ValueChanged<ControlRoute> onSelected;

  @override
  Widget build(BuildContext context) {
    const entries = <(ControlRoute, String)>[
      (ControlRoute.timer, '提醒'),
      (ControlRoute.groups, '群组'),
      (ControlRoute.media, '素材'),
      (ControlRoute.about, '关于'),
    ];
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: 52,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(child: DragToMoveArea(child: SizedBox())),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var index = 0; index < entries.length; index++) ...[
                        if (index > 0)
                          Container(
                            width: 1,
                            height: 18,
                            color: Colors.black.withValues(alpha: 0.07),
                          ),
                        _SettingsTabButton(
                          label: entries[index].$2,
                          selected: selected == entries[index].$1,
                          onPressed: () => onSelected(entries[index].$1),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  const _SettingsTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(17),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 32,
            constraints: const BoxConstraints(minWidth: 54),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.black.withValues(alpha: 0.075)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.text : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      );
}

class _PaneTitle extends StatelessWidget {
  const _PaneTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
        ],
      );
}

class _TimerPane extends StatefulWidget {
  const _TimerPane({required this.controller});

  final AppController controller;

  @override
  State<_TimerPane> createState() => _TimerPaneState();
}

class _TimerPaneState extends State<_TimerPane> {
  late int seconds = widget.controller.snapshot.config.intervalSeconds;
  bool saved = false;
  Timer? savedTimer;

  @override
  void dispose() {
    savedTimer?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.controller.modifyInterval(seconds);
    if (!mounted) return;
    savedTimer?.cancel();
    setState(() => saved = true);
    savedTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => saved = false);
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Spacer(),
            CircularIntervalPicker(
              seconds: seconds,
              onChanged: (value) => setState(() => seconds = value),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: Icon(
                  saved ? Icons.check : Icons.arrow_circle_down_outlined,
                  size: 17,
                ),
                label: Text(saved ? '已保存' : '保存设置'),
              ),
            ),
            const Spacer(),
          ],
        ),
      );
}

class _GroupsPane extends StatefulWidget {
  const _GroupsPane({required this.controller});

  final AppController controller;

  @override
  State<_GroupsPane> createState() => _GroupsPaneState();
}

class _GroupsPaneState extends State<_GroupsPane> {
  final createController = TextEditingController();
  final joinController = TextEditingController();
  final Set<String> expandedGroups = <String>{};

  @override
  void dispose() {
    createController.dispose();
    joinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: widget.controller.groups.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: widget.controller.groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildGroupCard(widget.controller.groups[index]),
                  ),
          ),
          const SizedBox(height: 12),
          _buildActions(),
        ],
      );

  Widget _buildHeader() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '群组',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '管理同步完成记录的群组和邀请码。',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: '刷新群组',
            onPressed: widget.controller.refreshGroups,
            icon: const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      );

  Widget _buildEmptyState() => Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.groups_2_outlined, size: 32, color: AppColors.accent),
              SizedBox(height: 12),
              Text(
                '还没有群组',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '创建一个群组，或用邀请码加入已有群组。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _buildGroupCard(GroupInfo group) {
    final isExpanded = expandedGroups.contains(group.groupId);
    final groupName = group.name.isEmpty ? '未命名群组' : group.name;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: <Widget>[
            InkWell(
              onTap: () => _toggleGroup(group.groupId),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.groups_2_outlined,
                        color: Color(0xFF174A8B),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _MetaPill(
                            icon: Icons.person_outline_rounded,
                            label: '${group.members.length} 位成员',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isExpanded ? '收起' : '展开',
                      onPressed: () => _toggleGroup(group.groupId),
                      icon: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _buildGroupDetails(group),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 160),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDetails(GroupInfo group) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Divider(height: 1),
            const SizedBox(height: 13),
            _SectionLabel(
              icon: Icons.key_rounded,
              label: '邀请码',
              trailing: TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: group.inviteCode),
                ),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('复制'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final character in group.inviteCode.characters)
                  _InviteCodeCell(character: character),
              ],
            ),
            const SizedBox(height: 14),
            const _SectionLabel(icon: Icons.badge_outlined, label: '成员'),
            const SizedBox(height: 8),
            if (group.members.isEmpty)
              const Text(
                '暂无成员信息',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final member in group.members) _memberChip(member),
                ],
              ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmLeave(group),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('退出群组'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _memberChip(GroupMember member) {
    final isMe = member.userId == widget.controller.snapshot.config.userId;
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 11,
            backgroundColor: Colors.white,
            child: Text(member.petEmoji, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 6),
          Text(
            member.nickname,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isMe) ...<Widget>[
            const SizedBox(width: 5),
            const Text(
              '我',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() => DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: <Widget>[
              SizedBox(
                height: 40,
                width: 148,
                child: FilledButton.icon(
                  onPressed: _showCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('创建群组'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                width: 148,
                child: OutlinedButton.icon(
                  onPressed: _showJoin,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('加入群组'),
                ),
              ),
            ],
          ),
        ),
      );

  void _toggleGroup(String groupId) => setState(() {
        if (expandedGroups.contains(groupId)) {
          expandedGroups.remove(groupId);
        } else {
          expandedGroups.add(groupId);
        }
      });

  Future<void> _showCreate() => _textDialog(
        title: '创建群组',
        label: '群组名称',
        controller: createController,
        onSubmit: () => widget.controller.createGroup(createController.text),
      );

  Future<void> _showJoin() => _textDialog(
        title: '加入群组',
        label: '6 位邀请码',
        controller: joinController,
        onSubmit: () => widget.controller.joinGroup(joinController.text),
      );

  Future<void> _textDialog({
    required String title,
    required String label,
    required TextEditingController controller,
    required Future<void> Function() onSubmit,
  }) async {
    controller.clear();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await onSubmit();
                if (context.mounted) Navigator.of(context).pop();
              } on Object {
                // The controller exposes the localized error in the banner.
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(GroupInfo group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出群组？'),
        content: Text('确定退出“${group.name}”吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.leaveGroup(group.groupId);
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: AppColors.secondaryText),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.secondaryText),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      );
}

class _InviteCodeCell extends StatelessWidget {
  const _InviteCodeCell({required this.character});

  final String character;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          border: Border.all(color: const Color(0xFFC8DCF7)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          character,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      );
}

class _ChatPane extends StatefulWidget {
  const _ChatPane({required this.controller, this.standalone = false});

  final AppController controller;
  final bool standalone;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final input = TextEditingController();
  String? requestedGroupId;
  bool sending = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final joined = widget.controller.snapshot.config.joinedGroups;
    final selected =
        widget.controller.activeChatGroupId ?? joined.firstOrNull?.groupId;
    if (selected != null && requestedGroupId != selected) {
      requestedGroupId = selected;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(widget.controller.loadChat(selected));
      });
    }
    final messages =
        widget.controller.chatMessages[selected] ?? <ChatMessage>[];
    final selectedGroup = selected == null
        ? null
        : widget.controller.groups
            .where((group) => group.groupId == selected)
            .toList()
            .firstOrNull;
    final selectedJoinedGroup = selected == null
        ? null
        : joined
            .where((group) => group.groupId == selected)
            .toList()
            .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!widget.standalone)
          const _PaneTitle('群聊', subtitle: '消息会实时同步，并在本地保留每个群组最近 100 条。'),
        if (joined.isEmpty)
          const Expanded(child: Center(child: Text('加入群组后即可开始聊天')))
        else
          Expanded(
            child: Container(
              decoration: widget.standalone
                  ? const BoxDecoration(color: Colors.white)
                  : BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.standalone ? 0 : 10),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 150,
                      child: ColoredBox(
                        color: AppColors.muted,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(6),
                          itemCount: joined.length,
                          itemBuilder: (context, index) {
                            final group = joined[index];
                            final unread = widget.controller.snapshot
                                    .unreadCounts[group.groupId] ??
                                0;
                            final isSelected = group.groupId == selected;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                minTileHeight: 42,
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                title: Text(
                                  group.groupName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: unread > 0
                                    ? Badge(label: Text('$unread'))
                                    : null,
                                onTap: () => _loadGroup(group.groupId),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    selectedGroup?.name ??
                                        selectedJoinedGroup?.groupName ??
                                        '群聊',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (selectedGroup != null)
                                  Text(
                                    '${selectedGroup.members.length} 人',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                const SizedBox(width: 8),
                                _ConnectionBadge(
                                  state:
                                      widget.controller.backendConnectionState,
                                ),
                                const SizedBox(width: 6),
                                if (selectedGroup != null)
                                  OutlinedButton.icon(
                                    onPressed: () => Clipboard.setData(
                                      ClipboardData(
                                        text: selectedGroup.inviteCode,
                                      ),
                                    ),
                                    icon: const Icon(Icons.numbers, size: 15),
                                    label: const Text('邀请码'),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: messages.isEmpty
                                ? const Center(child: Text('还没有消息'))
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final message = messages[index];
                                      final own = message.userId ==
                                          widget.controller.snapshot.config
                                              .userId;
                                      return _ChatMessageRow(
                                        controller: widget.controller,
                                        message: message,
                                        own: own,
                                      );
                                    },
                                  ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: input,
                                    maxLength: 2000,
                                    onSubmitted: (_) => _send(selected),
                                    decoration: const InputDecoration(
                                      hintText: '输入消息',
                                      counterText: '',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  tooltip: sending ? '正在发送' : '发送消息',
                                  onPressed: selected == null || sending
                                      ? null
                                      : () => _send(selected),
                                  icon: sending
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _send(String? groupId) async {
    if (groupId == null || input.text.trim().isEmpty) return;
    final content = input.text;
    input.clear();
    setState(() => sending = true);
    try {
      await widget.controller.sendChat(groupId, content);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  void _loadGroup(String groupId) {
    if (requestedGroupId == groupId) return;
    setState(() => requestedGroupId = groupId);
    unawaited(widget.controller.loadChat(groupId));
  }
}

class _ChatMessageRow extends StatelessWidget {
  const _ChatMessageRow({
    required this.controller,
    required this.message,
    required this.own,
  });

  final AppController controller;
  final ChatMessage message;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final avatar = _UserAvatar(
      controller: controller,
      avatarUrl: message.avatarUrl,
      fallback: message.petEmoji,
    );
    final bubble = Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: own ? AppColors.accentSoft : AppColors.muted,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    own ? '我' : message.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatMessageTime(message.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(message.content),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            own ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: own
            ? <Widget>[bubble, const SizedBox(width: 7), avatar]
            : <Widget>[avatar, const SizedBox(width: 7), bubble],
      ),
    );
  }
}

class _UserAvatar extends StatefulWidget {
  const _UserAvatar({
    required this.controller,
    required this.avatarUrl,
    required this.fallback,
    this.size = 30,
  });

  final AppController controller;
  final String avatarUrl;
  final String fallback;
  final double size;

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  Future<String?>? pathFuture;

  @override
  void initState() {
    super.initState();
    _refreshPath();
  }

  @override
  void didUpdateWidget(covariant _UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) _refreshPath();
  }

  void _refreshPath() {
    pathFuture = widget.avatarUrl.trim().isEmpty
        ? null
        : widget.controller.cachedAvatarPath(widget.avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final fallbackWidget = Center(
      child: Text(
        widget.fallback,
        style: TextStyle(fontSize: widget.size * 0.5),
      ),
    );
    return Semantics(
      image: true,
      label: '用户头像',
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.accentSoft,
          child: SizedBox.square(
            dimension: widget.size,
            child: pathFuture == null
                ? fallbackWidget
                : FutureBuilder<String?>(
                    future: pathFuture,
                    builder: (context, snapshot) {
                      final path = snapshot.data;
                      return path == null
                          ? fallbackWidget
                          : Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => fallbackWidget,
                            );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

String _formatMessageTime(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.state});

  final BackendConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      BackendConnectionState.connected => (AppColors.success, '实时已连接'),
      BackendConnectionState.connecting => (const Color(0xFFB56A00), '正在重连'),
      BackendConnectionState.disconnected => (AppColors.danger, '实时已断开'),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _LeaderboardPane extends StatefulWidget {
  const _LeaderboardPane({required this.controller, this.standalone = false});

  final AppController controller;
  final bool standalone;

  @override
  State<_LeaderboardPane> createState() => _LeaderboardPaneState();
}

class _LeaderboardPaneState extends State<_LeaderboardPane> {
  String? selected;
  String? loadedGroup;
  Timer? refreshTimer;

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  void _selectGroup(String groupId) {
    setState(() => selected = groupId);
    loadedGroup = groupId;
    unawaited(_refresh(groupId));
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refresh(groupId));
    });
  }

  Future<void> _refresh(String groupId) async {
    await widget.controller.refreshLeaderboard(groupId);
    if (widget.controller.leaderboardError != null) refreshTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.controller.snapshot.config.joinedGroups;
    selected ??= groups.firstOrNull?.groupId;
    if (selected != null && loadedGroup != selected) {
      loadedGroup = selected;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && selected != null) _selectGroup(selected!);
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.standalone)
          Row(
            children: <Widget>[
              const Icon(Icons.emoji_events, color: Color(0xFFD99A00)),
              const SizedBox(width: 7),
              const Text(
                '排行榜',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (groups.isNotEmpty && selected != null)
                DropdownButton<String>(
                  value: selected,
                  underline: const SizedBox.shrink(),
                  items: groups
                      .map(
                        (group) => DropdownMenuItem(
                          value: group.groupId,
                          child: Text(
                            group.groupName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _selectGroup(value);
                  },
                ),
              IconButton(
                tooltip: '刷新排行榜',
                onPressed: selected == null
                    ? null
                    : () => widget.controller.refreshLeaderboard(selected!),
                icon: const Icon(Icons.refresh, size: 19),
              ),
            ],
          )
        else
          const _PaneTitle('排行榜', subtitle: '查看群组成员累计完成次数。'),
        if (groups.isEmpty)
          const Expanded(child: Center(child: Text('加入群组后即可查看排行榜')))
        else if (selected != null && !widget.standalone)
          Row(
            children: <Widget>[
              DropdownButton<String>(
                value: selected,
                items: groups
                    .map(
                      (group) => DropdownMenuItem(
                        value: group.groupId,
                        child: Text(group.groupName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _selectGroup(value);
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新排行榜',
                onPressed: () =>
                    widget.controller.refreshLeaderboard(selected!),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        if (groups.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Expanded(
            child: widget.controller.leaderboardLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.controller.leaderboardError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.wifi_off_outlined,
                              color: AppColors.secondaryText,
                            ),
                            const SizedBox(height: 8),
                            Text(widget.controller.leaderboardError!),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: selected == null
                                  ? null
                                  : () => _selectGroup(selected!),
                              icon: const Icon(Icons.refresh, size: 17),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    : widget.controller.leaderboard.isEmpty
                        ? const Center(child: Text('暂无数据'))
                        : ListView.separated(
                            itemCount: widget.controller.leaderboard.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry =
                                  widget.controller.leaderboard[index];
                              final own = entry.userId ==
                                  widget.controller.snapshot.config.userId;
                              final medal = switch (entry.rank) {
                                1 => '🥇',
                                2 => '🥈',
                                3 => '🥉',
                                _ => '${entry.rank}',
                              };
                              return Container(
                                decoration: BoxDecoration(
                                  color: own
                                      ? AppColors.accentSoft
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 72,
                                    child: Row(
                                      children: <Widget>[
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            medal,
                                            style: TextStyle(
                                              fontSize:
                                                  entry.rank <= 3 ? 22 : 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        _UserAvatar(
                                          controller: widget.controller,
                                          avatarUrl: entry.avatarUrl,
                                          fallback: entry.petEmoji,
                                          size: 30,
                                        ),
                                      ],
                                    ),
                                  ),
                                  title: Text(
                                    entry.nickname,
                                    style: TextStyle(
                                      fontWeight: own
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  trailing: Text(
                                    '${entry.count} 次',
                                    style: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontFeatures: <FontFeature>[
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '我的总${widget.controller.exerciseName}：${widget.controller.snapshot.config.localEventCount} 次',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaPane extends StatelessWidget {
  const _MediaPane({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const slots = <(String, String, String, String)>[
      ('reminder', '提醒', '提醒出现时', 'assets/sprites/停止.png'),
      ('completion', '完成', '完成提肛后', 'assets/sprites/得意.png'),
      ('nap', '睡觉', '宠物趴下时', 'assets/sprites/趴.png'),
      ('interaction', '单击互动', '单击宠物后', 'assets/sprites/愤怒.png'),
      ('obedientPet', '听话模式宠物', '听话模式开启时', 'assets/sprites/得意.png'),
      ('docked', '吸附边缘', '吸附到屏幕边缘时', 'assets/sprites/后视镜.png'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PaneTitle('动作素材', subtitle: '为不同动作设置照片；未设置时显示默认素材。'),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.12,
              ),
              itemCount: slots.length,
              itemBuilder: (context, index) => _MediaSlotCard(
                controller: controller,
                slot: slots[index],
                onChoosePhoto: _choosePhoto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _choosePhoto(String slot) async {
    const group = XTypeGroup(
      label: '图片',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp'],
      uniformTypeIdentifiers: <String>['public.image'],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);
    if (file != null) await controller.saveCustomMedia(slot, file.path);
  }
}

class _MediaSlotCard extends StatelessWidget {
  const _MediaSlotCard({
    required this.controller,
    required this.slot,
    required this.onChoosePhoto,
  });

  final AppController controller;
  final (String, String, String, String) slot;
  final Future<void> Function(String slot) onChoosePhoto;

  @override
  Widget build(BuildContext context) {
    final entry = controller.snapshot.config.customActionMedia[slot.$1];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MediaPreview(
              controller: controller,
              entry: entry,
              fallbackAsset: slot.$4,
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    slot.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (entry?.removesBackground == true)
                  const Icon(
                    Icons.auto_fix_high,
                    size: 13,
                    color: AppColors.accent,
                  )
                else if (entry == null)
                  const Text(
                    '默认',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
            Text(
              slot.$3,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onChoosePhoto(slot.$1),
                    style: _mediaActionButtonStyle,
                    child: const Text('选择'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: entry == null ||
                            entry.removesBackground ||
                            !controller.supportsBackgroundRemoval
                        ? null
                        : () => controller.setBackgroundRemoval(
                              slot.$1,
                              true,
                            ),
                    style: _mediaActionButtonStyle,
                    child: const Text('去除背景'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton(
                    onPressed: entry == null
                        ? null
                        : () => controller.removeCustomMedia(slot.$1),
                    style: _mediaActionButtonStyle,
                    child: const Text('重置'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle get _mediaActionButtonStyle => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: const TextStyle(fontSize: 11),
        visualDensity: VisualDensity.compact,
      );
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.controller,
    required this.entry,
    required this.fallbackAsset,
  });

  final AppController controller;
  final CustomActionMediaEntry? entry;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: entry == null
            ? Image.asset(fallbackAsset, fit: BoxFit.contain)
            : FutureBuilder<String?>(
                future: controller.customMediaPreviewPath(entry!),
                builder: (context, snapshot) {
                  final path = snapshot.data;
                  return path == null
                      ? Image.asset(fallbackAsset, fit: BoxFit.contain)
                      : Image.file(
                          File(path),
                          key: ValueKey(entry!.revision),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Image.asset(fallbackAsset, fit: BoxFit.contain),
                        );
                },
              ),
      );
}

class _AboutPane extends StatefulWidget {
  const _AboutPane({required this.controller});

  final AppController controller;

  @override
  State<_AboutPane> createState() => _AboutPaneState();
}

class _AboutPaneState extends State<_AboutPane> {
  AppController get controller => widget.controller;

  late final Future<PackageInfo> packageInfo = PackageInfo.fromPlatform();
  bool uploadingAvatar = false;
  bool clearing = false;

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: packageInfo,
        builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    _UserAvatar(
                      controller: controller,
                      avatarUrl: controller.snapshot.config.avatarUrl ?? '',
                      fallback: controller.snapshot.config.petEmoji,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            controller.snapshot.config.nickname ?? '未设置昵称',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '账户头像',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: uploadingAvatar ? null : _chooseAvatar,
                      child: uploadingAvatar
                          ? const SizedBox.square(
                              dimension: 13,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('选择'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          controller.availableUpdate == null
                              ? Icons.check_circle
                              : Icons.system_update_alt,
                          size: 18,
                          color: controller.availableUpdate == null
                              ? const Color(0xFF32C759)
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.availableUpdate == null
                                ? '已是最新版本'
                                : '发现新版本 ${controller.availableUpdate!.latestVersion}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '当前版本 v${snapshot.data?.version ?? '—'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (controller.availableUpdate != null &&
                        controller.availableUpdate!.releaseNotes
                            .isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(controller.availableUpdate!.releaseNotes),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => controller.checkForUpdate(),
                      icon: const Icon(Icons.refresh, size: 17),
                      label: const Text('检查更新'),
                    ),
                    if (controller.availableUpdate != null) ...<Widget>[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(controller.availableUpdate!.downloadUrl),
                        ),
                        icon: const Icon(Icons.download, size: 17),
                        label: const Text('下载更新'),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: clearing ? null : () => _confirmClear(context),
                  icon: clearing
                      ? const SizedBox.square(
                          dimension: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 17),
                  label: Text(clearing ? '清除中…' : '清除本地数据'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    backgroundColor: AppColors.danger.withValues(alpha: 0.035),
                    side: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _chooseAvatar() async {
    const group = XTypeGroup(
      label: '头像',
      extensions: <String>['png', 'jpg', 'jpeg', 'gif', 'webp'],
      uniformTypeIdentifiers: <String>['public.image'],
    );
    final file = await openFile(acceptedTypeGroups: const <XTypeGroup>[group]);
    if (file == null || !mounted) return;
    setState(() => uploadingAvatar = true);
    try {
      await controller.updateAvatar(file.path);
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本地数据？'),
        content: const Text(
          '会清除昵称、群组、提醒进度、计数、聊天缓存和自定义素材，'
          '然后重新进入初始设置。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => clearing = true);
      await controller.clearLocalData();
      if (mounted) setState(() => clearing = false);
    }
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
