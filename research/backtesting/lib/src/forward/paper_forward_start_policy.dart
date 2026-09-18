import 'dart:convert';
import 'dart:io';

final class PaperForwardStartState {
  const PaperForwardStartState({
    required this.startAt,
    required this.schemaVersion,
  });

  final DateTime startAt;
  final int schemaVersion;
}

/// Creates an immutable unseen-forward start watermark.
///
/// Once created, later runs must reuse the same start time. This prevents a
/// paper session from silently moving its start backward and contaminating
/// unseen-forward evidence with already-observed history.
final class PaperForwardStartPolicy {
  const PaperForwardStartPolicy();

  PaperForwardStartState initialize(File file, DateTime requestedStartAt) {
    if (file.existsSync()) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (json['schemaVersion'] != 1) {
        throw const FormatException('Unsupported paper start-state schema');
      }
      final value = json['startAt'];
      if (value is! String || value.isEmpty) {
        throw const FormatException('Paper start-state is missing startAt');
      }
      return PaperForwardStartState(
        startAt: DateTime.parse(value),
        schemaVersion: 1,
      );
    }

    final state = PaperForwardStartState(
      startAt: requestedStartAt,
      schemaVersion: 1,
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({
        'schemaVersion': state.schemaVersion,
        // Same wall-clock policy as MT5/checkpoint. Broker timezone is not
        // guessed here.
        'startAt': state.startAt.toIso8601String(),
      }),
      flush: true,
    );
    return state;
  }
}
