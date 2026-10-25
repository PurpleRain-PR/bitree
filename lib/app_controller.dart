import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/desktop_widget.dart';
import 'data/schedule_store.dart';
import 'data/school_errors.dart';
import 'data/school_network.dart';
import 'data/school_service.dart';
import 'data/school_session.dart';
import 'error_message.dart';
import 'schedule/model.dart';

enum AccountStatus { unverified, signedIn, signedOut, expired }

class AppController extends ChangeNotifier {
  AppController({
    required this._store,
    required this._school,
    required this._preferences,
  });

  final ScheduleStore _store;
  final SchoolService _school;
  final SharedPreferencesAsync _preferences;

  SemesterSchedule? _schedule;
  bool ready = false;
  bool busy = false;
  String? error;
  AccountStatus accountStatus = AccountStatus.unverified;

  int week = 1;
  ThemeMode themeMode = ThemeMode.system;
  SchoolNetwork network = SchoolNetwork.campus;
  List<String> terms = [];

  SchoolSession get schoolSession => _school.session;

  SemesterSchedule? get schedule => _schedule;

  bool get loginExpired => accountStatus == AccountStatus.expired;

  Future<void> initialize() async {
    try {
      _schedule = await _store.read();
      terms = await _store.terms();

      final theme = await _preferences.getString('theme');
      themeMode =
          ThemeMode.values.where((value) => value.name == theme).firstOrNull ??
          ThemeMode.system;
      network = await _preferences.getString('network') == 'webvpn'
          ? SchoolNetwork.webvpn
          : SchoolNetwork.campus;
      _goToCurrentWeek();
    } catch (failure) {
      error = errorMessage(failure);
    }

    ready = true;
    notifyListeners();
  }

  void _goToCurrentWeek() {
    week = (schedule?.weekAt(campusNow()) ?? 1).clamp(
      schedule?.firstWeek ?? 1,
      schedule?.lastWeek ?? 20,
    );
  }

  void selectWeek(int value) {
    week = value.clamp(schedule?.firstWeek ?? 1, schedule?.lastWeek ?? 20);
    notifyListeners();
  }

  void showCurrentWeek() {
    _goToCurrentWeek();
    notifyListeners();
  }

  void dismissError() {
    error = null;
    notifyListeners();
  }

  void requireLogin() {
    final next = switch (accountStatus) {
      AccountStatus.signedIn => AccountStatus.expired,
      AccountStatus.unverified => AccountStatus.signedOut,
      _ => accountStatus,
    };
    if (next == accountStatus) return;

    accountStatus = next;
    notifyListeners();
  }

  Future<void> _saveLoginState(SchoolNetwork using) async {
    await _preferences.setString('network', using.name);

    accountStatus = AccountStatus.signedIn;
    network = using;
  }

  void _handleSchoolError(Object failure) {
    if (failure is SessionExpired) requireLogin();
    error = errorMessage(failure);
  }

  Future<bool> completeSignIn(SchoolNetwork using) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _saveLoginState(using);
      return true;
    } catch (failure) {
      _handleSchoolError(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> synchronize({
    SchoolNetwork? using,
    String? term,
    SchoolJsonRequest? request,
  }) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final selectedNetwork = using ?? network;
      final result = await _school.synchronize(
        selectedNetwork,
        term: term,
        request: request,
      );
      await _saveLoginState(selectedNetwork);

      final previous = await _store.readTerm(result.schedule.term);
      final localCourses = previous != null
          ? previous.courses.where((course) => course.local).toList()
          : <Course>[];
      final next = result.schedule.copyWith(
        courses: {
          for (final course in result.schedule.courses) course.id: course,
          for (final course in localCourses) course.id: course,
        }.values.toList(),
      );

      await _store.write(next);
      _schedule = next;
      terms = {...await _store.terms(), ...result.terms}.toList();
      _goToCurrentWeek();
      await _updateWidget();
      return true;
    } catch (failure) {
      _handleSchoolError(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveCourse(
    Course course, {
    Course? replacing,
    SemesterSchedule? semester,
  }) async {
    final current = semester ?? _schedule;
    if (current == null || busy) return false;
    return _save(
      current.copyWith(
        courses: [
          ...current.courses.where(
            (item) => item.id != course.id && item.id != replacing?.id,
          ),
          course,
        ],
      ),
    );
  }

  Future<bool> selectTerm(String term) async {
    if (busy) return false;
    try {
      final saved = await _store.readTerm(term);
      if (busy) return false;
      if (saved == null) return await synchronize(term: term);
      final success = await _save(saved);
      if (success) showCurrentWeek();
      return success;
    } catch (failure) {
      error = errorMessage(failure);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCourse(Course course) async {
    if (_schedule == null || busy) return false;
    return _save(
      _schedule!.copyWith(
        courses: [..._schedule!.courses.where((item) => item.id != course.id)],
      ),
    );
  }

  Future<bool> setFirstMonday(DateTime date) async {
    if (_schedule == null || busy) return false;
    final result = await _save(_schedule!.copyWith(firstMonday: date));
    if (result) showCurrentWeek();
    return result;
  }

  Future<bool> _save(SemesterSchedule next) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _store.write(next);
      _schedule = next;
      week = week.clamp(next.firstWeek, next.lastWeek);
      terms = {...terms, next.term}.toList();
      await _updateWidget();
      return true;
    } catch (failure) {
      error = errorMessage(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setTheme(ThemeMode value) async {
    try {
      await _preferences.setString('theme', value.name);
      themeMode = value;
    } catch (failure) {
      error = errorMessage(failure);
    }
    notifyListeners();
  }

  Future<bool> signOut() async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      await _school.session.clear();
      accountStatus = AccountStatus.signedOut;
      error = null;
      return true;
    } catch (failure) {
      error = errorMessage(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> clearSchedule() async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      await _store.clear();
      _schedule = null;
      terms = [];
      error = null;
      _goToCurrentWeek();
      await _updateWidget();
      return true;
    } catch (failure) {
      error = errorMessage(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _updateWidget() async {
    try {
      await updateDesktopWidget();
    } catch (failure) {
      error = '桌面组件更新失败：${errorMessage(failure)}';
    }
  }
}
