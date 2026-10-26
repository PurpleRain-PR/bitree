import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'school_verification_dialog.dart';
import 'update_check.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  int _tab = 0;
  bool _checkingUpdates = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onReady);
    _onReady();
  }

  void _onReady() {
    if (_started || !widget.controller.ready) return;
    _started = true;
    widget.controller.removeListener(_onReady);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_restoreAccount());
    });
  }

  Future<void> _restoreAccount() async {
    await widget.controller.restoreAccount(
      (request) => verifySchoolLogin(context, request),
    );
    if (mounted) await _checkUpdates(silent: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onReady);
    super.dispose();
  }

  Future<void> _checkUpdates({bool silent = false}) async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);

    try {
      await checkForUpdates(context, silent: silent);
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: _tab,
          children: [
            ScheduleScreen(controller: widget.controller),
            const _PendingPage(title: '日程'),
            const _PendingPage(title: '工具'),
            SettingsScreen(
              controller: widget.controller,
              checkingForUpdates: _checkingUpdates,
              onCheckForUpdates: () => _checkUpdates(),
            ),
          ],
        ),
        if (widget.controller.schoolBusy)
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 0,
            right: 0,
            child: const LinearProgressIndicator(minHeight: 3),
          ),
      ],
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: NavigationBar(
              height: 56 + MediaQuery.textScalerOf(context).scale(12),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() => _tab = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_view_week_outlined),
                  selectedIcon: Icon(Icons.calendar_view_week_rounded),
                  label: '课表',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note_rounded),
                  label: '日程',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: '工具',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: '设置',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PendingPage extends StatelessWidget {
  const _PendingPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Text(
        '$title功能暂未开放',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
