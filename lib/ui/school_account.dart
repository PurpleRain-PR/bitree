import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'school_screen.dart';

enum _AccountAction { signIn, signOut }

class SchoolAccount extends StatefulWidget {
  const SchoolAccount({super.key, required this.controller});

  final AppController controller;

  @override
  State<SchoolAccount> createState() => _SchoolAccountState();
}

class _SchoolAccountState extends State<SchoolAccount> {
  bool _handlingAction = false;

  Future<void> _handleAccount({bool manage = false}) async {
    final controller = widget.controller;
    if (_handlingAction || controller.busy) return;

    setState(() => _handlingAction = true);

    try {
      final action = manage
          ? await showModalBottomSheet<_AccountAction>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              constraints: const BoxConstraints(maxWidth: 520),
              builder: _buildActions,
            )
          : _AccountAction.signIn;
      if (!mounted || action == null) return;

      switch (action) {
        case _AccountAction.signIn:
          await openSchoolPage(
            context,
            controller,
            action: SchoolAction.signIn,
          );
        case _AccountAction.signOut:
          await controller.signOut();
      }
    } finally {
      if (mounted) setState(() => _handlingAction = false);
    }
  }

  Widget _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = widget.controller.accountStatus == AccountStatus.signedIn;

    void select(_AccountAction action) {
      if (ModalRoute.of(context)!.isCurrent) Navigator.pop(context, action);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text('学校账号', style: theme.textTheme.titleLarge),
            ),
            ListTile(
              leading: Icon(
                signedIn ? Icons.swap_horiz_rounded : Icons.login_rounded,
              ),
              title: Text(signedIn ? '切换登录方式' : '重新登录'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => select(_AccountAction.signIn),
            ),
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                '退出登录',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('保留本地课表'),
              onTap: () => select(_AccountAction.signOut),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final signedIn = controller.accountStatus == AccountStatus.signedIn;
    final expired = controller.accountStatus == AccountStatus.expired;
    final enabled = !_handlingAction && !controller.busy;
    final status = switch (controller.accountStatus) {
      AccountStatus.signedIn => '已登录',
      AccountStatus.expired => '登录已过期',
      AccountStatus.unverified || AccountStatus.signedOut => '未登录',
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        Icons.account_circle_outlined,
        size: 40,
        color: signedIn ? theme.colorScheme.primary : null,
      ),
      title: Text('学校账号', style: theme.textTheme.titleMedium),
      subtitle: Text(
        status,
        style: TextStyle(color: signedIn ? theme.colorScheme.primary : null),
      ),
      trailing: signedIn || expired
          ? IconButton(
              tooltip: '管理学校账号',
              onPressed: enabled ? () => _handleAccount(manage: true) : null,
              icon: const Icon(Icons.more_horiz_rounded),
            )
          : TextButton(
              onPressed: enabled ? _handleAccount : null,
              child: const Text('登录'),
            ),
      onTap: enabled ? () => _handleAccount(manage: signedIn) : null,
    );
  }
}
