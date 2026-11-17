import 'package:flutter/material.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';

class FinanceUi {
  static Widget amountField(TextEditingController controller, {String label='Amount (₹)'}) => TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,prefixIcon:const Icon(Icons.currency_rupee)));
  static Future<bool> confirm(BuildContext context,String title) => showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(title:Text(title),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('Confirm'))])).then((v)=>v??false);
  static Widget row(String name,double value,{bool bold=false}) => Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Expanded(child:Text(name,style:TextStyle(fontWeight:bold?FontWeight.w800:FontWeight.w500))),Text(FinanceCalculator.money(value),style:TextStyle(fontWeight:bold?FontWeight.w800:FontWeight.w600))]));
  static Widget empty(String message) => EmptyMessage(message:message);
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({super.key,required this.message});
  final String message;
  @override
  Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(28),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.inbox_outlined,size:36,color:AppColors.muted),const SizedBox(height:8),Text(message,style:const TextStyle(color:AppColors.muted))])));
}
