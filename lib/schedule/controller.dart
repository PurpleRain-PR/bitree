import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/schedule_store.dart';
import '../data/school_service.dart';
import '../data/school_session.dart';
import '../data/desktop_widget.dart';
import 'model.dart';

String operationError(Object error) => switch (error) {
  SessionExpired() => error.toString(),
  SchoolRequestError() => error.message,
  SocketException() => '无法连接学校网站，请检查网络或更换登录方式。',
  TimeoutException() => '连接学校网站超时，请稍后重试。',
  HandshakeException() => '无法验证学校网站证书，请检查系统时间和网络。',
  FormatException() => '课表数据格式不正确：${error.message}',
  FileSystemException() => '无法读写本地课表：${error.message}',
  PlatformException() => '无法调用系统服务：${error.message ?? error.code}',
  _ => '操作失败：$error',
};

enum AccountStatus { unverified, signedIn, signedOut, expired }

class ScheduleController extends ChangeNotifier {
  ScheduleController({
    required this.store,
    required this.school,
    required this.preferences,
  });
  final ScheduleStore store;
  final SchoolService school;
  final SharedPreferencesAsync preferences;
  SemesterSchedule? _saved;
  SemesterSchedule? get schedule => _saved;
  bool ready = false;
  bool busy = false;
  String? error;
  AccountStatus accountStatus = AccountStatus.unverified;
  bool get needsLogin => accountStatus == AccountStatus.expired;
  int week = 1;
  ThemeMode themeMode = ThemeMode.system;
  SchoolNetwork network = SchoolNetwork.campus;
  List<String> terms = [];

  Future<void> initialize() async {
    try {
      _saved = await store.read();
      terms = await store.terms();
      final theme = await preferences.getString('theme');
      themeMode =
          ThemeMode.values.where((value) => value.name == theme).firstOrNull ??
          ThemeMode.system;
      network = await preferences.getString('network') == 'webvpn'
          ? SchoolNetwork.webvpn
          : SchoolNetwork.campus;
      _goToCurrentWeek();
    } catch (failure) {
      error = operationError(failure);
    }
    ready = true;
    notifyListeners();
  }

  void _goToCurrentWeek() {
    week = (schedule?.weekAt(campusNow()) ?? 1).clamp(
      1,
      schedule?.weekCount ?? 20,
    );
  }

  void selectWeek(int value) {
    week = value.clamp(1, schedule?.weekCount ?? 20);
    notifyListeners();
  }

  void today() {
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

  Future<void> _connected(SchoolNetwork using) async {
    await preferences.setString('network', using.name);
    accountStatus = AccountStatus.signedIn;
    network = using;
  }

  void _schoolFailure(Object failure) {
    if (failure is SessionExpired) requireLogin();
    error = operationError(failure);
  }

  Future<bool> completeSignIn(SchoolNetwork using) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _connected(using);
      return true;
    } catch (failure) {
      _schoolFailure(failure);
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
      final result = await school.synchronize(
        selectedNetwork,
        term: term,
        request: request,
      );
      await _connected(selectedNetwork);
      final previous = await store.readTerm(result.schedule.term);
      final localCourses = previous != null
          ? previous.courses.where((course) => course.local).toList()
          : <Course>[];
      final next = result.schedule.copyWith(
        courses: [...result.schedule.courses, ...localCourses],
      );
      await store.write(next);
      _saved = next;
      terms = {...await store.terms(), ...result.terms}.toList();
      _goToCurrentWeek();
      await _updateWidget();
      return true;
    } catch (failure) {
      _schoolFailure(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveCourse(Course course, {SemesterSchedule? semester}) async {
    final current = semester ?? _saved;
    if (current == null || busy) return false;
    return _save(
      current.copyWith(
        courses: [
          ...current.courses.where((item) => item.id != course.id),
          course,
        ],
      ),
    );
  }

  Future<bool> selectTerm(String term) async {
    if (busy) return false;
    try {
      final saved = await store.readTerm(term);
      if (busy) return false;
      if (saved == null) return await synchronize(term: term);
      final success = await _save(saved);
      if (success) today();
      return success;
    } catch (failure) {
      error = operationError(failure);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCourse(Course course) async {
    if (_saved == null || !course.local || busy) return false;
    return _save(
      _saved!.copyWith(
        courses: [..._saved!.courses.where((item) => item.id != course.id)],
      ),
    );
  }

  Future<bool> setFirstMonday(DateTime date) async {
    if (_saved == null || busy) return false;
    final result = await _save(_saved!.copyWith(firstMonday: date));
    if (result) today();
    return result;
  }

  Future<bool> _save(SemesterSchedule next) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await store.write(next);
      _saved = next;
      terms = {...terms, next.term}.toList();
      await _updateWidget();
      return true;
    } catch (failure) {
      error = operationError(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setTheme(ThemeMode value) async {
    try {
      await preferences.setString('theme', value.name);
      themeMode = value;
    } catch (failure) {
      error = operationError(failure);
    }
    notifyListeners();
  }

  Future<bool> signOut() async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      await school.session.clear();
      accountStatus = AccountStatus.signedOut;
      error = null;
      return true;
    } catch (failure) {
      error = operationError(failure);
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
      await store.clear();
      _saved = null;
      terms = [];
      error = null;
      _goToCurrentWeek();
      await _updateWidget();
      return true;
    } catch (failure) {
      error = operationError(failure);
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
      error = '桌面组件更新失败：${operationError(failure)}';
    }
  }
}
