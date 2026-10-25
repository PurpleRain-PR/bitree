enum SchoolNetwork {
  campus,
  webvpn;

  Uri get base => Uri.parse(
    this == campus ? 'https://jxzxehallapp.bit.edu.cn' : 'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421faef5b842238695c720999bcd6572a216b231105adc27d',
  );

  Uri get app => Uri.parse('$base/jwapp/sys/wdkbby/*default/index.do');

  Uri get authLanding => Uri.parse('$base/jwapp/sys/xsfacx/*default/index.do');

  static Uri get webvpnTeachingLogin => Uri.parse(
    'https://webvpn.bit.edu.cn/https/77726476706e69737468656265737421faef5b842238695c72468ba58c1b26316e8e7f6f/auth-protocol-core/login?service=https%3A%2F%2Fjxzxehallapp.bit.edu.cn%2Fjwapp%2Fsys%2Fxsfacx%2F*default%2Findex.do',
  );

  Uri get loginEntry => this == webvpn
      ? Uri.parse('https://webvpn.bit.edu.cn/login?cas_login=true')
      : authLanding;

  Uri endpoint(String path) => Uri.parse('$base/jwapp/sys/wdkbby/$path');

  bool isApp(Uri uri) => _isPage(uri, app);

  bool isAuthLanding(Uri uri) => _isPage(uri, authLanding);

  bool isLoginLanding(Uri uri) =>
      isAuthLanding(uri) || isApp(uri) || isGatewayHome(uri);

  Set<Uri> get sessionUrls => {
    app,
    authLanding,
    Uri.parse('$base/'),
    Uri.parse('https://sso.bit.edu.cn/cas/'),
    Uri.parse('https://jxzxehall.bit.edu.cn/'),
    Uri.parse('https://webvpn.bit.edu.cn/'),
  };

  bool _isPage(Uri uri, Uri page) {
    if (uri.scheme != page.scheme ||
        uri.host != page.host ||
        uri.port != page.port) {
      return false;
    }
    try {
      // SSO may encode *default as %2Adefault in its callback.
      return Uri.decodeComponent(uri.path) == page.path;
    } on FormatException {
      return false;
    }
  }

  bool isGatewayHome(Uri uri) =>
      this == webvpn && uri.host == 'webvpn.bit.edu.cn' && uri.path == '/';
}

bool isSchoolUrl(Uri uri) =>
    uri.scheme == 'https' &&
    (uri.host == 'bit.edu.cn' || uri.host.endsWith('.bit.edu.cn'));

bool isSchoolLogin(Uri uri) =>
    isSchoolUrl(uri) &&
    (uri.host == 'sso.bit.edu.cn' ||
        uri.host == 'login.bit.edu.cn' ||
        uri.path.contains('/authserver/login') ||
        uri.path.contains('/cas/login') ||
        (uri.host == 'webvpn.bit.edu.cn' && uri.path == '/login'));
