import 'dart:async';

import 'package:ass_timer_flutter/application/app_controller.dart';
import 'package:ass_timer_flutter/core/diagnostics/crash_reporter.dart';
import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:ass_timer_flutter/core/widgets/responsive_collection.dart';
import 'package:ass_timer_flutter/data/api_models.dart';
import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:ass_timer_flutter/features/onboarding/circular_interval_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    leading: const Icon(Icons.error_outline,
                        color: AppColors.danger),
                    actions: const <Widget>[SizedBox.shrink()],
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: switch (route) {
                      ControlRoute.timer => _TimerPane(controller: controller),
                      ControlRoute.groups =>
                        _GroupsPane(controller: controller),
                      ControlRoute.media => _MediaPane(controller: controller),
                      ControlRoute.about => _AboutPane(controller: controller),
                      ControlRoute.chat ||
                      ControlRoute.leaderboard =>
                        const SizedBox.shrink(),
                    },
                  ),
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
            Expanded(child: Padding(padding: padding, child: child)),
          ],
        ),
      );
}

class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({
    required this.selected,
    required this.onSelected,
  });

  final ControlRoute selected;
  final ValueChanged<ControlRoute> onSelected;

  @override
  Widget build(BuildContext context) {
    const entries = <(ControlRoute, IconData, String)>[
      (ControlRoute.timer, Icons.notifications_outlined, '提醒'),
      (ControlRoute.groups, Icons.groups_outlined, '群组'),
      (ControlRoute.media, Icons.photo_library_outlined, '素材'),
      (ControlRoute.about, Icons.info_outline, '关于'),
    ];
    return ColoredBox(
      color: AppColors.sidebar,
      child: SizedBox(
        height: 58,
        child: Row(
          children: <Widget>[
            for (final entry in entries)
              Expanded(
                child: _SettingsTabButton(
                  icon: entry.$2,
                  label: entry.$3,
                  selected: selected == entry.$1,
                  onPressed: () => onSelected(entry.$1),
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon,
                  size: 19,
                  color: selected ? AppColors.accent : AppColors.secondaryText),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? AppColors.accent : AppColors.text,
                ),
              ),
            ],
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PaneTitle('提醒设置', subtitle: '使用绝对时间调度，电脑休眠后仍会按计划提醒。'),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularIntervalPicker(
                    seconds: seconds,
                    onChanged: (value) => setState(() => seconds = value),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(saved ? Icons.check : Icons.save_outlined),
                    label: Text(saved ? '已保存' : '保存设置'),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          Row(
            children: <Widget>[
              const Expanded(
                  child: _PaneTitle('群组', subtitle: '创建或加入多个群组，完成记录会同步到所有群组。')),
              IconButton(
                tooltip: '刷新群组',
                onPressed: widget.controller.refreshGroups,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Expanded(
            child: widget.controller.groups.isEmpty
                ? const Center(child: Text('还没有群组'))
                : ListView.separated(
                    itemCount: widget.controller.groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final group = widget.controller.groups[index];
                      return AppCard(
                        padding: EdgeInsets.zero,
                        child: ExpansionTile(
                          key: PageStorageKey<String>(group.groupId),
                          initiallyExpanded:
                              expandedGroups.contains(group.groupId),
                          onExpansionChanged: (expanded) => setState(() {
                            if (expanded) {
                              expandedGroups.add(group.groupId);
                            } else {
                              expandedGroups.remove(group.groupId);
                            }
                          }),
                          leading: const CircleAvatar(
                              child: Icon(Icons.groups_outlined, size: 19)),
                          title: Text(
                            group.name.isEmpty ? '未命名群组' : group.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text('${group.members.length} 位成员'),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          children: <Widget>[
                            const Divider(),
                            Row(
                              children: <Widget>[
                                const Text('邀请码',
                                    style: TextStyle(
                                        color: AppColors.secondaryText,
                                        fontSize: 12)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Wrap(
                                    spacing: 4,
                                    children: <Widget>[
                                      for (final character
                                          in group.inviteCode.characters)
                                        Container(
                                          width: 26,
                                          height: 30,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: AppColors.accentSoft,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            character,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontFeatures: <FontFeature>[
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(text: group.inviteCode),
                                  ),
                                  icon: const Icon(Icons.copy, size: 15),
                                  label: const Text('复制'),
                                ),
                              ],
                            ),
                            if (group.members.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('成员',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ),
                              const SizedBox(height: 4),
                              for (final member in group.members)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 11,
                                        child: Text(member.petEmoji,
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(member.nickname),
                                      if (member.userId ==
                                          widget.controller.snapshot.config
                                              .userId) ...<Widget>[
                                        const SizedBox(width: 6),
                                        const Text('我',
                                            style: TextStyle(
                                                color: AppColors.accent,
                                                fontSize: 11)),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _confirmLeave(group),
                                child: const Text('退出群组',
                                    style: TextStyle(color: AppColors.danger)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Row(
            children: <Widget>[
              FilledButton.icon(
                  onPressed: _showCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('创建群组')),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                  onPressed: _showJoin,
                  icon: const Icon(Icons.login),
                  label: const Text('加入群组')),
            ],
          ),
        ],
      );

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
            decoration: InputDecoration(labelText: label)),
        actions: <Widget>[
          TextButton(
              onPressed: Navigator.of(context).pop, child: const Text('取消')),
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
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.leaveGroup(group.groupId);
  }
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
    if (selected != null && widget.controller.activeChatGroupId == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.controller.loadChat(selected));
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
                                title: Text(group.groupName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: unread > 0
                                    ? Badge(label: Text('$unread'))
                                    : null,
                                onTap: () =>
                                    widget.controller.loadChat(group.groupId),
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
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    selectedGroup?.name ??
                                        selectedJoinedGroup?.groupName ??
                                        '群聊',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                if (selectedGroup != null)
                                  Text(
                                    '${selectedGroup.members.length} 人',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
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
                                          text: selectedGroup.inviteCode),
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
                                        horizontal: 12, vertical: 8),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final message = messages[index];
                                      final own = message.userId ==
                                          widget.controller.snapshot.config
                                              .userId;
                                      return Align(
                                        alignment: own
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                              maxWidth: 360),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 11, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: own
                                                ? AppColors.accentSoft
                                                : AppColors.muted,
                                            borderRadius:
                                                BorderRadius.circular(9),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              if (!own)
                                                Text(
                                                  message.nickname,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              Text(message.content),
                                            ],
                                          ),
                                        ),
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
                                  tooltip: '发送消息',
                                  onPressed: () => _send(selected),
                                  icon: const Icon(Icons.send, size: 18),
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
    await widget.controller.sendChat(groupId, content);
  }
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
    unawaited(widget.controller.refreshLeaderboard(groupId));
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(widget.controller.refreshLeaderboard(groupId));
    });
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
              const Text('排行榜',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (groups.isNotEmpty && selected != null)
                DropdownButton<String>(
                  value: selected,
                  underline: const SizedBox.shrink(),
                  items: groups
                      .map((group) => DropdownMenuItem(
                          value: group.groupId,
                          child: Text(group.groupName,
                              overflow: TextOverflow.ellipsis)))
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
                    .map((group) => DropdownMenuItem(
                        value: group.groupId, child: Text(group.groupName)))
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
            child: widget.controller.leaderboard.isEmpty
                ? const Center(child: Text('暂无数据'))
                : ListView.separated(
                    itemCount: widget.controller.leaderboard.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = widget.controller.leaderboard[index];
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
                          color:
                              own ? AppColors.accentSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: SizedBox(
                            width: 40,
                            child: Text(
                              medal,
                              style: TextStyle(
                                fontSize: entry.rank <= 3 ? 22 : 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            entry.nickname,
                            style: TextStyle(
                              fontWeight:
                                  own ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                          trailing: Text('${entry.count} 次',
                              style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontFeatures: <FontFeature>[
                                    FontFeature.tabularFigures()
                                  ])),
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
    const slots = <(String, String, IconData)>[
      ('reminder', '提醒', Icons.notifications_active_outlined),
      ('completion', '完成', Icons.check_circle_outline),
      ('nap', '睡觉', Icons.bedtime_outlined),
      ('interaction', '单击互动', Icons.touch_app_outlined),
      ('obedientPet', '听话模式宠物', Icons.push_pin_outlined),
      ('docked', '吸附边缘', Icons.dock_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _PaneTitle('动作素材', subtitle: '可为不同宠物状态选择本地照片，照片不会上传。'),
        if (!controller.supportsBackgroundRemoval)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('当前系统不支持本地去背景；普通照片裁剪与显示仍可使用。',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
        Expanded(
          child: ResponsiveCollection(
            itemCount: slots.length,
            itemBuilder: (context, index, singleColumn) => _MediaSlotCard(
              controller: controller,
              slot: slots[index],
              compact: singleColumn,
              onChoosePhoto: _choosePhoto,
            ),
          ),
        ),
      ],
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
    required this.compact,
    required this.onChoosePhoto,
  });

  final AppController controller;
  final (String, String, IconData) slot;
  final bool compact;
  final Future<void> Function(String slot) onChoosePhoto;

  @override
  Widget build(BuildContext context) {
    final entry = controller.snapshot.config.customActionMedia[slot.$1];
    final content = <Widget>[
      Icon(slot.$3, color: AppColors.accent),
      const SizedBox(height: 10),
      Text(slot.$2, style: const TextStyle(fontWeight: FontWeight.w500)),
      Text(
        entry == null ? '默认素材' : '已设置自定义照片',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (entry != null && controller.supportsBackgroundRemoval)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('去除背景', style: TextStyle(fontSize: 12)),
          value: entry.removesBackground,
          onChanged: (value) => controller.setBackgroundRemoval(
            slot.$1,
            value ?? false,
          ),
        ),
      if (!compact) const Spacer() else const SizedBox(height: 12),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: () => onChoosePhoto(slot.$1),
              child: Text(entry == null ? '选择照片…' : '更换…'),
            ),
          ),
          if (entry != null)
            IconButton(
              tooltip: '恢复默认',
              onPressed: () => controller.removeCustomMedia(slot.$1),
              icon: const Icon(Icons.restore, size: 18),
            ),
        ],
      ),
    ];
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }
}

class _AboutPane extends StatelessWidget {
  const _AboutPane({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _PaneTitle('关于'),
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('🦌', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('该提肛了',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      Text(
                        '版本 ${snapshot.data?.version ?? '2.0.0'} (${snapshot.data?.buildNumber ?? '1'})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 24,
                          child: Text(controller.snapshot.config.petEmoji,
                              style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                controller.snapshot.config.nickname ?? '未设置昵称',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '累计${controller.exerciseName} ${controller.snapshot.config.localEventCount} 次',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          controller.availableUpdate == null
                              ? Icons.info_outline
                              : Icons.system_update_alt,
                          size: 18,
                          color: controller.availableUpdate == null
                              ? AppColors.secondaryText
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.availableUpdate == null
                                ? '尚未发现新版本'
                                : '发现新版本 ${controller.availableUpdate!.latestVersion}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: CrashReporter.instance.openLogsDirectory,
                      icon: const Icon(Icons.folder_open_outlined, size: 17),
                      label: const Text('打开日志目录'),
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmClear(context),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('清除本地数据'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );

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
    if (confirmed == true) await controller.clearLocalData();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
