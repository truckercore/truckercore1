import 'package:flutter/material.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(title: const Text('Compare Plans')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Upsell message
          Card(
            color: Colors.blue.shade50,
            child: const ListTile(
              leading: Icon(Icons.workspace_premium, color: Colors.orange),
              title: Text(
                'Never pay a fine again. RoadDogg keeps you compliant across 50 states with legal truck routes, weigh station alerts, and restricted road warnings.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Grid or stacked cards
          isWide ? _DesktopGrid() : const _MobileStack(),
          const SizedBox(height: 24),
          // Notes
          const Text(
            'Key Notes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Free Plan → Good for adoption, but drivers quickly hit limitations.\n'
            'Premium Driver / Owner-Op (\$14.99/mo) → Unlocks Route Planning folder, RoadDogg, compliance, weigh stations, low bridge alerts, inspections.\n'
            'Fleet (\$149/mo, up to 5 trucks) → Fleet managers get Route Planning + analytics + compliance reports.\n'
            'Broker (\$199/mo) → Compliance-checked loads, Route Planning, RoadDogg suggestions.\n'
            'Enterprise (Custom) → White-label, API, advanced analytics, custom RLS policies.',
          ),
        ],
      ),
    );
  }
}

class _DesktopGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 5 columns where space allows, otherwise wrap
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final cardW = (maxW - 16 * 4) / 5; // spacing approx for 5 cols
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: cardW, child: const _PlanFree()),
            SizedBox(width: cardW, child: const _PlanDriver()),
            SizedBox(width: cardW, child: const _PlanFleet()),
            SizedBox(width: cardW, child: const _PlanBroker()),
            SizedBox(width: cardW, child: const _PlanEnterprise()),
          ],
        );
      },
    );
  }
}

class _MobileStack extends StatelessWidget {
  const _MobileStack();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _PlanDriver(),
        SizedBox(height: 12),
        _PlanFree(),
        SizedBox(height: 12),
        _PlanFleet(),
        SizedBox(height: 12),
        _PlanBroker(),
        SizedBox(height: 12),
        _PlanEnterprise(),
      ],
    );
  }
}

// Reusable badges and feature row
Widget _badge(String text, Color color, {Color? fg}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: (fg ?? Colors.white).withValues(alpha: 0.1)),
  ),
  child: Text(text, style: TextStyle(color: fg ?? Colors.white, fontSize: 12)),
);

Widget _feat(String text, bool has) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Icon(
      has ? Icons.check_circle : Icons.cancel,
      size: 18,
      color: has ? Colors.green : Colors.redAccent,
    ),
    const SizedBox(width: 6),
    Expanded(child: Text(text)),
  ],
);

// Plan cards ----------------------------------------------------
class _PlanFree extends StatelessWidget {
  const _PlanFree();
  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      headerColor: const Color(0xFFF3F4F6),
      headerFg: const Color(0xFF374151),
      title: 'Free',
      price: '\$0 / month',
      badge: _badge('Get Started Free', Colors.white, fg: Colors.orange),
      cta: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF97316),
          side: const BorderSide(color: Color(0xFFF97316)),
        ),
        child: const Text('Sign Up Free'),
      ),
      features: const [
        _FeatLine('Basic GPS routing', true),
        _FeatLine('Truck-safe routing (STAA)', false),
        _FeatLine('Route Planning folder', false),
        _FeatLine('RoadDogg AI', false),
        _FeatLine('Load board (view only)', true),
        _FeatLine('Pre/Post Trip inspections (limited)', true),
      ],
    );
  }
}

class _PlanDriver extends StatelessWidget {
  const _PlanDriver();
  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      highlight: true,
      headerColor: const Color(0xFF1E3A8A),
      headerFg: Colors.white,
      title: 'Driver / Owner-Op',
      price: '\$14.99 / month',
      priceColor: const Color(0xFF10B981),
      badge: _badge('Most Popular', const Color(0xFFF97316)),
      cta: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF97316),
          foregroundColor: Colors.white,
        ),
        child: const Text('Start Premium'),
      ),
      features: const [
        _FeatLine('Full Route Planning folder (all 50 states)', true),
        _FeatLine('Prohibited road alerts', true),
        _FeatLine('Weigh station & low-bridge alerts', true),
        _FeatLine('Hazmat routing alerts', true),
        _FeatLine('RoadDogg AI assistant', true),
        _FeatLine('Load board + job board (apply/search)', true),
        _FeatLine('Compliance report export (PDF for DOT/IFTA)', true),
        _FeatLine('Pre/Post Trip inspections', true),
      ],
    );
  }
}

class _PlanFleet extends StatelessWidget {
  const _PlanFleet();
  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      headerColor: const Color(0xFF1E3A8A),
      headerFg: Colors.white,
      title: 'Fleet (up to 5 trucks)',
      price: '\$149 / month',
      priceColor: const Color(0xFF10B981),
      cta: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1E3A8A),
          side: const BorderSide(color: Color(0xFF1E3A8A)),
        ),
        child: const Text('Upgrade Now'),
      ),
      features: const [
        _FeatLine('All Driver features, plus:', true),
        _FeatLine('Fleet Analytics Dashboard', true),
        _FeatLine('Route Planning (multi-state compliance checks)', true),
        _FeatLine('Real-time alerts for restricted road entry', true),
        _FeatLine('Export compliance & performance reports', true),
        _FeatLine('Assign drivers only on legal routes', true),
      ],
    );
  }
}

class _PlanBroker extends StatelessWidget {
  const _PlanBroker();
  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      headerColor: const Color(0xFF10B981),
      headerFg: Colors.white,
      title: 'Broker',
      price: '\$199 / month',
      priceFgOverride: Colors.white,
      cta: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
        ),
        child: const Text('Get Started'),
      ),
      features: const [
        _FeatLine('All Fleet features, plus:', true),
        _FeatLine('Broker-specific Route Planning access', true),
        _FeatLine('Compliance-checked load posting', true),
        _FeatLine('RoadDogg suggestions (lane-specific)', true),
        _FeatLine('Attach compliance playbook PDFs to loads', true),
      ],
    );
  }
}

class _PlanEnterprise extends StatelessWidget {
  const _PlanEnterprise();
  @override
  Widget build(BuildContext context) {
    return _PlanCard(
      headerColor: const Color(0xFF111827),
      headerFg: const Color(0xFFFACC15),
      title: 'Enterprise (50+ trucks)',
      price: 'Custom (Request Demo)',
      cta: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111827),
          side: const BorderSide(color: Color(0xFF111827)),
        ),
        child: const Text('Contact Sales'),
      ),
      features: const [
        _FeatLine('All Broker features, plus:', true),
        _FeatLine('White-label branding', true),
        _FeatLine('API access & integrations', true),
        _FeatLine('Custom analytics dashboards', true),
        _FeatLine('Premium RLS enforcement', true),
        _FeatLine('Dedicated support team', true),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Color headerColor;
  final Color headerFg;
  final String title;
  final String price;
  final Color? priceColor;
  final Color? priceFgOverride;
  final Widget? badge;
  final List<Widget> features;
  final Widget cta;
  final bool highlight;
  const _PlanCard({
    required this.headerColor,
    required this.headerFg,
    required this.title,
    required this.price,
    required this.features,
    required this.cta,
    this.priceColor,
    this.priceFgOverride,
    this.badge,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: highlight ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlight
            ? const BorderSide(color: Color(0xFF1E3A8A), width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: headerFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (badge != null) badge!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    color: priceFgOverride ?? (priceColor ?? Colors.black),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  child: Text(price),
                ),
                const SizedBox(height: 8),
                ...features,
                const SizedBox(height: 12),
                Row(children: [cta]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatLine extends StatelessWidget {
  final String text;
  final bool has;
  const _FeatLine(this.text, this.has);
  @override
  Widget build(BuildContext context) => _feat(text, has);
}
