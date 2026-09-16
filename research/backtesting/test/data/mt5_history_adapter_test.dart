import 'package:test/test.dart';
import 'package:tradeforge_backtesting/tradeforge_backtesting.dart';

void main() {
  const adapter = Mt5HistoryAdapter();

  group('Mt5HistoryAdapter', () {
    test('parses the TradeForge V1 MT5 tab-separated format', () {
      final result = adapter.parse(
        content: _sample,
        timeframe: MarketTimeframe.h1,
      );

      expect(result.timeframe, MarketTimeframe.h1);
      expect(result.candles, hasLength(3));

      final first = result.candles.first;
      expect(first.openTime, DateTime(2024, 1, 2, 1));
      expect(first.closeTime, DateTime(2024, 1, 2, 2));
      expect(first.open, 2062.91);
      expect(first.high, 2066.54);
      expect(first.low, 2062.80);
      expect(first.close, 2063.66);
      expect(first.volume, 4278);
    });

    test('uses timeframe duration for candle close time', () {
      final result = adapter.parse(
        content: _singleRow,
        timeframe: MarketTimeframe.m15,
      );

      expect(result.candles.single.closeTime, DateTime(2024, 1, 2, 1, 15));
    });

    test('preserves MT5 wall-clock time without guessing timezone', () {
      final candle = adapter
          .parse(content: _singleRow, timeframe: MarketTimeframe.h4)
          .candles
          .single;

      expect(candle.openTime.isUtc, isFalse);
      expect(candle.openTime, DateTime(2024, 1, 2, 1));
    });

    test('maps TICKVOL into Candle.volume', () {
      final candle = adapter
          .parse(content: _singleRow, timeframe: MarketTimeframe.h1)
          .candles
          .single;

      expect(candle.volume, 4278);
    });

    test('rejects unsupported headers', () {
      expect(
        () => adapter.parse(
          content: _singleRow.replaceFirst('<TICKVOL>', '<VOLUME>'),
          timeframe: MarketTimeframe.h1,
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed rows', () {
      const malformed =
          '<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>\n'
          '2024.01.02\t01:00:00\t2062.91\t2066.54';

      expect(
        () => adapter.parse(content: malformed, timeframe: MarketTimeframe.h1),
        throwsFormatException,
      );
    });

    test('rejects out-of-order history instead of sorting it', () {
      const outOfOrder =
          '<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>\n'
          '2024.01.02\t02:00:00\t2063.68\t2065.94\t2062.17\t2065.45\t4807\t0\t4\n'
          '2024.01.02\t01:00:00\t2062.91\t2066.54\t2062.80\t2063.66\t4278\t0\t4';

      expect(
        () => adapter.parse(content: outOfOrder, timeframe: MarketTimeframe.h1),
        throwsFormatException,
      );
    });

    test('parsed output can enter the anti-look-ahead feed', () {
      final series = adapter.parse(
        content: _sample,
        timeframe: MarketTimeframe.h1,
      );

      final observations = BacktestCandleFeed(
        series.candles,
      ).observations().toList();

      expect(observations, hasLength(3));
      expect(observations.first.history, hasLength(1));
      expect(observations.last.history, hasLength(3));
    });
  });
}

const _singleRow =
    '<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>\n'
    '2024.01.02\t01:00:00\t2062.91\t2066.54\t2062.80\t2063.66\t4278\t0\t4';

const _sample =
    '<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>\n'
    '2024.01.02\t01:00:00\t2062.91\t2066.54\t2062.80\t2063.66\t4278\t0\t4\n'
    '2024.01.02\t02:00:00\t2063.68\t2065.94\t2062.17\t2065.45\t4807\t0\t4\n'
    '2024.01.02\t03:00:00\t2065.43\t2069.97\t2064.88\t2066.53\t9827\t0\t4';
