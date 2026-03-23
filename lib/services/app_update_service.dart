import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ingapirca_league_frontend/core/constants/environments.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ForceUpdateResult {
  const ForceUpdateResult({
    required this.required,
    this.currentVersion = '',
    this.requiredVersion = '',
    this.storeUrl,
  });

  final bool required;
  final String currentVersion;
  final String requiredVersion;
  final String? storeUrl;
}

class AppUpdateService {
  static const String baseUrl = Environment.baseUrl;

  Future<ForceUpdateResult> checkForceUpdate() async {
    if (kIsWeb) {
      return const ForceUpdateResult(required: false);
    }

    final targetPlatform = defaultTargetPlatform;
    if (targetPlatform != TargetPlatform.android &&
        targetPlatform != TargetPlatform.iOS) {
      return const ForceUpdateResult(required: false);
    }

    try {
      final appInfo = await PackageInfo.fromPlatform();
      final currentVersion = appInfo.version.trim();

      final response = await http
          .get(Uri.parse('$baseUrl/health/public'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return const ForceUpdateResult(required: false);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const ForceUpdateResult(required: false);
      }

      final appUpdate = decoded['app_update'];
      if (appUpdate is! Map<String, dynamic>) {
        return const ForceUpdateResult(required: false);
      }

      final forceEnabled = _toBool(appUpdate['force_update']);
      if (!forceEnabled) {
        return const ForceUpdateResult(required: false);
      }

      final minAndroidVersion =
          (appUpdate['min_android_version'] ?? '').toString().trim();
      final minIosVersion =
          (appUpdate['min_ios_version'] ?? '').toString().trim();
      final androidStoreUrl =
          (appUpdate['android_store_url'] ?? '').toString().trim();
      final iosStoreUrl = (appUpdate['ios_store_url'] ?? '').toString().trim();

      final requiredVersion = targetPlatform == TargetPlatform.android
          ? minAndroidVersion
          : minIosVersion;

      if (requiredVersion.isEmpty) {
        return const ForceUpdateResult(required: false);
      }

      final isOutdated = _compareVersions(currentVersion, requiredVersion) < 0;

      if (!isOutdated) {
        return const ForceUpdateResult(required: false);
      }

      return ForceUpdateResult(
        required: true,
        currentVersion: currentVersion,
        requiredVersion: requiredVersion,
        storeUrl: targetPlatform == TargetPlatform.android
            ? (androidStoreUrl.isEmpty ? null : androidStoreUrl)
            : (iosStoreUrl.isEmpty ? null : iosStoreUrl),
      );
    } catch (_) {
      // Fail-open if check cannot be completed (network/timeouts/json issues).
      return const ForceUpdateResult(required: false);
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 'yes';
    }
    return false;
  }

  int _compareVersions(String left, String right) {
    final a = _normalizeVersion(left);
    final b = _normalizeVersion(right);
    final maxLen = a.length > b.length ? a.length : b.length;

    for (var i = 0; i < maxLen; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) {
        return ai.compareTo(bi);
      }
    }
    return 0;
  }

  List<int> _normalizeVersion(String version) {
    final clean = version.split('+').first.trim();
    if (clean.isEmpty) return [0];

    return clean.split('.').map((part) {
      final parsed = int.tryParse(part.trim());
      return parsed ?? 0;
    }).toList();
  }
}
