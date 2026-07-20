import 'dart:async';

import 'package:ass_timer_flutter/domain/app_models.dart';
import 'package:uuid/uuid.dart';

class BubbleQueue {
  BubbleQueue({required this.onChanged});

  final void Function(List<BubbleItem> items) onChanged;
  final List<BubbleItem> _items = <BubbleItem>[];
  final Map<String, Timer> _dismissTimers = <String, Timer>{};
  final Uuid _uuid = const Uuid();

  List<BubbleItem> get items => List<BubbleItem>.unmodifiable(_items);

  BubbleItem add(
    BubbleKind kind, {
    String? senderNickname,
    String? senderPetEmoji,
    String? senderAvatarUrl,
    String? groupId,
    String? message,
    BubbleFeedbackTone? feedbackTone,
  }) {
    if (kind == BubbleKind.reminder) {
      final existing = _items.where((item) => item.kind == kind).firstOrNull;
      if (existing != null) return existing;
    }

    final item = BubbleItem(
      id: _uuid.v4(),
      kind: kind,
      createdAt: DateTime.now(),
      senderNickname: senderNickname,
      senderPetEmoji: senderPetEmoji,
      senderAvatarUrl: senderAvatarUrl,
      groupId: groupId,
      message: message,
      feedbackTone: feedbackTone,
    );
    _items.add(item);
    _items.sort((a, b) {
      final priority = a.priority.compareTo(b.priority);
      return priority != 0 ? priority : a.createdAt.compareTo(b.createdAt);
    });
    _notify();

    if (kind != BubbleKind.reminder) {
      _dismissTimers[item.id] = Timer(
        kind == BubbleKind.feedback
            ? const Duration(milliseconds: 1400)
            : const Duration(seconds: 5),
        () => remove(item.id),
      );
    }
    return item;
  }

  void remove(String id) {
    _dismissTimers.remove(id)?.cancel();
    _items.removeWhere((item) => item.id == id);
    _notify();
  }

  void removeKind(BubbleKind kind) {
    final ids = _items
        .where((item) => item.kind == kind)
        .map((item) => item.id)
        .toList(growable: false);
    for (final id in ids) {
      _dismissTimers.remove(id)?.cancel();
    }
    _items.removeWhere((item) => item.kind == kind);
    _notify();
  }

  void clear() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _items.clear();
    _notify();
  }

  void dispose() => clear();

  void _notify() => onChanged(items);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
