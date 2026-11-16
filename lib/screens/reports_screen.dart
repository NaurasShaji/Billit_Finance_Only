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
  DateTime get start => period == 'day'
      ? DateTime(anchor.year, anchor.month, anchor.day)
      : period == 'year' ? DateTime(anchor.year, 1, 1) : DateTime(anchor.year, anchor.month, 1);
  DateTime get end => period == 'day'
      ? start.add(const Duration(days: 1))
      : period == 'year' ? DateTime(anchor.year + 1, 1, 1) : DateTime(anchor.year, anchor.month + 1, 1);
  Future<void> load() async {
    setState(() => loading = true);
    final values = await Future.wait([
      DatabaseService.instance.expenses(start: start, end: end),
      DatabaseService.instance.payroll(start: start, end: end),
    ]);
    if (!mounted) return;
    setState(() { expenses = values[0] as List<ExpenseRecord>; payroll = values[1] as List<PayrollPayment>; loading = false; });
  }
  @override
  void initState() { super.initState(); load(); }
  double get expenseTotal => expenses.fold(0, (s, e) => s + e.amount);
  double get payrollTotal => payroll.fold(0, (s, e) => s + e.amount);
  String get label => period == 'day'
      ? DateFormat('dd MMM yyyy').format(anchor)
      : period == 'year' ? DateFormat('yyyy').format(anchor) : DateFormat('MMMM yyyy').format(anchor);
  void shiftPeriod(int direction) {
    setState(() {
      if (period == 'day') anchor = anchor.add(Duration(days: direction));
      else if (period == 'year') anchor = DateTime(anchor.year + direction, anchor.month, anchor.day);
      else anchor = DateTime(anchor.year, anchor.month + direction, anchor.day);
    });
    load();
  }
  String money(double v) => NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(v);

  Future<Uint8List> _pdf() async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => [
      pw.Text('Billit Finance Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text(label), pw.SizedBox(height: 18),
      pw.Text('Expenses: INR ${expenseTotal.toStringAsFixed(2)}'),
      pw.Text('Payroll: INR ${payrollTotal.toStringAsFixed(2)}'),
      pw.Text('Total outflow: INR ${(expenseTotal + payrollTotal).toStringAsFixed(2)}'),
      pw.SizedBox(height: 18),
      pw.Text('Expense details', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      pw.TableHelper.fromTextArray(headers: ['Date','Category','Description','Amount'], data: expenses.map((e) => [DateFormat('dd MMM yyyy').format(e.date), e.category, e.description, e.amount.toStringAsFixed(2)]).toList()),
      pw.SizedBox(height: 18),
      pw.Text('Payroll details', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      pw.TableHelper.fromTextArray(headers: ['Date','Type','Note','Amount'], data: payroll.map((e) => [DateFormat('dd MMM yyyy').format(e.date), e.type, e.note, e.amount.toStringAsFixed(2)]).toList()),
    ]));
    return Uint8List.fromList(await doc.save());
  }
  Future<void> _download() async {
    final bytes = await _pdf();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save finance report',
      fileName: 'billit_finance_${anchor.year}_${anchor.month.toString().padLeft(2, '0')}.pdf',
      bytes: bytes,
    );
    if (mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report saved.')));
  }
  String _csvCell(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';
  Uint8List _csv() {
    final rows = <String>[
      ['Record type', 'Date', 'Category / type', 'Description / note', 'Amount'].map(_csvCell).join(','),
      ...expenses.map((e) => ['Expense', DateFormat('yyyy-MM-dd').format(e.date), e.category, e.description, e.amount.toStringAsFixed(2)].map(_csvCell).join(',')),
      ...payroll.map((e) => ['Payroll', DateFormat('yyyy-MM-dd').format(e.date), e.type, e.note, e.amount.toStringAsFixed(2)].map(_csvCell).join(',')),
      ['', '', '', 'Total outflow', (expenseTotal + payrollTotal).toStringAsFixed(2)].map(_csvCell).join(','),
    ];
    return Uint8List.fromList(utf8.encode('\uFEFF${rows.join('\r\n')}'));
  }
  Future<void> _downloadCsv() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save finance report CSV',
      fileName: 'billit_finance_${anchor.year}_${anchor.month.toString().padLeft(2, '0')}.csv',
      bytes: _csv(),
    );
    if (mounted && path != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV report saved.')));
  }
  Future<void> _shareCsv() async {
    await Share.shareXFiles([XFile.fromData(_csv(), mimeType: 'text/csv', name: 'billit_finance_report.csv')], subject: 'Billit Finance CSV - $label');
  }
  Future<void> _share() async {
    final bytes = await _pdf();
    await Share.shareXFiles([XFile.fromData(bytes, mimeType: 'application/pdf', name: 'billit_finance_report.pdf')], subject: 'Billit Finance Report - $label');
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Finance Reports')),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'day', label: Text('Daily')),
          ButtonSegment(value: 'month', label: Text('Monthly')),
          ButtonSegment(value: 'year', label: Text('Yearly')),
        ],
        selected: {period},
        onSelectionChanged: (value) { setState(() => period = value.first); load(); },
      ),
      const SizedBox(height: 10),
      Card(child: Row(children: [
        IconButton(onPressed: () => shiftPeriod(-1), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(onPressed: () => shiftPeriod(1), icon: const Icon(Icons.chevron_right)),
      ])),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _line('Expenses', expenseTotal), _line('Payroll', payrollTotal), const Divider(), _line('Total outflow', expenseTotal + payrollTotal, bold: true),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 10, runSpacing: 10, children: [
        FilledButton.icon(onPressed: _download, icon: const Icon(Icons.download), label: const Text('Download PDF')),
        OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('Share PDF')),
        OutlinedButton.icon(onPressed: _downloadCsv, icon: const Icon(Icons.table_view), label: const Text('Download CSV')),
        OutlinedButton.icon(onPressed: _shareCsv, icon: const Icon(Icons.share_outlined), label: const Text('Share CSV')),
      ]))),
      const Text('Expense and payroll details are included in the exported report.'),
    ]),
  );
  Widget _line(String title, double value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))), Text(money(value), style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))]),
  );
}
