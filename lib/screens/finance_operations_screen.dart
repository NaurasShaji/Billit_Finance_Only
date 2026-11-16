import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';

class FinanceOperationsScreen extends StatelessWidget {
  const FinanceOperationsScreen({super.key});
  @override Widget build(BuildContext context)=>DefaultTabController(length:3,child:Scaffold(
    appBar:AppBar(title:const Text('Income & Accounts'),bottom:const TabBar(isScrollable:true,tabs:[Tab(text:'Income'),Tab(text:'Credit ledger'),Tab(text:'Cash book')])),
    body:const TabBarView(children:[_IncomeTab(),_CreditTab(),_CashTab()]),
  ));
}
class _IncomeTab extends StatefulWidget { const _IncomeTab(); @override State<_IncomeTab> createState()=>_IncomeTabState(); }
class _IncomeTabState extends State<_IncomeTab>{
  List<IncomeRecord> rows=[]; double total=0,received=0; bool busy=true;
  @override void initState(){super.initState();load();}
  Future<void> load() async {final n=DateTime.now(),s=DateTime(n.year,n.month,1),e=DateTime(n.year,n.month+1,1);final r=await DatabaseService.instance.income(start:s,end:e);final p=await DatabaseService.instance.incomeCollected(start:s,end:e);if(mounted)setState(()=>{rows=r,total=r.fold(0,(v,x)=>v+x.amount),received=p,busy=false});}
  Future<void> add() async {
    final amount=TextEditingController(),cost=TextEditingController(text:'0'),paid=TextEditingController(text:'0'),desc=TextEditingController();String method='cash';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,u)=>AlertDialog(title:const Text('Add sale / income'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Sale total (₹)')),
      TextField(controller:cost,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cost of goods sold (₹)',helperText:'Optional; required for meaningful profit')),\n      TextField(controller:paid,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Collected now (₹)',helperText:'Remaining amount stays outstanding')),
      DropdownButtonFormField<String>(value:method,items:const ['cash','upi','card','bank','other'].map((x)=>DropdownMenuItem(value:x,child:Text(x.toUpperCase()))).toList(),onChanged:(v)=>u(()=>method=v??'cash')),
      TextField(controller:desc,decoration:const InputDecoration(labelText:'Description / bill reference')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))])));
    final a=double.tryParse(amount.text),cogs=double.tryParse(cost.text),p=double.tryParse(paid.text);
    if(ok==true&&a!=null&&a>0&&cogs!=null&&cogs>=0&&p!=null&&p>=0&&p<=a){try{await DatabaseService.instance.addIncome(IncomeRecord(date:DateTime.now(),amount:a,costAmount:cogs,description:desc.text.trim()),payments:p>0?[IncomePayment(incomeId:0,date:DateTime.now(),method:method,amount:p)]:[]);await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}}
    else if(ok==true&&mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter valid amounts.')));}
    amount.dispose();cost.dispose();paid.dispose();desc.dispose();
  }
  @override Widget build(BuildContext context)=>busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
    _metric('Sales this month',total),_metric('Collected',received),_metric('Outstanding',total-received),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add income')),
    if(rows.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('No income entries this month.')),
    ...rows.map((x)=>ListTile(title:Text(x.description.isEmpty?'Sale':x.description),subtitle:Text(DateFormat('dd MMM yyyy').format(x.date)),trailing:Text(FinanceCalculator.money(x.amount))))
  ]));
}
class _CreditTab extends StatefulWidget { const _CreditTab(); @override State<_CreditTab> createState()=>_CreditTabState(); }
class _CreditTabState extends State<_CreditTab>{
  List<Map<String,Object?>> rows=[];bool busy=true;
  @override void initState(){super.initState();load();}
  Future<void> load()async{final x=await DatabaseService.instance.creditBalances();if(mounted)setState(()=>{rows=x,busy=false});}
  Future<void> addParty()async{final n=TextEditingController(),p=TextEditingController();String type='customer';final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,u)=>AlertDialog(title:const Text('Add customer / supplier'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:n,decoration:const InputDecoration(labelText:'Name')),TextField(controller:p,decoration:const InputDecoration(labelText:'Phone')),DropdownButtonFormField<String>(value:type,items:const [DropdownMenuItem(value:'customer',child:Text('Customer')),DropdownMenuItem(value:'supplier',child:Text('Supplier'))],onChanged:(v)=>u(()=>type=v??'customer'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))])));if(ok==true&&n.text.trim().isNotEmpty){await DatabaseService.instance.addCreditParty(CreditParty(name:n.text.trim(),phone:p.text.trim(),type:type));await load();}n.dispose();p.dispose();}
  Future<void> addEntry(CreditParty party)async{final a=TextEditingController(),note=TextEditingController();final isCustomer=party.type=='customer';String type=isCustomer?'credit_sale':'credit_purchase';final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,u)=>AlertDialog(title:Text('Record with '+party.name),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:type,items:(isCustomer?['credit_sale','payment_received','adjustment']:['credit_purchase','payment_made','adjustment']).map((v)=>DropdownMenuItem(value:v,child:Text(v.replaceAll('_',' ')))).toList(),onChanged:(v)=>u(()=>type=v??type)),TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount (₹)')),TextField(controller:note,decoration:const InputDecoration(labelText:'Note'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))])));final value=double.tryParse(a.text);if(ok==true&&value!=null&&value>0){await DatabaseService.instance.addCreditTransaction(CreditTransaction(partyId:party.id!,date:DateTime.now(),type:type,amount:value,note:note.text.trim()));await load();}a.dispose();note.dispose();}
  @override Widget build(BuildContext context)=>busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[FilledButton.icon(onPressed:addParty,icon:const Icon(Icons.person_add),label:const Text('Add party')),if(rows.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('No credit parties yet.')), ...rows.map((r){final p=CreditParty.fromMap(r);final b=(r['balance'] as num).toDouble();return Card(child:ListTile(title:Text(p.name),subtitle:Text(p.type=='customer'?'Customer receivable':'Supplier payable'),trailing:Text(FinanceCalculator.money(b.abs()),style:const TextStyle(fontWeight:FontWeight.bold)),onTap:()=>addEntry(p)));})]));
}
class _CashTab extends StatefulWidget { const _CashTab(); @override State<_CashTab> createState()=>_CashTabState(); }
class _CashTabState extends State<_CashTab>{
  CashSession? session;List<CashTransaction> rows=[];Map<String,double> net={};bool busy=true;
  @override void initState(){super.initState();load();}
  Future<void> load()async{final s=await DatabaseService.instance.cashSession(DateTime.now());if(s==null){if(mounted)setState(()=>{session=null,rows=[],net={},busy=false});return;}final r=await DatabaseService.instance.cashTransactions(s.id!);final b=await DatabaseService.instance.cashBalances(s.id!);if(mounted)setState(()=>{session=s,rows=r,net=b,busy=false});}
  Future<void> open()async{final c=TextEditingController(text:'0');final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('Opening cash'),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Opening cash (₹)')),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,true),child:const Text('Open day'))]));final v=double.tryParse(c.text);if(ok==true&&v!=null&&v>=0){await DatabaseService.instance.openCashSession(DateTime.now(),v);await load();}c.dispose();}
  Future<void> movement()async{final a=TextEditingController(),n=TextEditingController();String d='in',m='cash';final ok=await showDialog<bool>(context:context,builder:(x)=>StatefulBuilder(builder:(x,u)=>AlertDialog(title:const Text('Cash book movement'),content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:d,items:const [DropdownMenuItem(value:'in',child:Text('Money in')),DropdownMenuItem(value:'out',child:Text('Money out'))],onChanged:(v)=>u(()=>d=v??'in')),DropdownButtonFormField<String>(value:m,items:const ['cash','upi','card','bank'].map((v)=>DropdownMenuItem(value:v,child:Text(v.toUpperCase()))).toList(),onChanged:(v)=>u(()=>m=v??'cash')),TextField(controller:a,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Amount (₹)')),TextField(controller:n,decoration:const InputDecoration(labelText:'Description'))]),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,true),child:const Text('Save'))])));final v=double.tryParse(a.text);if(ok==true&&v!=null&&v>0){await DatabaseService.instance.addCashTransaction(CashTransaction(sessionId:session!.id!,date:DateTime.now(),direction:d,method:m,amount:v,note:n.text.trim()));await load();}a.dispose();n.dispose();}
  Future<void> close()async{final expected=session!.openingBalance+(net['cash']??0);final c=TextEditingController(text:expected.toStringAsFixed(2));final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('Close day'),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Physical cash counted (₹)')),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,true),child:const Text('Close'))]));final v=double.tryParse(c.text);if(ok==true&&v!=null&&v>=0){await DatabaseService.instance.closeCashSession(session!.id!,v);await load();}c.dispose();}
  @override Widget build(BuildContext context)=>busy?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(16),children:[
    if(session==null)FilledButton.icon(onPressed:open,icon:const Icon(Icons.lock_open),label:const Text('Open today’s cash book'))
    else ...[
      _metric('Opening cash',session!.openingBalance),
      ...['cash','upi','card','bank'].map((m)=>_metric(m.toUpperCase()+' net movement',net[m]??0)),
      _metric('Expected cash in drawer',session!.openingBalance+(net['cash']??0)),
      if(session!.status=='open')Wrap(spacing:8,children:[FilledButton.icon(onPressed:movement,icon:const Icon(Icons.add),label:const Text('Add movement')),OutlinedButton.icon(onPressed:close,icon:const Icon(Icons.lock),label:const Text('Close day'))]),
      if(session!.status=='closed')_metric('Counted closing cash',session!.closingBalance??0),
      ...rows.map((r)=>ListTile(title:Text(r.note.isEmpty?r.method.toUpperCase():r.note),subtitle:Text(r.direction.toUpperCase()+' • '+r.method.toUpperCase()),trailing:Text(FinanceCalculator.money(r.amount))))
    ]
  ]));
}
Widget _metric(String label,double value)=>Card(child:ListTile(title:Text(label),trailing:Text(FinanceCalculator.money(value),style:const TextStyle(fontWeight:FontWeight.bold))));
