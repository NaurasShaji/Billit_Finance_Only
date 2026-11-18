import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_settings_action.dart';
import '../widgets/finance_ui.dart';
import '../widgets/ui_kit.dart';
import 'entry_form_screens.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<EmployeeRecord> employees = [];
  List<PayrollPayment> payments = [];
  bool loading = true;

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
    final employeeRows = await DatabaseService.instance.employees();
    final paymentRows = await DatabaseService.instance.payroll();
    if (!mounted) return;
    setState(() {
      employees = employeeRows;
      payments = paymentRows;
      loading = false;
    });
  }

  Future<void> addEmployee([EmployeeRecord? existing]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EmployeeEntryPage(existing: existing)),
    );
    await load();
  }

  Future<void> removeEmployee(EmployeeRecord employee) async {
    final confirmed = await FinanceUi.confirm(
      context,
      'Remove ${employee.name}?',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await DatabaseService.instance.archiveEmployee(employee.id!);
    await load();
  }

  String _periodFor(EmployeeRecord employee, DateTime now) =>
      employee.type == 'daily'
      ? DateFormat('yyyy-MM-dd').format(now)
      : DateFormat('yyyy-MM').format(now);

  bool _isPaid(EmployeeRecord employee) {
    final period = _periodFor(employee, DateTime.now());
    return payments.any(
      (p) => p.employeeId == employee.id && p.period == period,
    );
  }

  Future<void> pay(EmployeeRecord employee) async {
    final now = DateTime.now();
    final period = _periodFor(employee, now);
    if (_isPaid(employee)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already paid for this period')),
      );
      return;
    }
    final amount = await showAmountDialog(
      context,
      title: 'Pay ${employee.name}',
      initial: employee.wage,
      confirmLabel: 'Pay',
    );
    if (amount == null) return;
    await DatabaseService.instance.addPayroll(
      PayrollPayment(
        id: null,
        employeeId: employee.id!,
        date: now,
        period: period,
        amount: amount,
        type: employee.type,
      ),
    );
    HapticFeedback.lightImpact();
    await load();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Paid ${FinanceCalculator.money(amount)} to ${employee.name}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final monthlyTotal = payments
        .where((p) => p.period.startsWith(month))
        .fold<double>(0, (s, p) => s + p.amount);
    final paidCount = employees.where(_isPaid).length;
    final names = {for (final e in employees) e.id: e.name};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: const [AdminSettingsAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEmployee,
        icon: const Icon(Icons.person_add),
        label: const Text('Add employee'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Paid this month',
                                  style: TextStyle(
                                    color: context.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$paidCount of ${employees.length} paid',
                                  style: TextStyle(
                                    color: context.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            MaskedText(
                              FinanceCalculator.money(monthlyTotal),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LinearProgressIndicator(
                              value: employees.isEmpty
                                  ? 0
                                  : paidCount / employees.length,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                              backgroundColor: context.hairline,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SectionHeader('Employees'),
                    if (employees.isEmpty)
                      const EmptyState(
                        title: 'No employees yet',
                        icon: Icons.groups_outlined,
                      ),
                    ...employees.map((employee) {
                      final paid = _isPaid(employee);
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            4,
                            4,
                            4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: context.accent.withValues(
                              alpha: .12,
                            ),
                            child: Text(
                              employee.name.isEmpty
                                  ? '?'
                                  : employee.name[0].toUpperCase(),
                              style: TextStyle(
                                color: context.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            employee.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${employee.type == 'daily' ? 'Daily' : 'Monthly'} • ${FinanceCalculator.money(employee.wage)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (paid)
                                StatusPill('Paid', context.good)
                              else
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 38),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                  ),
                                  onPressed: () => pay(employee),
                                  child: const Text('Pay'),
                                ),
                              PopupMenuButton<String>(
                                tooltip: 'More',
                                onSelected: (value) {
                                  if (value == 'edit') addEmployee(employee);
                                  if (value == 'remove')
                                    removeEmployee(employee);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SectionHeader('Recent payments'),
                    if (payments.isEmpty)
                      const EmptyState(
                        title: 'No payments yet',
                        icon: Icons.payments_outlined,
                      ),
                    ...payments
                        .take(15)
                        .map(
                          (payment) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: context.softFill,
                                child: Icon(
                                  Icons.payments_outlined,
                                  color: context.muted,
                                ),
                              ),
                              title: Text(
                                names[payment.employeeId] ??
                                    (payment.type == 'daily'
                                        ? 'Daily wage'
                                        : 'Monthly salary'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${payment.type == 'daily' ? 'Daily' : 'Monthly'} • ${dayLabel(payment.date)}',
                              ),
                              trailing: MaskedText(
                                FinanceCalculator.money(payment.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
    );
  }
}
