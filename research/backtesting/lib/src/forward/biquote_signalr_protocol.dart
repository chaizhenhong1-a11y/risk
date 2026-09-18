import 'dart:convert';

const String signalRRecordSeparator = '\u001e';

final class BiQuoteSignalRProtocol {
  const BiQuoteSignalRProtocol();

  String handshake() =>
      '${jsonEncode({'protocol': 'json', 'version': 1})}$signalRRecordSeparator';

  String invocation({
    required String invocationId,
    required String target,
    required List<Object?> arguments,
  }) =>
      '${jsonEncode({'type': 1, 'invocationId': invocationId, 'target': target, 'arguments': arguments})}$signalRRecordSeparator';

  List<Map<String, dynamic>> decode(String payload) {
    final messages = <Map<String, dynamic>>[];
    for (final frame in payload.split(signalRRecordSeparator)) {
      if (frame.trim().isEmpty) continue;
      final decoded = jsonDecode(frame);
      if (decoded is! Map) {
        throw const FormatException('SignalR frame is not a JSON object');
      }
      messages.add(Map<String, dynamic>.from(decoded));
    }
    return messages;
  }
}
