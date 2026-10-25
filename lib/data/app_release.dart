import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.url,
    required this.notes,
  });

  final Version version;
  final Uri url;
  final String notes;

  bool isNewerThan(String installed) {
    final normalized = installed.startsWith('v')
        ? installed.substring(1)
        : installed;
    final current = Version.parse(normalized.split('-').first);

    return version > current ||
        (version == current && normalized.contains('-'));
  }
}

Future<AppRelease?> latestAppRelease() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  try {
    final request = await client
        .getUrl(
          Uri.https('api.github.com', '/repos/so1ve/bitree/releases/latest'),
        )
        .timeout(const Duration(seconds: 15));
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'BITree')
      ..set('X-GitHub-Api-Version', '2022-11-28');

    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode == HttpStatus.notFound) return null;
    if (response.statusCode == HttpStatus.forbidden ||
        response.statusCode == HttpStatus.tooManyRequests) {
      throw const HttpException('检查更新次数过多，请稍后重试。');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GitHub 暂时无法提供更新信息（${response.statusCode}）。');
    }

    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));
    final value = jsonDecode(text) as Map<String, dynamic>;
    if (value['draft'] == true || value['prerelease'] == true) return null;

    final tag = value['tag_name'] as String;
    final version = Version.parse(tag.startsWith('v') ? tag.substring(1) : tag);
    if (version.isPreRelease) return null;

    return AppRelease(
      version: version,
      url: Uri.https('github.com', '/so1ve/bitree/releases/tag/$tag'),
      notes: value['body'] as String? ?? '',
    );
  } finally {
    client.close(force: true);
  }
}
