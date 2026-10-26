import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agenda/controller.dart';
import '../agenda/model.dart';
import 'app_notice.dart';

Future<void> toggleAgendaDone(
  BuildContext context,
  AgendaController controller,
  AgendaEntry entry,
) async {
  final saved = await controller.save(entry.withDone(!entry.done));
  if (saved) {
    HapticFeedback.selectionClick();
  } else if (context.mounted) {
    showAppNotice(context, controller.error ?? '未能保存，请重试');
  }
}

Future<bool> deleteAgendaEntry(
  BuildContext context,
  AgendaController controller,
  AgendaEntry entry,
) async {
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
  final deleted = await controller.delete(entry);
  if (!deleted && context.mounted) {
    showAppNotice(context, controller.error ?? '未能删除，请重试');
  }
  return deleted;
}
