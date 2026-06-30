import 'package:flutter_test/flutter_test.dart';
import 'package:santander_consumer_clientes/core/utils/scoring_helper.dart';

void main() {
  test('segmento PREMIER para score >= 700', () {
    expect(ScoringHelper.segmentoLabel('PREMIER'), 'PREMIER');
    expect(ScoringHelper.scoreProgress(750), closeTo(0.75, 0.01));
  });
}
