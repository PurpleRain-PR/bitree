import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agenda/controller.dart';
import 'agenda/deadline_source.dart';
import 'classrooms/model.dart';
import 'data/desktop_widget.dart';
import 'data/schedule_store.dart';
import 'data/school_access.dart';
import 'data/school_errors.dart';
import 'data/school_classrooms.dart';
import 'data/lexue_deadlines.dart';
import 'data/eclass_deadlines.dart';
import 'data/school_exams.dart';
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
  late final _schoolAccess = SchoolAccess(_schoolStorage);
  final SharedPreferencesAsync _preferences;
  final AgendaController agenda;

  SemesterSchedule? _schedule;
  bool ready = false;
  bool busy = false;
  String? error;
  AccountStatus accountStatus = AccountStatus.unverified;
  String? username;
  Future<void>? _schoolFinished;

  int week = 1;
  ThemeMode themeMode = ThemeMode.system;
  bool confirmDelete = true;
  List<String> terms = [];

  SemesterSchedule? get schedule => _schedule;

  List<int> get weeks => schedule?.weeks ?? const [];

  bool get loginExpired => accountStatus == AccountStatus.expired;

  bool get schoolBusy => _schoolFinished != null;

  Future<void> initialize() async {
    try {
      _schedule = await _store.read();
      terms = await _store.terms();

      final theme = await _preferences.getString('theme');
      confirmDelete = await _preferences.getBool('confirmDelete') ?? true;
      themeMode =
          ThemeMode.values.where((value) => value.name == theme).firstOrNull ??
          ThemeMode.system;
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
    if (agenda.ready && !agenda.busy) unawaited(_updateWidget());
  }

  void _goToCurrentWeek() {
    final available = weeks;
    final current = schedule?.weekAt(campusNow()) ?? 1;
    week = available.contains(current) ? current : 1;
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

  void _handleSchoolError(Object failure) {
    if (failure is SessionExpired || failure is SchoolCredentialsRequired) {
      requireLogin();
    }
    error = errorMessage(failure);
  }

  Future<bool> _runSchool(Future<void> Function() operation) async {
    if (busy || schoolBusy) return false;

    final finished = Completer<void>();
    _schoolFinished = finished.future;
    error = null;
    notifyListeners();

    try {
      await operation();
      accountStatus = AccountStatus.signedIn;
      return true;
    } on SchoolCancelled {
      return false;
    } catch (failure) {
      _handleSchoolError(failure);
      return false;
    } finally {
      _schoolFinished = null;
      finished.complete();
      notifyListeners();
    }
  }

  void cancelSchoolRequest() => _schoolAccess.cancel();

  Future<ClassroomDirectory?> classroomDirectory({
    required VerifySchoolLogin verify,
  }) => _readSchool(fetchClassroomDirectory, verify);

  Future<List<ClassroomOccupancy>?> classroomOccupancy({
    required String buildingCode,
    required DateTime date,
    required VerifySchoolLogin verify,
  }) => _readSchool(
    (session) => fetchClassroomOccupancy(
      session,
      buildingCode: buildingCode,
      date: date,
    ),
    verify,
  );

  Future<T?> _readSchool<T>(
    Future<T> Function(SchoolSession) read,
    VerifySchoolLogin verify,
  ) async {
    T? result;
    final success = await _runSchool(() async {
      result = await _schoolAccess.read(verify, read);
    });
    return success ? result : null;
  }

  Future<bool> signIn(
    SchoolCredentials credentials,
    VerifySchoolLogin verify, {
    DeadlineSource? source,
  }) => _runSchool(() async {
    await _schoolAccess.signIn(credentials, verify, source: source);
    username = credentials.username;
  });

  Future<bool> restoreAccount(VerifySchoolLogin verify) async {
    if (username == null) return true;
    return _runSchool(
      () => _schoolAccess.read(verify, (session) => session.checkLogin()),
    );
  }

  Future<bool> synchronize({String? term, required VerifySchoolLogin verify}) =>
      _runSchool(
        () => _schoolAccess.read(verify, (session) async {
          final result = await _school.synchronize(session, term: term);

          if (busy) throw const SchoolRequestError('课程正在保存，请稍后重新导入。');
          busy = true;
          notifyListeners();
          try {
            final previous = await _store.readTerm(result.schedule.term);
            session.checkActive();
            final next = result.schedule.mergeLocalChanges(previous);
            await _store.write(next);
            _schedule = next;
            terms = {...await _store.terms(), ...result.terms}.toList();
            _goToCurrentWeek();
            await _updateWidget();
          } finally {
            busy = false;
            notifyListeners();
          }
        }),
      );

  Future<bool> importExams({required VerifySchoolLogin verify}) => _runSchool(
    () => _schoolAccess.read(verify, (session) async {
      final result = await fetchSchoolExams(session, term: schedule?.term);
      session.checkActive();
      if (!await agenda.replaceExams(result.term, result.exams)) {
        throw SchoolRequestError(agenda.error ?? '安排正在保存，请稍后重试。');
      }
    }),
  );

  Future<bool> importDeadlines(
    DeadlineSource source, {
    required VerifySchoolLogin verify,
  }) => _runSchool(
    () => _schoolAccess.readLearningPlatform(source, verify, (
      session,
      page,
    ) async {
      final deadlines = await switch (source) {
        DeadlineSource.lexue => fetchLexueDeadlines(session, page),
        DeadlineSource.eclass => fetchEclassDeadlines(session),
      };
      session.checkActive();
      if (!await agenda.mergeDeadlines(deadlines)) {
        throw SchoolRequestError(agenda.error ?? '安排正在保存，请稍后重试。');
      }
    }),
  );

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

  Future<bool> setWeekRange({required int first, required int last}) async {
    final current = schedule;
    if (current == null || busy) return false;
    return _save(current.copyWith(firstWeek: first, lastWeek: last));
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

      return await _save(saved);
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
      final changingTerm = _schedule?.term != next.term;
      _schedule = next;
      if (changingTerm) {
        _goToCurrentWeek();
      } else {
        final available = weeks;
        week = week.clamp(available.first, available.last);
      }
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

  Future<void> setConfirmDelete(bool value) async {
    try {
      await _preferences.setBool('confirmDelete', value);
      confirmDelete = value;
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
      notifyListeners();
    }
  }
}
