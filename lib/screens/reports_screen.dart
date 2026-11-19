import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_settings_action.dart';
import '../widgets/finance_ui.dart';
import '../widgets/ui_kit.dart';
import 'entry_form_screens.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime anchor = DateTime.now();
  String period = 'month';
  bool loaded = false;
  List<ExpenseRecord> expenses = [];
  List<PayrollPayment> payroll = [];
  List<IncomeRecord> income = [];
  List<Map<String, Object?>> creditBalanceRows = [];
  double collectedTotal = 0;
  double? monthlyLimit;
  List<CategoryBudget> categoryLimits = [];

  DateTime get start => period == 'day'
      ? DateTime(anchor.year, anchor.month, anchor.day)
      : period == 'year'
      ? DateTime(anchor.year, 1, 1)
      : DateTime(anchor.year, anchor.month, 1);
  DateTime get end => period == 'day'
      ? start.add(const Duration(days: 1))
      : period == 'year'
      ? DateTime(anchor.year + 1, 1, 1)
      : DateTime(anchor.year, anchor.month + 1, 1);

  @override
  void initState() {
    super.initState();
    DatabaseService.revision.addListener(load);
    load();
  }

  @override
  void dispose() {
    DatabaseService.revision.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final values = await Future.wait<Object?>([
      DatabaseService.instance.expenses(start: start, end: end),
      DatabaseService.instance.payroll(start: start, end: end),
      DatabaseService.instance.income(start: start, end: end),
      DatabaseService.instance.incomeCollected(start: start, end: end),
      DatabaseService.instance.creditBalances(),
      DatabaseService.instance.totalMonthlyBudget('${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}'),
      DatabaseService.instance.categoryBudgets('${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}'),
    ]);
    if (!mounted) return;
    setState(() {
      expenses = values[0] as List<ExpenseRecord>;
      payroll = values[1] as List<PayrollPayment>;
      income = values[2] as List<IncomeRecord>;
      collectedTotal = values[3] as double;
      creditBalanceRows = values[4] as List<Map<String, Object?>>;
      monthlyLimit = values[5] as double?;
      categoryLimits = values[6] as List<CategoryBudget>;
      loaded = true;
    });
  }

  double get expenseTotal => expenses.fold<double>(0, (s, e) => s + e.amount);
  double get payrollTotal => payroll.fold<double>(0, (s, e) => s + e.amount);
  double get incomeTotal => income.fold<double>(0, (s, e) => s + e.amount);
  double get outstandingSales => (incomeTotal - collectedTotal).clamp(0, double.infinity).toDouble();
  double get outstandingCredit => creditBalanceRows.fold<double>(0, (sum, row) => sum + ((row['balance'] as num?)?.toDouble() ?? 0).abs());
  double get costOfGoodsSold =>
      income.fold<double>(0, (s, e) => s + e.costAmount);
  double get grossProfit => incomeTotal - costOfGoodsSold;
  double get netProfit => grossProfit - expenseTotal - payrollTotal;
  String get label => period == 'day'
      ? DateFormat('dd MMM yyyy').format(anchor)
      : period == 'year'
      ? DateFormat('yyyy').format(anchor)
      : DateFormat('MMMM yyyy').format(anchor);

  void shiftPeriod(int direction) {
    setState(() {
      if (period == 'day') {
        anchor = anchor.add(Duration(days: direction));
      } else if (period == 'year') {
        anchor = DateTime(anchor.year + direction, anchor.month, 1);
      } else {
        anchor = DateTime(anchor.year, anchor.month + direction, 1);
      }
    });
    load();
  }

  Future<Uint8List> _pdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'Billit Finance Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(label),
          pw.SizedBox(height: 18),
          pw.Text('Income / sales: INR ${incomeTotal.toStringAsFixed(2)}'),
          pw.Text('Collected from customers: INR ${collectedTotal.toStringAsFixed(2)}'),
          pw.Text('Pending collection on period sales: INR ${outstandingSales.toStringAsFixed(2)}'),
          pw.Text('All-time outstanding credit ledger: INR ${outstandingCredit.toStringAsFixed(2)}'),
          pw.Text(
            'Cost of goods sold: INR ${costOfGoodsSold.toStringAsFixed(2)}',
          ),
          pw.Text('Gross profit: INR ${grossProfit.toStringAsFixed(2)}'),
          pw.Text('Expenses: INR ${expenseTotal.toStringAsFixed(2)}'),
          if (period == 'month' && monthlyLimit != null) pw.Text('Budget: INR ${monthlyLimit!.toStringAsFixed(2)} | Remaining: INR ${(monthlyLimit! - expenseTotal).toStringAsFixed(2)}'),
          pw.Text('Payroll: INR ${payrollTotal.toStringAsFixed(2)}'),
          pw.Text(
            'Total outflow: INR ${(expenseTotal + payrollTotal).toStringAsFixed(2)}',
          ),
          pw.Text('Net operating result: INR ${netProfit.toStringAsFixed(2)}'),
          pw.SizedBox(height: 18),
          pw.Text(
            'Income details',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Sales', 'COGS'],
            data: income
                .map(
                  (e) => [
                    DateFormat('dd MMM yyyy').format(e.date),
                    e.description,
                    e.amount.toStringAsFixed(2),
                    e.costAmount.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Expense details',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Category', 'Description', 'Amount'],
            data: expenses
                .map(
                  (e) => [
                    DateFormat('dd MMM yyyy').format(e.date),
                    e.category,
                    e.description,
                    e.amount.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Payroll details',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Note', 'Amount'],
            data: payroll
                .map(
                  (e) => [
                    DateFormat('dd MMM yyyy').format(e.date),
                    e.type,
                    e.note,
                    e.amount.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  Future<void> _download() async {
    final bytes = await _pdf();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save finance report',
      fileName: 'billit_finance_${label.replaceAll(' ', '_')}.pdf',
      bytes: bytes,
    );
    if (mounted && path != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Report saved.')));
  }

  String _csvCell(Object? v) =>
      '"${(v ?? '').toString().replaceAll('"', '""')}"';
  Uint8List _csv() {
    final rows = <String>[
      [
        'Record type',
        'Date',
        'Category / type',
        'Description / note',
        'Amount',
      ].map(_csvCell).join(','),
      ...income.map(
        (e) => [
          'Income',
          DateFormat('yyyy-MM-dd').format(e.date),
          e.source,
          '${e.description} | COGS ${e.costAmount.toStringAsFixed(2)}',
          e.amount.toStringAsFixed(2),
        ].map(_csvCell).join(','),
      ),
      ...expenses.map(
        (e) => [
          'Expense',
          DateFormat('yyyy-MM-dd').format(e.date),
          e.category,
          e.description,
          e.amount.toStringAsFixed(2),
        ].map(_csvCell).join(','),
      ),
      ...payroll.map(
        (e) => [
          'Payroll',
          DateFormat('yyyy-MM-dd').format(e.date),
          e.type,
          e.note,
          e.amount.toStringAsFixed(2),
        ].map(_csvCell).join(','),
      ),
      ['', '', '', 'Collected from customers', collectedTotal.toStringAsFixed(2)].map(_csvCell).join(','),
      ['', '', '', 'Pending collection', outstandingSales.toStringAsFixed(2)].map(_csvCell).join(','),
      ['', '', '', 'All-time outstanding credit ledger', outstandingCredit.toStringAsFixed(2)].map(_csvCell).join(','),
      if (period == 'month' && monthlyLimit != null) ['', '', '', 'Monthly budget', monthlyLimit!.toStringAsFixed(2)].map(_csvCell).join(','),
      if (period == 'month' && monthlyLimit != null) ['', '', '', 'Budget remaining', (monthlyLimit! - expenseTotal).toStringAsFixed(2)].map(_csvCell).join(','),
      [
        '',
        '',
        '',
        'Total income',
        incomeTotal.toStringAsFixed(2),
      ].map(_csvCell).join(','),
      [
        '',
        '',
        '',
        'Total outflow',
        (expenseTotal + payrollTotal).toStringAsFixed(2),
      ].map(_csvCell).join(','),
      [
        '',
        '',
        '',
        'Net operating result',
        netProfit.toStringAsFixed(2),
      ].map(_csvCell).join(','),
    ];
    return Uint8List.fromList(utf8.encode('\uFEFF${rows.join('\r\n')}'));
  }

  Future<void> _downloadCsv() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save finance report CSV',
      fileName: 'billit_finance_${label.replaceAll(' ', '_')}.csv',
      bytes: _csv(),
    );
    if (mounted && path != null)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('CSV report saved.')));
  }

  Future<void> _shareCsv() async {
    await Share.shareXFiles([
      XFile.fromData(
        _csv(),
        mimeType: 'text/csv',
        name: 'billit_finance_report.csv',
      ),
    ], subject: 'Billit Finance CSV - $label');
  }

  Future<void> _share() async {
    final bytes = await _pdf();
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: 'billit_finance_report.pdf',
      ),
    ], subject: 'Billit Finance Report - $label');
  }

  List<MapEntry<String, double>> get topCategories {
    final totals = <String, double>{};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  void _onExport(String value) {
    switch (value) {
      case 'pdf-save':
        _download();
      case 'pdf-share':
        _share();
      case 'csv-save':
        _downloadCsv();
      case 'csv-share':
        _shareCsv();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = topCategories;
    final topValue = categories.isEmpty ? 0.0 : categories.first.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [

          const AdminSettingsAction(),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, viewport) {
                final width = viewport.maxWidth;
                final pad = width < 600 ? 16.0 : 24.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: context.softFill, borderRadius: BorderRadius.circular(14)),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(onPressed: _download, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Download PDF')),
                            OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share_outlined), label: const Text('Share PDF')),
                            OutlinedButton.icon(onPressed: _downloadCsv, icon: const Icon(Icons.table_view_outlined), label: const Text('Download CSV')),
                            OutlinedButton.icon(onPressed: _shareCsv, icon: const Icon(Icons.share_outlined), label: const Text('Share CSV')),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 'day', label: Text('Day')),
                            ButtonSegment(value: 'month', label: Text('Month')),
                            ButtonSegment(value: 'year', label: Text('Year')),
                          ],
                          selected: {period},
                          onSelectionChanged: (value) {
                            setState(() => period = value.first);
                            load();
                          },
                        ),
                        const SizedBox(height: 10),
                        PeriodSwitcher(
                          label: label,
                          onPrevious: () => shiftPeriod(-1),
                          onNext: () => shiftPeriod(1),
                        ),
                        const SizedBox(height: 6),
                        const SectionHeader('Cash collection'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              FinanceUiRow(label: 'Sales recorded', value: incomeTotal),
                              FinanceUiRow(label: 'Collected', value: collectedTotal),
                              FinanceUiRow(label: 'Pending collection', value: outstandingSales, emphasize: true),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: incomeTotal <= 0 ? 0 : (collectedTotal / incomeTotal).clamp(0, 1),
                                  backgroundColor: context.hairline,
                                  color: context.good,
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const SectionHeader('All-time outstanding credit ledger'),
                        Card(
                          child: creditBalanceRows.isEmpty
                              ? const EmptyState(title: 'No credit parties recorded', icon: Icons.account_balance_wallet_outlined)
                              : Column(children: [
                                  for (final row in creditBalanceRows)
                                    ListTile(
                                      title: Text((row['name'] ?? 'Party').toString()),
                                      subtitle: Text((row['type'] ?? '').toString()),
                                      trailing: MaskedText(
                                        FinanceCalculator.money(((row['balance'] as num?)?.toDouble() ?? 0).abs()),
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                ]),
                        ),
                        const SectionHeader('Where sales go'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: BreakdownBar(
                              segments: [
                                BarSegment(
                                  'Cost of goods',
                                  costOfGoodsSold,
                                  AppColors.brown,
                                ),
                                BarSegment(
                                  'Expenses',
                                  expenseTotal,
                                  AppColors.warning,
                                ),
                                BarSegment(
                                  'Payroll',
                                  payrollTotal,
                                  AppColors.indigo,
                                ),
                                BarSegment(
                                  'Profit',
                                  netProfit > 0 ? netProfit : 0,
                                  context.good,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (categories.isNotEmpty) ...[
                          const SectionHeader('Top expenses'),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  for (final c in categories)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                categoryIcon(c.key),
                                                size: 18,
                                                color: context.muted,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  c.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              MaskedText(
                                                FinanceCalculator.money(
                                                  c.value,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                            value: topValue == 0
                                                ? 0
                                                : c.value / topValue,
                                            minHeight: 6,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            color: AppColors.warning,
                                            backgroundColor: context.hairline,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
