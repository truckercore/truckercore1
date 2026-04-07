import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class JobsBoardPage extends StatelessWidget {
  const JobsBoardPage({super.key});
  @override
  Widget build(BuildContext context) {
    // TODO: load assigned/open jobs via Supabase rows/realtime
    final jobs = const [
      {'id':'job_1','type':'tire','status':'new','mi': 4.2,'eta': 30},
      {'id':'job_2','type':'tow','status':'assigned','mi': 12.7,'eta': 45},
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final j = jobs[i];
                return ListTile(
                  leading: Icon(j['type']=='tow'?Icons.local_shipping:Icons.build),
                  title: Text('Request ${j['type']} • ${j['status']}'),
                  subtitle: Text('${j['mi']} mi • ETA ${j['eta']} min'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/job/${j['id']}'),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
