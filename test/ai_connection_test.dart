import 'package:flutter_test/flutter_test.dart';
import 'package:streakup/service/ai_service.dart';

void main() {
  test('Flutter can connect to StreakUp AI server', () async {
    final connected = await AIService.testConnection();

    expect(connected, true);
  });
}
