import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../shipper_service.dart';

class TenderCreatePage extends StatefulWidget {
  const TenderCreatePage({super.key});
  @override State<TenderCreatePage> createState() => _TenderCreatePageState();
}

class _TenderCreatePageState extends State<TenderCreatePage> {
  final _form = GlobalKey<FormState>();
  final _commodity = TextEditingController();
  final _weight = TextEditingController();
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  bool loading = false;

  @override void dispose(){ _commodity.dispose(); _weight.dispose(); _pickup.dispose(); _dropoff.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if(!_form.currentState!.validate()) return;
    setState(()=>loading=true);
    try{
      final supa = Supabase.instance.client;
      final orgId = supa.auth.currentUser!.appMetadata['app_org_id'] as String;
      final svc = ShipperService(supa);
      final id = await svc.createTender(Tender(
        id: 'new', shipperOrgId: orgId,
        pickup: Address(line1:_pickup.text, city:'',state:'',postal:'',country:'US'),
        dropoff: Address(line1:_dropoff.text, city:'',state:'',postal:'',country:'US'),
        commodity: _commodity.text,
        weightKg: double.tryParse(_weight.text) ?? 0,
        equipment: "53' Dry Van",
        status: 'open',
      ));
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tender created $id'))); Navigator.pop(context); }
    } finally { if(mounted) setState(()=>loading=false); }
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tender (Shipper)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key:_form,
          child: Column(children: [
            TextFormField(controller:_commodity, decoration: const InputDecoration(labelText:'Commodity'), validator:(v)=>v!.isEmpty?'Required':null),
            TextFormField(controller:_weight, decoration: const InputDecoration(labelText:'Weight (kg)'), keyboardType: TextInputType.number),
            TextFormField(controller:_pickup, decoration: const InputDecoration(labelText:'Pickup Address')),
            TextFormField(controller:_dropoff, decoration: const InputDecoration(labelText:'Dropoff Address')),
            const SizedBox(height:16),
            ElevatedButton(onPressed: loading?null:_submit, child: loading?const CircularProgressIndicator():const Text('Create'))
          ]),
        ),
      ),
    );
  }
}
