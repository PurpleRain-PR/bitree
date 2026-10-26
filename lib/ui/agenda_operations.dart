import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agenda/controller.dart';
import '../agenda/model.dart';
import '../app_controller.dart';
import 'app_notice.dart';

Future<void> toggleAgendaDone(
  BuildContext context,
  AgendaController controller,
  AgendaEntry entry, {
  bool haptic = true,
}) async {
  final saved = await controller.save(entry.copyWith(done: !entry.done));
  if (saved && haptic) {
    HapticFeedback.selectionClick();
  } else if (!saved && context.mounted) {
    showAppNotice(context, controller.error ?? '未能保存，请重试');
  }
}

Future<bool> deleteAgendaEntry(
  BuildContext context,
  AppController controller,
  AgendaEntry entry, {
  bool confirm = true,
}) async {
  // The originating sheet can close while the undo action remains visible.
  final overlay = Overlay.of(context, rootOverlay: true);
  if (confirm && controller.confirmDelete) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除${entry.kind.label}？'),
        content: Text(entry.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }
  final deleted = await controller.agenda.delete(entry);
  if (!overlay.mounted) return deleted;
  if (!deleted) {
    showOverlayNotice(overlay, controller.agenda.error ?? '未能删除，请重试');
    return false;
  }

  Future<void> restore() async {
    final restored = await controller.agenda.restore(entry);
    if (!overlay.mounted) return;
    if (restored) {
      showOverlayNotice(overlay, '已恢复“${entry.title}”');
    } else {
      showOverlayNotice(
        overlay,
        controller.agenda.error ?? '未能恢复，请重试',
        action: (label: '重试', onPressed: restore),
      );
    }
  }

  showOverlayNotice(
    overlay,
    '已删除“${entry.title}”',
    action: (label: '撤销', onPressed: restore),
  );
  return true;
}
