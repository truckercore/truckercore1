import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:truckercore1/common/state/phase2_flags.dart';
import 'package:truckercore1/common/state/plan_tier.dart';
import 'package:truckercore1/features/ai/trihaul_service.dart';
import 'package:truckercore1/features/pricing/credit_service.dart';
import 'package:truckercore1/features/pricing/market_rates_service.dart';

void main() {
  group('Phase2 providers (mock path)', () {
    ProviderContainer containerFactory({required PlanTier plan}) {
      return ProviderContainer(
        overrides: [
          phase2FlagsProvider.overrideWithValue(
            const Phase2Flags(
              marketRates: true,
              trihaul: true,
              brokerCredit: true,
              mock: true,
            ),
          ),
          planTierProvider.overrideWithValue(plan),
        ],
      );
    }

    test('MarketRatesService: 400 on invalid zips', () async {
      final c = containerFactory(plan: PlanTier.pro);
      final svc = c.read(marketRatesServiceProvider);
      expect(
        () => svc.getLaneRates(originZip: '3030', destZip: '75201'),
        throwsA(predicate((e) => e.toString().contains('400'))),
      );
      c.dispose();
    });

    test('MarketRatesService: 403 on free plan', () async {
      final c = containerFactory(plan: PlanTier.free);
      final svc = c.read(marketRatesServiceProvider);
      expect(
        () => svc.getLaneRates(originZip: '30301', destZip: '75201'),
        throwsA(predicate((e) => e.toString().contains('403'))),
      );
      c.dispose();
    });

    test('MarketRatesService: returns mock payload for Pro', () async {
      final c = containerFactory(plan: PlanTier.pro);
      final svc = c.read(marketRatesServiceProvider);
      final res = await svc.getLaneRates(originZip: '30301', destZip: '75201');
      expect(res.laneKey, '30301->75201');
      expect(res.latestSpot, 2.25);
      expect(res.latestContract, 2.00);
      expect(res.sampleSize, 184);
      expect(res.series.length, 3);
      c.dispose();
    });

    test('TrihaulService: 403 on Pro (requires Premium)', () async {
      final c = containerFactory(plan: PlanTier.pro);
      final svc = c.read(trihaulServiceProvider);
      expect(
        () => svc.suggest(origin: '30301', dest: '75201', equipment: 'van'),
        throwsA(predicate((e) => e.toString().contains('403'))),
      );
      c.dispose();
    });

    test('TrihaulService: returns 3 suggestions on Premium', () async {
      final c = containerFactory(plan: PlanTier.premium);
      final svc = c.read(trihaulServiceProvider);
      final sug = await svc.suggest(
        origin: '30301',
        dest: '75201',
        equipment: 'van',
      );
      expect(sug.options.length, 3);
      expect(sug.options.first.estPpm, greaterThan(0));
      c.dispose();
    });

    test('CreditService: deterministic mock profiles', () async {
      final c = containerFactory(plan: PlanTier.free);
      final svc = c.read(creditServiceProvider);
      final a = await svc.getBrokerCredit(
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );
      final b = await svc.getBrokerCredit(
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      );
      final x = await svc.getBrokerCredit(
        'cccccccc-cccc-cccc-cccc-ccccccccccc0',
      );
      expect(a!.score, 86);
      expect(b!.score, 72);
      expect(x!.score, 80);
      c.dispose();
    });
  });
}
