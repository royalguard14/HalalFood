import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeveloperRestaurantControlScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  const DeveloperRestaurantControlScreen({super.key, required this.restaurantId, required this.restaurantName});
  @override State<DeveloperRestaurantControlScreen> createState() => _DeveloperRestaurantControlScreenState();
}

class _DeveloperRestaurantControlScreenState extends State<DeveloperRestaurantControlScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true, _saving = false;
  double _cashReceived = 0, _gcashReceived = 0, _gcashCashouts = 0, _cashAdjustments = 0, _gcashAdjustments = 0;
  List<Map<String,dynamic>> _adjustments = [];
  double get _cashBalance => _cashReceived + _cashAdjustments;
  double get _gcashBalance => _gcashReceived + _gcashAdjustments - _gcashCashouts;
  @override void initState(){super.initState();_load();}

  Future<void> _load() async {
    if(mounted)setState(()=>_loading=true);
    try {
      final orders=await _supabase.from('orders').select('id').eq('restaurant_id',widget.restaurantId);
      final ids=(orders).map((r)=>r['id']?.toString()).whereType<String>().toList();
      final payments=ids.isEmpty?[]:await _supabase.from('payments').select('amount,payment_method,status').eq('status','paid').inFilter('order_id',ids);
      final cashouts=await _supabase.from('owner_gcash_cashouts').select('amount').eq('restaurant_id',widget.restaurantId);
      final adjustments=await _supabase.from('developer_restaurant_vault_adjustments').select('id,vault_type,amount,notes,created_at').eq('restaurant_id',widget.restaurantId).order('created_at',ascending:false);
      double cash=0,gcash=0;
      for(final row in payments as List){final amount=(row['amount'] as num?)?.toDouble()??0; final method=row['payment_method']?.toString().toLowerCase(); if(method=='cash_on_delivery')cash+=amount; if(method=='gcash')gcash+=amount;}
      final out=(cashouts).fold<double>(0,(s,r)=>s+((r['amount'] as num?)?.toDouble()??0));
      double ca=0,ga=0;
      for(final row in adjustments as List){final amount=(row['amount'] as num?)?.toDouble()??0; if(row['vault_type']=='cash')ca+=amount; if(row['vault_type']=='gcash')ga+=amount;}
      if(!mounted)return;
      setState((){_cashReceived=cash;_gcashReceived=gcash;_gcashCashouts=out;_cashAdjustments=ca;_gcashAdjustments=ga;_adjustments=(adjustments).map((r)=>Map<String,dynamic>.from(r)).toList();_loading=false;});
    } catch(e){if(mounted){setState(()=>_loading=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Unable to load vault: $e')));}}
  }

  Future<void> _adjust(String vault) async {
    final amount=TextEditingController(); final notes=TextEditingController();
    final result=await showDialog<List<String>>(context:context,builder:(c)=>AlertDialog(title:Text((vault=='cash'?'Cash':'GCash')+' Vault Adjustment'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount',helperText:'Positive adds funds; negative subtracts funds.',prefixText:'₱ ')),const SizedBox(height:10),TextField(controller:notes,maxLines:2,decoration:const InputDecoration(labelText:'Reason / Notes'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,[amount.text.trim(),notes.text.trim()]),child:const Text('Save Adjustment'))]));
    amount.dispose();notes.dispose(); if(result==null||!mounted)return;
    final value=double.tryParse(result[0].replaceAll(',',''));
    if(value==null||value==0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a non-zero amount.')));return;}
    setState(()=>_saving=true);
    try{await _supabase.rpc('developer_record_vault_adjustment',params:{'p_restaurant_id':widget.restaurantId,'p_vault_type':vault,'p_amount':value,'p_notes':result[1].isEmpty?null:result[1]});await _load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor:Colors.red,content:Text('Adjustment failed: $e')));}
    finally{if(mounted)setState(()=>_saving=false);}
  }

  String _date(String? value){final d=DateTime.tryParse(value??'');if(d==null)return '—';return d.month.toString()+'/'+d.day.toString()+'/'+d.year.toString()+' '+d.hour.toString().padLeft(2,'0')+':'+d.minute.toString().padLeft(2,'0');}
  Widget _vault(String title,double balance,IconData icon,VoidCallback onAdjust){
    final cash=title=='Cash Vault';
    return Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon),const SizedBox(width:8),Expanded(child:Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)))]),const SizedBox(height:10),Text('₱'+balance.toStringAsFixed(2),style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text('Received: ₱'+(cash?_cashReceived:_gcashReceived).toStringAsFixed(2)),Text('Developer adjustments: ₱'+(cash?_cashAdjustments:_gcashAdjustments).toStringAsFixed(2)),if(!cash)Text('GCash cashouts: ₱'+_gcashCashouts.toStringAsFixed(2)),const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:_saving?null:onAdjust,icon:const Icon(Icons.tune_rounded),label:const Text('Manipulate Vault',style:TextStyle(fontWeight:FontWeight.w800))))])));
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.restaurantName,style:const TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(onPressed:_loading||_saving?null:_load,icon:const Icon(Icons.refresh_rounded))]),body:_loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.fromLTRB(18,18,18,32),physics:const AlwaysScrollableScrollPhysics(),children:[const Text('Restaurant Control',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:4),const Text('Developer-only financial control. Positive adjustments add funds; negative adjustments subtract funds.'),const SizedBox(height:16),_vault('Cash Vault',_cashBalance,Icons.payments_rounded,()=>_adjust('cash')),const SizedBox(height:12),_vault('GCash Vault',_gcashBalance,Icons.phone_android_rounded,()=>_adjust('gcash')),const SizedBox(height:22),const Text('Developer Adjustment History',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),const SizedBox(height:10),if(_adjustments.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('No developer adjustments recorded.'))) else ..._adjustments.map((r){final a=(r['amount'] as num?)?.toDouble()??0;return Card(child:ListTile(leading:Icon(r['vault_type']=='cash'?Icons.payments_rounded:Icons.phone_android_rounded),title:Text((r['vault_type']=='cash'?'Cash':'GCash')+'  '+(a>=0?'+':'−')+' ₱'+a.abs().toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text((r['notes']?.toString().isNotEmpty==true?r['notes'].toString()+'\\n':'')+_date(r['created_at']?.toString())));})])));
}