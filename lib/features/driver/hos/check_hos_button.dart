import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A small button that checks whether the driver's 8/2 split is valid for today
/// by calling the `hos_is_valid_split` RPC. The RPC is expected to accept:
///   - driver_id (uuid text)
///   - log_date (date as YYYY-MM-DD)
/// and return a boolean.
class CheckHosButton extends StatefulWidget {
  final String driverId; // UUID string
  const CheckHosButton({super.key, required this.driverId});

  @override
  State<CheckHosButton> createState() => _CheckHosButtonState();
}

class _CheckHosButtonState extends State<CheckHosButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final client = Supabase.instance.client;

                // Pass a DATE only: YYYY-MM-DD (function expects `date`, not timestamp)
                final todayUtc = DateTime.now().toUtc();
                final logDate = DateFormat('yyyy-MM-dd').format(todayUtc);

                final res = await client.rpc('hos_is_valid_split', params: {
                  'driver_id': widget.driverId,
                  'log_date': logDate,
                });

                // Supabase returns dynamic; coerce to bool safely
                final isValid = (res as bool?) ?? false;

                if (!context.mounted) return;
                if (!isValid) {
                  // Use dialog for a stronger stop signal
                  showDialog(
                    context: context,
                    builder: (_) => const AlertDialog(
                      title: Text('HOS Violation'),
                      content: Text('Your 8/2 split is invalid. Review log.'),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('HOS split is valid')),
                  );
                }
              } on PostgrestException catch (e) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('HOS check failed: ${e.message}')),
                );
              } catch (e) {
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('HOS check error: $e')),
                );
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      child: _loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text('Check HOS Compliance'),
    );
  }
}
