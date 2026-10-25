const schoolPageNotReady = '学校网页还在加载，请稍后重试。';
const schoolScheduleNotReady = '还未识别到课表，请等页面加载完成后重试。';
const schoolLoginNotReady = '请先在学校网页中完成登录。';

class SessionExpired implements Exception {
  const SessionExpired();

  @override
  String toString() => '请先登录学校账号。本地课表可继续使用。';
}

class SchoolRequestError implements Exception {
  const SchoolRequestError(this.message);
  final String message;

  @override
  String toString() => message;
}

String? schoolPageError(String text) {
  if (text.contains('Illegal referrer')) {
    return '教学中心拒绝此页面来源，请返回后重新打开学校网页。';
  }
  if (text.contains('Access Denied') || text.contains('您没有权限访问该资源')) {
    return 'WebVPN 拒绝访问此页面，请从 WebVPN 首页确认教学中心入口。';
  }
  return null;
}
