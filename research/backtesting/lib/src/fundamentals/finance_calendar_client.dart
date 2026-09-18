import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gold_event_context.dart';

abstract interface class FinanceCalendarTransport {
  Future<Map<String, dynamic>> getJson(Uri uri, {required Duration timeout});
}

final class IoFinanceCalendarTransport implements FinanceCalendarTransport {
  IoFinanceCalendarTransport({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    final request = await _client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join().timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Finance Calendar HTTP ${response.statusCode}: $body',
        uri: uri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException(
        'Finance Calendar response is not an object.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }
}

final class FinanceCalendarClient {
  FinanceCalendarClient({
    FinanceCalendarTransport? transport,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 12),
  }) : _transport = transport ?? IoFinanceCalendarTransport(),
       endpoint =
           endpoint ??
           Uri.parse('https://www.financecalendar.com/wp-json/fc/v1/calendar');

  final FinanceCalendarTransport _transport;
  final Uri endpoint;
  final Duration timeout;

  Future<GoldEventContext> loadGoldContext({
    required DateTime nowUtc,
    Duration lookAhead = const Duration(hours: 24),
  }) async {
    final from = _date(nowUtc.toUtc());
    final to = _date(nowUtc.toUtc().add(lookAhead));
    final uri = endpoint.replace(
      queryParameters: <String, String>{
        'from': from,
        'to': to,
        'impact': 'high',
        'limit': '100',
      },
    );

    final json = await _transport.getJson(uri, timeout: timeout);
    final rawEvents = json['events'];
    final events = <GoldEconomicEvent>[];

    if (rawEvents is List) {
      for (final raw in rawEvents) {
        if (raw is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(raw);
        final time = DateTime.tryParse(
          (map['time_utc'] ?? map['datetime'] ?? '').toString(),
        )?.toUtc();

        if (time == null) {
          continue;
        }

        events.add(
          GoldEconomicEvent(
            id: (map['id'] ?? map['slug'] ?? '${map['name']}|$time').toString(),
            name: (map['name'] ?? map['title'] ?? 'Economic event').toString(),
            scheduledAtUtc: time,
            impact: (map['impact'] ?? '').toString(),
            category: (map['category'] ?? '').toString(),
            consensus: _nullable(map['consensus']),
            prior: _nullable(map['prior']),
            actual: _nullable(map['actual']),
            sourceUrl: _nullable(map['url']),
          ),
        );
      }
    }

    events.sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));

    return GoldEventContext(
      observedAtUtc: nowUtc.toUtc(),
      events: List<GoldEconomicEvent>.unmodifiable(events),
      risk: _risk(events, nowUtc.toUtc()),
      source: 'financecalendar.com',
    );
  }

  GoldEventRisk _risk(List<GoldEconomicEvent> events, DateTime now) {
    var caution = false;

    for (final event in events.where((event) => event.isHighImpact)) {
      final delta = event.scheduledAtUtc.difference(now);

      if (delta >= const Duration(minutes: -15) &&
          delta <= const Duration(minutes: 30)) {
        return GoldEventRisk.highRisk;
      }

      if (delta >= const Duration(hours: -1) &&
          delta <= const Duration(hours: 2)) {
        caution = true;
      }
    }

    return caution ? GoldEventRisk.caution : GoldEventRisk.normal;
  }

  String _date(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String? _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }
}
