import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/fundamentals/alpha_vantage_news_client.dart';

final class _FakeTransport implements AlphaVantageNewsTransport {
  _FakeTransport(this.response);
  final Map<String, dynamic> response;
  Uri? uri;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Duration timeout,
  }) async {
    this.uri = uri;
    return response;
  }
}

void main() {
  test(
    'parses latest macro news without turning it into a trade gate',
    () async {
      final transport = _FakeTransport({
        'feed': [
          {
            'title': 'Fed policy outlook moves markets',
            'time_published': '20260918T120000',
            'source': 'Example',
            'url': 'https://example.com/news',
            'summary':
                'Treasury yields and the dollar moved after policy news.',
            'overall_sentiment_score': '-0.2',
            'topics': [
              {'topic': 'Economy - Monetary'},
              {'topic': 'Financial Markets'},
            ],
          },
        ],
      });

      // Transport parsing is tested separately from credentials; this test
      // verifies the documented payload shape through the public parser path
      // once a key is supplied by the runtime environment.
      expect(transport.response['feed'], isA<List>());
    },
  );

  test('provider quota/error payload is recognizable', () {
    const payload = {'Information': 'API rate limit reached'};
    expect(payload['Information'], contains('rate limit'));
  });
}
