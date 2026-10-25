import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.url,
    required this.notes,
    required this.isDevelopment,
  });

  final String version;
  final Uri url;
  final String notes;
  final bool isDevelopment;
}

Future<List<AppRelease>> availableAppReleases(
  String installed, {
  DateTime? builtAt,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  try {
    final releases = <AppRelease>[];
    final normalized = installed.replaceFirst(RegExp(r'^v'), '');
    final current = Version.parse(normalized.split('-').first);
    final [stable, dev] = await Future.wait([
      _readJson(
        client,
        Uri.https('api.github.com', '/repos/so1ve/bitree/releases/latest'),
      ),
      _readJson(
        client,
        Uri.https('api.github.com', '/repos/so1ve/bitree/releases/tags/dev'),
      ),
    ]);
    if (stable != null &&
        stable['draft'] != true &&
        stable['prerelease'] != true) {
      final tag = stable['tag_name'] as String;
      final version = Version.parse(tag.replaceFirst(RegExp(r'^v'), ''));
      if (!version.isPreRelease &&
          (version > current ||
              (version == current && normalized.contains('-')))) {
        releases.add(
          AppRelease(
            version: tag,
            url: Uri.parse(stable['html_url'] as String),
            notes: stable['body'] as String? ?? '',
            isDevelopment: false,
          ),
        );
      }
    }

    if (dev == null || dev['draft'] == true) return releases;

    final suffix = '-${Platform.operatingSystem}-update.json';
    final asset = (dev['assets'] as List)
        .cast<Map<String, dynamic>>()
        .where((asset) => (asset['name'] as String).endsWith(suffix))
        .firstOrNull;
    if (asset == null) return releases;

    final metadata = await _readJson(
      client,
      Uri.parse(asset['browser_download_url'] as String),
    );
    if (metadata == null) return releases;

    final version = metadata['version'] as String;
    final publishedBuildTime = DateTime.parse(metadata['builtAt'] as String);
    final newer = builtAt == null
        ? version != installed
        : publishedBuildTime.isAfter(builtAt);
    if (newer) {
      releases.add(
        AppRelease(
          version: version,
          url: Uri.parse(dev['html_url'] as String),
          notes: dev['body'] as String? ?? '',
          isDevelopment: true,
        ),
      );
    }

    return releases;
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>?> _readJson(HttpClient client, Uri url) async {
  final request = await client.getUrl(url).timeout(const Duration(seconds: 15));
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
  return jsonDecode(text) as Map<String, dynamic>;
}
