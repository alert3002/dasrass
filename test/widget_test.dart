import 'package:dastrass_app/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API base задан', () {
    expect(ApiConfig.base, isNotEmpty);
    expect(ApiConfig.base, contains('/api'));
  });
}
