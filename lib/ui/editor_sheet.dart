import 'package:flutter/material.dart';

import 'sheet_layout.dart';

class EditorSheet extends StatelessWidget {
  const EditorSheet({
    super.key,
    required this.title,
    required this.formKey,
    required this.saving,
    required this.onSave,
    required this.saveLabel,
    required this.child,
    this.onDelete,
    this.error,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave;
  final Widget saveLabel;
  final Widget child;
  final VoidCallback? onDelete;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !saving,
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SheetLayout(
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            content: Padding(
              // Leave room for floating labels above the first field.
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Form(key: formKey, child: child),
            ),
            actions: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (error case final message?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          message,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    Row(
                      children: [
                        if (onDelete != null) ...[
                          IconButton(
                            tooltip: '删除',
                            onPressed: saving ? null : onDelete,
                            color: theme.colorScheme.error,
                            icon: const Icon(Icons.delete_outline),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: saving ? null : onSave,
                            child: saveLabel,
                          ),
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
  }
}
