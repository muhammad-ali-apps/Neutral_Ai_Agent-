import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Safely opens external URLs across Desktop, Mobile, and Web platforms.
///
/// Features:
/// - Handles bare URLs, scheme-less URLs (e.g. www.google.com -> https://www.google.com).
/// - Strips accidental trailing markdown punctuation or enclosing quotes/brackets.
/// - Uses [url_launcher] as primary handler.
/// - Falls back to native OS process commands (Windows cmd start, macOS open, Linux xdg-open)
///   to ensure zero failure on desktop even during live hot reloads.
Future<bool> openAppUrl(String rawUrl) async {
  var url = rawUrl.trim();
  if (url.isEmpty) return false;

  // Trim opening enclosing brackets/quotes
  while (url.isNotEmpty &&
      (url.startsWith('<') ||
          url.startsWith('"') ||
          url.startsWith("'") ||
          url.startsWith('(') ||
          url.startsWith('['))) {
    url = url.substring(1).trim();
  }

  // Trim closing brackets/quotes and trailing punctuation often added by LLMs
  while (url.isNotEmpty &&
      (url.endsWith('>') ||
          url.endsWith('"') ||
          url.endsWith("'") ||
          url.endsWith(')') ||
          url.endsWith(']') ||
          url.endsWith('.') ||
          url.endsWith(',') ||
          url.endsWith(';') ||
          url.endsWith(':'))) {
    url = url.substring(0, url.length - 1).trim();
  }

  if (url.isEmpty) return false;

  // Add default https scheme if missing
  if (!url.startsWith('http://') &&
      !url.startsWith('https://') &&
      !url.startsWith('mailto:') &&
      !url.startsWith('tel:')) {
    url = 'https://$url';
  }

  // 1. Primary: url_launcher
  try {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    }
  } catch (e) {
    debugPrint('url_launcher attempt error: $e');
  }

  // 2. Desktop Fallback: Native OS processes
  if (!kIsWeb) {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
        return true;
      }
    } catch (e) {
      debugPrint('Desktop native launch error: $e');
    }
  }

  return false;
}
