import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/core/data/tender_delivery_terminal_patch_service.dart';

void main() {
  test('failed tender delivery statuses are terminal for active count', () {
    expect(isTenderDeliveryFailureTerminalStatus('failed'), isTrue);
    expect(isTenderDeliveryFailureTerminalStatus('failed_late'), isTrue);
    expect(isTenderDeliveryFailureTerminalStatus('expired'), isTrue);
  });

  test('statuses already handled by dispatcher are not double counted', () {
    expect(isTenderDeliveryFailureTerminalStatus('completed'), isFalse);
    expect(isTenderDeliveryFailureTerminalStatus('cancelled'), isFalse);
    expect(isTenderDeliveryFailureTerminalStatus('in_transit'), isFalse);
  });
}
