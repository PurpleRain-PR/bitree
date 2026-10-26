import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'school_screen.dart';

class SchoolAccount extends StatefulWidget {
  const SchoolAccount({super.key, required this.controller});

  final AppController controller;

  @override
  State<SchoolAccount> createState() => _SchoolAccountState();
}

class _SchoolAccountState extends State<SchoolAccount> {
  bool _handlingAction = false;

  Future<void> _perform(Future<void> Function() action) async {
    if (_handlingAction || widget.controller.busy) return;
    setState(() => _handlingAction = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _handlingAction = false);
    }
  }

  Future<void> _login() async {
    await openSchoolPage(
      context,
      widget.controller,
      action: SchoolAction.signIn,
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出学校账号？'),
        content: const Text('将移除此设备上的登录信息，保留本地课表和日程。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final hasAccount = controller.username != null;
    final enabled = !_handlingAction && !controller.busy;
    final canLogin = enabled && !controller.schoolBusy;
    final scheme = Theme.of(context).colorScheme;
    final status = switch (controller.accountStatus) {
      AccountStatus.signedIn => '已登录',
      AccountStatus.expired => '需要重新登录',
      AccountStatus.unverified => '未连接',
      AccountStatus.signedOut => '未登录',
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(
        Icons.account_circle_outlined,
        size: 36,
        color: hasAccount ? scheme.primary : null,
      ),
      title: Text(controller.username ?? '登录学校账号'),
      subtitle: hasAccount ? Text(status) : null,
      trailing: controller.loginExpired
          ? TextButton(
              onPressed: canLogin ? () => _perform(_login) : null,
              child: const Text('登录'),
            )
          : Icon(
              hasAccount ? Icons.logout_rounded : Icons.chevron_right_rounded,
              size: 20,
            ),
      onTap: (hasAccount ? enabled : canLogin)
          ? () => _perform(hasAccount ? _signOut : _login)
          : null,
    );
  }
}
