import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../schedule/controller.dart';
import '../schedule/model.dart';
import 'course_editor.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final ScheduleController controller;

  Future<void> _selectTerm(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('选择学期'),
      children: [
        for (final term in controller.terms)
          SimpleDialogOption(
            onPressed: controller.busy
                ? null
                : () {
                    Navigator.pop(context);
                    controller.selectTerm(term);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(term)),
                  if (controller.schedule?.term == term)
                    const Icon(Icons.check_rounded, size: 18),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _clearSchedule(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除本地课表？'),
        content: const Text('将删除所有学期的课表，包括手动添加的课程。删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除课表'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.clearSchedule();
  }

  Future<void> _showAbout(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        constraints: const BoxConstraints(maxWidth: 360),
        insetPadding: const EdgeInsets.all(24),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        scrollable: true,
        title: Row(
          children: [
            Image.asset('assets/brand/bitree.png', width: 40, height: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'BITree',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('理枝', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '0.1.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: const Text('北京理工大学工具集。\n理枝，谐音“荔枝”。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              showLicensePage(
                context: context,
                applicationName: 'BITree 理枝',
                applicationVersion: '0.1.0',
                applicationIcon: Image.asset(
                  'assets/brand/bitree.png',
                  width: 40,
                  height: 40,
                ),
              );
            },
            child: const Text('查看许可'),
          ),
          TextButton(
            onPressed: () => _openGitHub(dialogContext),
            child: const Text('GitHub'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );

  Future<void> _openGitHub(BuildContext context) async {
    final repository = Uri.https('github.com', '/so1ve/bitree');
    bool opened;
    try {
      opened = await launchUrl(
        repository,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      opened = false;
    }
    if (opened || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('无法打开 GitHub'),
        content: SelectableText('请在浏览器中打开：\n$repository'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final signedIn = controller.accountStatus == AccountStatus.signedIn;
    final accountHint = switch (controller.accountStatus) {
      AccountStatus.signedIn => '已登录',
      AccountStatus.expired => '登录已过期，不影响本地课表',
      AccountStatus.unverified || AccountStatus.signedOut => '登录后可导入课表',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.person_outline_rounded),
                ),
                title: Text(
                  signedIn ? '学校账号' : '登录账号',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(accountHint),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: controller.busy
                    ? null
                    : () => openSchoolPage(
                        context,
                        controller,
                        action: SchoolAction.signIn,
                      ),
              ),
              if (controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    controller.error!,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              const Divider(height: 32),
              const _SectionLabel('外观'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (mode, label) in const [
                      (ThemeMode.system, '跟随系统'),
                      (ThemeMode.light, '浅色'),
                      (ThemeMode.dark, '深色'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        showCheckmark: false,
                        selected: controller.themeMode == mode,
                        onSelected: (_) => controller.setTheme(mode),
                      ),
                  ],
                ),
              ),
              const Divider(height: 32),
              const _SectionLabel('本地课表'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_rounded),
                title: const Text('添加课程'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: controller.busy
                    ? null
                    : () => editCourse(context, controller),
              ),
              if (controller.schedule != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('学期'),
                  subtitle: Text(controller.schedule!.termLabel),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: controller.busy ? null : () => _selectTerm(context),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('第一周周一'),
                  subtitle: Text(dateText(controller.schedule!.firstMonday)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: controller.busy
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: controller.schedule!.firstMonday,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            selectableDayPredicate: (date) =>
                                date.weekday == DateTime.monday,
                            helpText: '选择第一周周一',
                          );
                          if (date != null) {
                            await controller.setFirstMonday(date);
                          }
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: scheme.error,
                  ),
                  title: Text('删除本地课表', style: TextStyle(color: scheme.error)),
                  onTap: controller.busy ? null : () => _clearSchedule(context),
                ),
              ],
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('关于 BITree'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showAbout(context),
              ),
              if (signedIn || controller.accountStatus == AccountStatus.expired)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('退出学校账号'),
                  subtitle: const Text('保留本地课表'),
                  onTap: controller.busy ? null : controller.signOut,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
