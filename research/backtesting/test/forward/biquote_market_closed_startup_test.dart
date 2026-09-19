import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_rest_client.dart';

void main() {
  test(
    'explicit no-tick 404 is market-closed evidence, not transport failure',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = HttpStatus.notFound;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'message': "No tick data available for 'XAUUSD'"}),
        );
        await request.response.close();
      });
      final client = BiQuoteRestClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );

      expect(await client.latestTickOrNull('XAUUSD'), isNull);

      client.close();
      await subscription.cancel();
      await server.close(force: true);
    },
  );

  test(
    'other provider failures stay failures and are not called closed',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('provider unavailable');
        await request.response.close();
      });
      final client = BiQuoteRestClient(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      );

      await expectLater(
        client.latestTickOrNull('XAUUSD'),
        throwsA(isA<HttpException>()),
      );

      client.close();
      await subscription.cancel();
      await server.close(force: true);
    },
  );
}
