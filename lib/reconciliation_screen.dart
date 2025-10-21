import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReconciliationScreen extends StatefulWidget {
  final String orgId;
  final String edgeBaseUrl; // e.g., https://<project>.functions.supabase.co/connectors
  final Map<String, String> headers; // e.g., { 'Authorization': 'Bearer <service/run token if needed>' }
  const ReconciliationScreen({super.key, required this.orgId, required this.edgeBaseUrl, this.headers = const {}});
  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  String _status = 'Idle';
  Map<String, dynamic>? _lastSummary;
  bool _ok = false;

  Future<List<Map<String, dynamic>>> _parseCsvToRows(PlatformFile file, {required bool isTms}) async {
    final content = utf8.decode(file.bytes ?? await file.readStream!.expand((e) => e).toList());
    final lines = LineSplitter.split(content).toList();
    if (lines.isEmpty) return [];
    final headers = lines.first.split(',').map((s) => s.trim()).toList();
    return lines.skip(1).where((l) => l.trim().isNotEmpty).map((l) {
      final cols = l.split(',');
      final row = <String, String>{};
      for (int i = 0; i < headers.length && i < cols.length; i++) {
        row[headers[i]] = cols[i].trim();
      }
      if (isTms) {
        return {
          'ref_number': row['ref_number'],
          'pickup_at': row['pickup_at'],
          'delivery_at': row['delivery_at'],
          'billable_amount_cents': int.tryParse(row['billable_amount_cents'] ?? '') ?? 0,
          'raw': row,
        };
      } else {
        return {
          'invoice_number': row['invoice_number'],
          'ref_number': row['ref_number'],
          'amount_cents': int.tryParse(row['amount_cents'] ?? '') ?? 0,
          'status': row['status'],
          'issued_at': row['issued_at'],
          'paid_at': row['paid_at'],
          'raw': row,
        };
      }
    }).toList();
  }

  Future<void> _import({required bool tms}) async {
    setState(() { _status = 'Picking file...'; _ok = false; });
    final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['csv','json']);
    if (result == null) { setState(() { _status = 'Cancelled'; }); return; }
    final file = result.files.first;

    List<Map<String, dynamic>> rows;
    if (file.extension?.toLowerCase() == 'json') {
      rows = List<Map<String, dynamic>>.from(json.decode(utf8.decode(file.bytes!)));
    } else {
      rows = await _parseCsvToRows(file, isTms: tms);
    }

    setState(() { _status = 'Uploading...'; });
    final url = '${widget.edgeBaseUrl}/${tms ? 'import_tms' : 'import_acct'}';
    final resp = await http.post(Uri.parse(url),
      headers: {'content-type': 'application/json', ...widget.headers},
      body: json.encode({'org_id': widget.orgId, 'source': file.name, 'rows': rows}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      setState(() { _status = 'Imported OK'; });
    } else {
      setState(() { _status = 'Import failed: ${resp.body}'; });
    }
  }

  Future<void> _reconcile() async {
    setState(() { _status = 'Reconciling...'; _ok = false; });
    final url = '${widget.edgeBaseUrl}/reconcile';
    final resp = await http.post(Uri.parse(url),
      headers: {'content-type': 'application/json', ...widget.headers},
      body: json.encode({'org_id': widget.orgId}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = json.decode(resp.body);
      setState(() {
        _lastSummary = data['summary'] as Map<String, dynamic>?;
        _status = 'Reconciled';
        _ok = true;
      });
    } else {
      setState(() { _status = 'Reconcile failed: ${resp.body}'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _lastSummary;
    return Scaffold(
      appBar: AppBar(title: const Text('Reconciliation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status: $_status'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ElevatedButton(onPressed: () => _import(tms: true), child: const Text('Import TMS')),
            ElevatedButton(onPressed: () => _import(tms: false), child: const Text('Import Accounting')),
            ElevatedButton(onPressed: _reconcile, child: const Text('Run Reconcile')),
          ]),
          const Divider(height: 32),
          if (s != null) ...[
            Row(children: [
              Icon(_ok ? Icons.check_circle : Icons.info, color: _ok ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text('Last Recon: total ${s['total_loads']}, matched ${s['matched']}, mismatches ${s['mismatched_amounts']}, missing inv ${s['missing_invoices']}, missing loads ${s['missing_loads']}'),
            ]),
          ],
        ]),
      ),
    );
  }
}
