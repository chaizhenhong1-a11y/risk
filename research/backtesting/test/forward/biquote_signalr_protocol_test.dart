import 'package:test/test.dart';
import 'package:tradeforge_backtesting/src/forward/biquote_signalr_protocol.dart';

void main() {
  const protocol = BiQuoteSignalRProtocol();

  test('handshake uses SignalR JSON protocol record separator', () {
    expect(protocol.handshake(), '{"protocol":"json","version":1}\u001e');
  });

  test('Subscribe has one string-array method parameter', () {
    expect(
      protocol.invocation(
        invocationId: '1',
        target: 'Subscribe',
        arguments: [
          ['XAUUSD'],
        ],
      ),
      '{"type":1,"invocationId":"1","target":"Subscribe",'
      '"arguments":[["XAUUSD"]]}\u001e',
    );
  });

  test('decoder exposes invocation completion frame', () {
    final frames = protocol.decode(
      '{}\u001e'
      '{"type":3,"invocationId":"1","result":null}\u001e',
    );
    expect(frames, hasLength(2));
    expect(frames.last['type'], 3);
    expect(frames.last['invocationId'], '1');
  });
}
