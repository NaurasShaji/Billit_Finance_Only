import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}
class _ReportsScreenState extends State<ReportsScreen> {
  DateTime anchor = DateTime.now();
  String period = 'month';
  bool loading = false;
  List<ExpenseRecord> expenses = [];
  List<PayrollPayment> payroll = [];
  List<IncomeRecord> income = [];
  DateTime get start => period == 'day' ? DateTime(anchor.year, anchor.month, anchor.day) : period == 'year' ? DateTime(anchor.year, 1, 1) : DateTime(anchor.year, anchor.month, 1);
  DateTime get end => period == 'day' ? start.add(const Duration(days: 1)) : period == 'year' ? DateTime(anchor.year + 1, 1, 1) : DateTime(anchor.year, anchor.month + 1, 1);
  Future<void> load() async {
    setState(() => loading = true);
    final values = await Future.wait([DatabaseService.instance.expenses(start: start, end: end), DatabaseService.instance.payroll(start: start, end: end), DatabaseService.instance.income(start: start, end: end)]);
    if (!mounted) return;
    setState(() { expenses = values[0] as List<ExpenseRecord>; payroll = values[1] as List<PayrollPayment>; income = values[2] as List<IncomeRecord>; loading = false; });
  }
  @override
  void initState() { super.initState(); load(); }
  double get expenseTotal => expenses.fold(0, (s,e) => s+e.amount);
  double get payrollTotal => payroll.fold(0, (s,e) => s+e.amount);
  double get incomeTotal => income.fold(0, (s,e) => s+e.amount);
  double get costOfGoodsSold => income.fold(0, (s,e) => s+e.costAmount);
  double get grossProfit => incomeTotal-costOfGoodsSold;
  double get netProfit => grossProfit-expenseTotal-payrollTotal;
  String get label => period == 'day' ? DateFormat('dd MMM yyyy').format(anchor) : period == 'year' ? DateFormat('yyyy').format(anchor) : DateFormat('MMMM yyyy').format(anchor);
  void shiftPeriod(int direction) { setState(() { if(period=='day') anchor=anchor.add(Duration(days:direction)); else if(period=='year') anchor=DateTime(anchor.year+direction,anchor.month,1); else anchor=DateTime(anchor.year,anchor.month+direction,1); }); load(); }
  String money(double v) => NumberFormat.currency(locale:'en_IN',symbol:'₹').format(v);
  Future<Uint8List> _pdf() async {
    final doc=pw.Document();
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,build:(_)=>[
      pw.Text('Billit Finance Report',style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold)),pw.Text(label),pw.SizedBox(height:18),
      pw.Text('Income / sales: INR ${incomeTotal.toStringAsFixed(2)}'),pw.Text('Cost of goods sold: INR ${costOfGoodsSold.toStringAsFixed(2)}'),pw.Text('Gross profit: INR ${grossProfit.toStringAsFixed(2)}'),pw.Text('Expenses: INR ${expenseTotal.toStringAsFixed(2)}'),pw.Text('Payroll: INR ${payrollTotal.toStringAsFixed(2)}'),pw.Text('Total outflow: INR ${(expenseTotal+payrollTotal).toStringAsFixed(2)}'),pw.Text('Net operating result: INR ${netProfit.toStringAsFixed(2)}'),pw.SizedBox(height:18),
      pw.Text('Income details',style:pw.TextStyle(fontSize:15,fontWeight:pw.FontWeight.bold)),pw.TableHelper.fromTextArray(headers:['Date','Description','Sales','COGS'],data:income.map((e)=>[DateFormat('dd MMM yyyy').format(e.date),e.description,e.amount.toStringAsFixed(2),e.costAmount.toStringAsFixed(2)]).toList()),pw.SizedBox(height:18),
      pw.Text('Expense details',style:pw.TextStyle(fontSize:15,fontWeight:pw.FontWeight.bold)),pw.TableHelper.fromTextArray(headers:['Date','Category','Description','Amount'],data:expenses.map((e)=>[DateFormat('dd MMM yyyy').format(e.date),e.category,e.description,e.amount.toStringAsFixed(2)]).toList()),pw.SizedBox(height:18),
      pw.Text('Payroll details',style:pw.TextStyle(fontSize:15,fontWeight:pw.FontWeight.bold)),pw.TableHelper.fromTextArray(headers:['Date','Type','Note','Amount'],data:payroll.map((e)=>[DateFormat('dd MMM yyyy').format(e.date),e.type,e.note,e.amount.toStringAsFixed(2)]).toList()),
    ]));
    return Uint8List.fromList(await doc.save());
  }
  Future<void> _download() async { final bytes=await _pdf(); final path=await FilePicker.platform.saveFile(dialogTitle:'Save finance report',fileName:'billit_finance_${label.replaceAll(' ','_')}.pdf',bytes:bytes); if(mounted&&path!=null)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Report saved.'))); }
  String _csvCell(Object? v)=>'"${(v??'').toString().replaceAll('"','""')}"';
  Uint8List _csv(){final rows=<String>[
    ['Record type','Date','Category / type','Description / note','Amount'].map(_csvCell).join(','),
    ...income.map((e)=>['Income',DateFormat('yyyy-MM-dd').format(e.date),e.source,'${e.description} | COGS ${e.costAmount.toStringAsFixed(2)}',e.amount.toStringAsFixed(2)].map(_csvCell).join(',')),
    ...expenses.map((e)=>['Expense',DateFormat('yyyy-MM-dd').format(e.date),e.category,e.description,e.amount.toStringAsFixed(2)].map(_csvCell).join(',')),
    ...payroll.map((e)=>['Payroll',DateFormat('yyyy-MM-dd').format(e.date),e.type,e.note,e.amount.toStringAsFixed(2)].map(_csvCell).join(',')),
    ['','','','Total income',incomeTotal.toStringAsFixed(2)].map(_csvCell).join(','),['','','','Total outflow',(expenseTotal+payrollTotal).toStringAsFixed(2)].map(_csvCell).join(','),['','','','Net operating result',netProfit.toStringAsFixed(2)].map(_csvCell).join(','),
  ];return Uint8List.fromList(utf8.encode('\uFEFF${rows.join('\r\n')}'));}
  Future<void> _downloadCsv() async {final path=await FilePicker.platform.saveFile(dialogTitle:'Save finance report CSV',fileName:'billit_finance_${label.replaceAll(' ','_')}.csv',bytes:_csv());if(mounted&&path!=null)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('CSV report saved.')));}
  Future<void> _shareCsv() async {await Share.shareXFiles([XFile.fromData(_csv(),mimeType:'text/csv',name:'billit_finance_report.csv')],subject:'Billit Finance CSV - $label');}
  Future<void> _share() async {final bytes=await _pdf();await Share.shareXFiles([XFile.fromData(bytes,mimeType:'application/pdf',name:'billit_finance_report.pdf')],subject:'Billit Finance Report - $label');}
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Finance Reports')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(builder: (context, viewport) {
            final width = viewport.maxWidth;
            final horizontalPadding = width < 600 ? 14.0 : width < 1000 ? 22.0 : 30.0;
            final columns = width >= 1050 ? 3 : width >= 620 ? 2 : 1;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 28),
                  children: [
                    const Text('Performance summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    const Text('Review income, operating costs and payroll for the selected period.', style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 18),
                    SegmentedButton<String>(
                      expandedInsets: EdgeInsets.zero,
                      segments: const [
                        ButtonSegment(value: 'day', label: Text('Daily'), icon: Icon(Icons.today_outlined)),
                        ButtonSegment(value: 'month', label: Text('Monthly'), icon: Icon(Icons.calendar_month_outlined)),
                        ButtonSegment(value: 'year', label: Text('Yearly'), icon: Icon(Icons.date_range_outlined)),
                      ],
                      selected: {period},
                      onSelectionChanged: (value) { setState(() => period = value.first); load(); },
                    ),
                    const SizedBox(height: 10),
                    PeriodSwitcher(label: label, onPrevious: () => shiftPeriod(-1), onNext: () => shiftPeriod(1)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        SizedBox(width: (width - horizontalPadding * 2 - (columns - 1) * 12).clamp(0, 1180) / columns, child: StatCard(title: 'Income / sales', value: money(incomeTotal), icon: Icons.trending_up, color: AppColors.positive)),
                        SizedBox(width: (width - horizontalPadding * 2 - (columns - 1) * 12).clamp(0, 1180) / columns, child: StatCard(title: 'Cost of goods sold', value: money(costOfGoodsSold), icon: Icons.inventory_2_outlined, color: Colors.brown)),
                        SizedBox(width: (width - horizontalPadding * 2 - (columns - 1) * 12).clamp(0, 1180) / columns, child: StatCard(title: 'Gross profit', value: money(grossProfit), icon: Icons.show_chart, color: grossProfit >= 0 ? AppColors.positive : AppColors.negative)),
                        SizedBox(width: (width - horizontalPadding * 2 - (columns - 1) * 12).clamp(0, 1180) / columns, child: StatCard(title: 'Expenses', value: money(expenseTotal), icon: Icons.receipt_long, color: AppColors.warning)),
                        SizedBox(width: (width - horizontalPadding * 2 - (columns - 1) * 12).clamp(0, 1180) / columns, child: StatCard(title: 'Payroll', value: money(payrollTotal), icon: Icons.groups, color: Colors.indigo)),
                        SizedBox(width: (width - horizontalPadding * 2 - (columns - 1) * 12).clamp(0, 1180) / columns, child: StatCard(title: 'Net operating result', value: money(netProfit), icon: Icons.account_balance, color: netProfit >= 0 ? AppColors.positive : AppColors.negative)),
                      ],
                    ),
                    const SectionHeader('Export report'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(builder: (context, actionsBox) {
                          final actionWidth = actionsBox.maxWidth < 460 ? actionsBox.maxWidth : (actionsBox.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(width: actionWidth, child: FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download), label: const Text('Download PDF'))),
                              SizedBox(width: actionWidth, child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Share PDF'))),
                              SizedBox(width: actionWidth, child: OutlinedButton.icon(onPressed: _downloadCsv, icon: const Icon(Icons.table_view), label: const Text('Download CSV'))),
                              SizedBox(width: actionWidth, child: OutlinedButton.icon(onPressed: _shareCsv, icon: const Icon(Icons.share_outlined), label: const Text('Share CSV'))),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Net operating result is sales less recorded COGS, expenses and payroll; it is not a tax or statutory profit calculation.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            );
          }),

}
