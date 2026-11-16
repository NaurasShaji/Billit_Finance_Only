import 'package:flutter/material.dart';
import '../services/finance_calculator.dart';
class FinanceUi {
 static Widget amountField(TextEditingController c,{String label='Amount (₹)'})=>TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:label,prefixIcon:const Icon(Icons.currency_rupee)));
 static Future<bool> confirm(BuildContext context,String title)=>showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:Text(title),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Save'))])).then((v)=>v??false);
 static Widget row(String name,double value,{bool bold=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Expanded(child:Text(name,style:TextStyle(fontWeight:bold?FontWeight.w800:FontWeight.w500))),Text(FinanceCalculator.money(value),style:TextStyle(fontWeight:bold?FontWeight.w800:FontWeight.w600))]));
 static Widget empty(String message)=>Padding(padding:const EdgeInsets.all(28),child:Center(child:Text(message,style:const TextStyle(color:Colors.blueGrey))));
}
