import 'package:supabase_flutter/supabase_flutter.dart';

String sanitizeUserFacingError(Object? error, {String fallback = 'Bir hata olustu.'}) {
  if (error == null) return fallback;

  if (error is PostgrestException) {
    final message = error.message.trim();
    return message.isNotEmpty ? message : fallback;
  }

  if (error is AuthException) {
    final message = error.message.trim();
    return message.isNotEmpty ? message : fallback;
  }

  var text = error.toString().trim();
  if (text.isEmpty) return fallback;

  text = text.replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');

  final postgrestMessageMatch = RegExp(
    r'message:\s*([^,\)]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (postgrestMessageMatch != null) {
    final message = postgrestMessageMatch.group(1)?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
  }

  final postgresWrappedMatch = RegExp(
    r'PostgrestException\([^)]*message:\s*([^,\)]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (postgresWrappedMatch != null) {
    final message = postgresWrappedMatch.group(1)?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
  }

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where(
        (line) =>
            !line.toLowerCase().startsWith('code:') &&
            !line.toLowerCase().startsWith('details:') &&
            !line.toLowerCase().startsWith('hint:') &&
            !line.toLowerCase().startsWith('status code:') &&
            !line.toLowerCase().startsWith('stack trace:'),
      )
      .toList();

  if (lines.isEmpty) return fallback;

  final firstLine = lines.first;
  if (firstLine.startsWith('PostgrestException')) {
    return fallback;
  }

  return firstLine;
}
