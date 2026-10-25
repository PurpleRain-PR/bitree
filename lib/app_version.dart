import 'package:package_info_plus/package_info_plus.dart';

Future<String> appVersion() async {
  const version = String.fromEnvironment('BITREE_VERSION');
  if (version.isNotEmpty) return version;

  return 'v${(await PackageInfo.fromPlatform()).version}';
}
