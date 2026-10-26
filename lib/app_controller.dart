import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agenda/controller.dart';
import 'data/desktop_widget.dart';
import 'data/schedule_store.dart';
import 'data/school_errors.dart';
import 'data/school_exams.dart';
import 'data/school_login.dart';
import 'data/school_network.dart';
import 'data/school_service.dart';
import 'data/school_session.dart';
import 'data/school_storage.dart';
import 'data/school_verification.dart';
import 'error_message.dart';
import 'schedule/model.dart';

enum AccountStatus { unverified, signedIn, signedOut, expired }

class AppController extends ChangeNotifier {
  AppController({
    required this._store,
    required this._school,
    required this._schoolStorage,
    required this._preferences,
    required this.agenda,
  }) {
    agenda.addListener(_agendaChanged);
  }

  final ScheduleStore _store;
  final SchoolService _school;
  final SchoolStorage _schoolStorage;
  final SharedPreferencesAsync _preferences;
  final AgendaController agenda;

  SemesterSchedule? _schedule;
  bool ready = false;
  bool busy = false;
  String? error;
  AccountStatus accountStatus = AccountStatus.unverified;
  String? username;
  SchoolSession? _activeSchoolSession;
  Future<void>? _schoolFinished;

  int week = 1;
  ThemeMode themeMode = ThemeMode.system;
  SchoolNetwork network = SchoolNetwork.campus;
  List<String> terms = [];

  SemesterSchedule? get schedule => _schedule;

  List<int> get weeks {
    final current = schedule;
    if (current == null) return const [];
    var first = current.firstWeek;
    var last = current.lastWeek < 30 ? 30 : current.lastWeek;
    for (final entry in agenda.entries) {
      if (entry.term != null && entry.term != current.term) continue;
      final startWeek = current.weekAt(entry.startsAt);
      final endWeek = entry.isDeadline
          ? startWeek
          : current.weekAt(
              entry.endsAt!.subtract(const Duration(microseconds: 1)),
            );
      if (startWeek < first) first = startWeek;
      if (endWeek > last) last = endWeek;
    }
    return academicWeeks(first, last);
  }

  bool get loginExpired => accountStatus == AccountStatus.expired;

  bool get schoolBusy => _activeSchoolSession != null;

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
      username = (await _schoolStorage.readCredentials())?.username;
      if (username == null) accountStatus = AccountStatus.signedOut;
    } catch (failure) {
      error = errorMessage(failure);
    }

    await agenda.load();
    _goToCurrentWeek();
    ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    agenda.removeListener(_agendaChanged);
    agenda.dispose();
    super.dispose();
  }

  void _agendaChanged() {
    final available = weeks;
    if (available.isNotEmpty) {
      week = week.clamp(available.first, available.last);
    }
    notifyListeners();
  }

  void _goToCurrentWeek() {
    final available = weeks;
    week = (schedule?.weekAt(campusNow()) ?? 1).clamp(
      available.firstOrNull ?? 1,
      available.lastOrNull ?? 20,
    );
  }

  void selectWeek(int value) {
    final available = weeks;
    week = value.clamp(available.firstOrNull ?? 1, available.lastOrNull ?? 20);
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
    final next = username == null
        ? AccountStatus.signedOut
        : AccountStatus.expired;
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
    if (failure is SessionExpired || failure is SchoolCredentialsRequired) {
      requireLogin();
    }
    error = errorMessage(failure);
  }

  Future<bool> _runSchool(
    SchoolNetwork using,
    Future<void> Function(SchoolSession) operation,
  ) async {
    if (busy || schoolBusy) return false;

    final session = SchoolSession(network: using, storage: _schoolStorage);
    final finished = Completer<void>();
    _activeSchoolSession = session;
    _schoolFinished = finished.future;
    error = null;
    notifyListeners();

    try {
      await operation(session);
      session.checkActive();
      await _saveLoginState(using);
      return true;
    } on SchoolCancelled {
      return false;
    } catch (failure) {
      if (!session.cancelled) _handleSchoolError(failure);
      return false;
    } finally {
      session.close();
      _activeSchoolSession = null;
      _schoolFinished = null;
      finished.complete();
      notifyListeners();
    }
  }

  void cancelSchoolRequest() => _activeSchoolSession?.close();

  Future<T> _authenticated<T>(
    SchoolSession session,
    VerifySchoolLogin verify,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on SessionExpired {
      final credentials = await _schoolStorage.readCredentials();
      if (credentials == null) throw const SchoolCredentialsRequired();
      await SchoolLogin(session, verify).signIn(credentials);
      return operation();
    }
  }

  Future<bool> signIn(
    SchoolCredentials credentials,
    SchoolNetwork using,
    VerifySchoolLogin verify,
  ) => _runSchool(using, (session) async {
    await _schoolStorage.clearSession(using);
    await SchoolLogin(session, verify).signIn(credentials);
    session.checkActive();
    await _schoolStorage.saveCredentials(credentials);
    username = credentials.username;
  });

  Future<bool> restoreAccount(VerifySchoolLogin verify) async {
    if (username == null) return true;
    return _runSchool(
      network,
      (session) => _authenticated(session, verify, session.checkLogin),
    );
  }

  Future<bool> changeNetwork(
    SchoolNetwork value,
    VerifySchoolLogin verify,
  ) async {
    if (busy || schoolBusy || value == network) return false;
    if (username != null) {
      return _runSchool(
        value,
        (session) => _authenticated(session, verify, session.checkLogin),
      );
    }
    try {
      await _preferences.setString('network', value.name);
      network = value;
      error = null;
      return true;
    } catch (failure) {
      error = errorMessage(failure);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> synchronize({
    SchoolNetwork? using,
    String? term,
    required VerifySchoolLogin verify,
  }) => _runSchool(using ?? network, (session) async {
    final result = await _authenticated(
      session,
      verify,
      () => _school.synchronize(session, term: term),
    );

    if (busy) throw const SchoolRequestError('课程正在保存，请稍后重新导入。');
    busy = true;
    notifyListeners();
    try {
      final previous = await _store.readTerm(result.schedule.term);
      session.checkActive();
      final next = result.schedule.mergeLocalCourses(
        previous?.courses ?? const [],
      );
      await _store.write(next);
      _schedule = next;
      terms = {...await _store.terms(), ...result.terms}.toList();
      _goToCurrentWeek();
      await _updateWidget();
    } finally {
      busy = false;
      notifyListeners();
    }
  });

  Future<bool> importExams({
    SchoolNetwork? using,
    required VerifySchoolLogin verify,
  }) => _runSchool(using ?? network, (session) async {
    final result = await _authenticated(
      session,
      verify,
      () => fetchSchoolExams(session, term: schedule?.term),
    );
    session.checkActive();
    if (!await agenda.replaceExams(result.term, result.exams)) {
      throw SchoolRequestError(agenda.error ?? '安排正在保存，请稍后重试。');
    }
  });

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

  Future<bool> selectTerm(
    String term, {
    required Future<bool> Function(String term) importTerm,
  }) async {
    if (busy) return false;

    try {
      final saved = await _store.readTerm(term);
      if (busy) return false;
      if (saved == null) return await importTerm(term);

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

  Future<bool> _save(SemesterSchedule next) async {
    busy = true;
    error = null;
    notifyListeners();

    try {
      await _store.write(next);
      _schedule = next;
      final available = weeks;
      week = week.clamp(available.first, available.last);
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

    final finished = _schoolFinished;
    cancelSchoolRequest();
    await finished;
    busy = true;
    notifyListeners();

    try {
      await _schoolStorage.clear();
      username = null;
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
