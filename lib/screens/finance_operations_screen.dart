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

String _cap(String value) {
  final text = value.replaceAll('_', ' ');
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

class FinanceOperationsScreen extends StatelessWidget {
  const FinanceOperationsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: const [AdminSettingsAction()],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Income'),
            Tab(text: 'Credit'),
            Tab(text: 'Cash book'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_IncomeTab(), _CreditTab(), _CashTab()],
      ),
    ),
  );
}

// ---------------------------------------------------------------- Income

class _IncomeTab extends StatefulWidget {
  const _IncomeTab();
  @override
  State<_IncomeTab> createState() => _IncomeTabState();
}

class _IncomeTabState extends State<_IncomeTab> {
  List<IncomeRecord> rows = [];
  Map<int, double> paid = {};
  double total = 0, received = 0;
  bool busy = true;

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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final db = DatabaseService.instance;
    final r = await db.income(start: start, end: end);
    final collected = await db.incomeCollected(start: start, end: end);
    final paidTotals = await db.incomePaidTotals();
    if (!mounted) return;
    setState(() {
      rows = r;
      paid = paidTotals;
      total = r.fold<double>(0, (v, x) => v + x.amount);
      received = collected;
      busy = false;
    });
  }

  Future<void> add() async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const IncomeEntryPage()));
    await load();
  }

  Widget _status(BuildContext context, IncomeRecord x) {
    final collected = paid[x.id] ?? 0;
    if (collected >= x.amount - 0.005) return StatusPill('Paid', context.good);
    if (collected > 0) return StatusPill('Partial', context.caution);
    return StatusPill('Due', context.bad);
  }

  @override
  Widget build(BuildContext context) {
    if (busy) return const Center(child: CircularProgressIndicator());
    final groups = <String, List<IncomeRecord>>{};
    for (final x in rows) {
      groups.putIfAbsent(dayLabel(x.date), () => []).add(x);
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final count = box.maxWidth > 700 ? 3 : 1;
              final w = (box.maxWidth - (count - 1) * 10) / count;
              final cards = [
                StatCard(
                  title: 'Sales this month',
                  value: FinanceCalculator.money(total),
                  icon: Icons.trending_up,
                  color: AppColors.positive,
                ),
                StatCard(
                  title: 'Collected',
                  value: FinanceCalculator.money(received),
                  icon: Icons.payments_outlined,
                ),
                StatCard(
                  title: 'Outstanding',
                  value: FinanceCalculator.money(total - received),
                  icon: Icons.pending_actions,
                  color: AppColors.warning,
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final c in cards) SizedBox(width: w, child: c)],
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add),
            label: const Text('Add sale'),
          ),
          if (rows.isEmpty)
            const EmptyState(
              title: 'No sales this month',
              icon: Icons.trending_up,
            ),
          for (final g in groups.entries) ...[
            DayHeader(
              label: g.key,
              total: g.value.fold<double>(0, (s, x) => s + x.amount),
            ),
            for (final x in g.value)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.good.withValues(alpha: .12),
                    child: Icon(Icons.south_west, color: context.good),
                  ),
                  title: Text(
                    x.description.isEmpty ? 'Sale' : x.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MaskedText(
                        FinanceCalculator.money(x.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      _status(context, x),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Credit

class _CreditTab extends StatefulWidget {
  const _CreditTab();
  @override
  State<_CreditTab> createState() => _CreditTabState();
}

class _CreditTabState extends State<_CreditTab> {
  List<Map<String, Object?>> rows = [];
  bool busy = true;
  String filter = 'all';
  String query = '';

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
    final x = await DatabaseService.instance.creditBalances();
    if (!mounted) return;
    setState(() {
      rows = x;
      busy = false;
    });
  }

  /// Positive: the party owes you. Negative: you owe the party.
  double _owedToYou(Map<String, Object?> row) {
    final balance = (row['balance'] as num).toDouble();
    return row['type'] == 'customer' ? balance : -balance;
  }

  Future<void> addParty() async {
    final party = await Navigator.of(context).push<CreditParty>(
      MaterialPageRoute(builder: (_) => const _PartyEntryPage()),
    );
    if (party == null) return;
    await DatabaseService.instance.addCreditParty(party);
    await load();
  }

  Future<void> showParty(CreditParty party) async {
    final history = await DatabaseService.instance.creditTransactions(
      party.id!,
    );
    if (!mounted) return;
    final addNew = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _PartyHistoryPage(party: party, history: history)),
    );
    if (addNew == true && mounted) await addEntry(party);
  }

  Future<void> addEntry(CreditParty party) async {
    final entry = await Navigator.of(context).push<CreditTransaction>(
      MaterialPageRoute(builder: (_) => _CreditEntryPage(party: party)),
    );
    if (entry == null) return;
    await DatabaseService.instance.addCreditTransaction(entry);
    HapticFeedback.lightImpact();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (busy) return const Center(child: CircularProgressIndicator());
    var toReceive = 0.0, toPay = 0.0;
    for (final r in rows) {
      final v = _owedToYou(r);
      if (v > 0) toReceive += v;
      if (v < 0) toPay += -v;
    }
    final q = query.trim().toLowerCase();
    final shown = rows.where((r) {
      final type = r['type'] as String;
      final matchesType =
          filter == 'all' ||
          (filter == 'customers' && type == 'customer') ||
          (filter == 'suppliers' && type == 'supplier');
      return matchesType &&
          (q.isEmpty || (r['name'] as String).toLowerCase().contains(q));
    }).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'To receive',
                  value: FinanceCalculator.money(toReceive),
                  icon: Icons.south_west,
                  color: AppColors.positive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  title: 'To pay',
                  value: FinanceCalculator.money(toPay),
                  icon: Icons.north_east,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: addParty,
            icon: const Icon(Icons.person_add),
            label: const Text('Add party'),
          ),
          const SizedBox(height: 12),
          if (rows.length > 4) ...[
            TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search',
              ),
            ),
            const SizedBox(height: 10),
          ],
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'customers', label: Text('Customers')),
              ButtonSegment(value: 'suppliers', label: Text('Suppliers')),
            ],
            selected: {filter},
            onSelectionChanged: (s) => setState(() => filter = s.first),
          ),
          if (shown.isEmpty)
            const EmptyState(title: 'No parties', icon: Icons.people_outline),
          const SizedBox(height: 6),
          for (final r in shown) _partyTile(context, r),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _partyTile(BuildContext context, Map<String, Object?> r) {
    final party = CreditParty.fromMap(r);
    final owed = _owedToYou(r);
    final settled = owed.abs() < 0.005;
    final color = settled
        ? context.muted
        : (owed > 0 ? context.good : context.caution);
    return Card(
      child: ListTile(
        onTap: () => showParty(party),
        leading: CircleAvatar(
          backgroundColor: context.accent.withValues(alpha: .12),
          child: Text(
            party.name.isEmpty ? '?' : party.name[0].toUpperCase(),
            style: TextStyle(
              color: context.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          party.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(party.type == 'customer' ? 'Customer' : 'Supplier'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MaskedText(
              FinanceCalculator.money(owed.abs()),
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
            Text(
              settled ? 'Settled' : (owed > 0 ? 'Owes you' : 'You owe'),
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartyDialog extends StatefulWidget {
  const _PartyDialog();
  @override
  State<_PartyDialog> createState() => _PartyDialogState();
}

class _PartyDialogState extends State<_PartyDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _type = 'customer';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    Navigator.pop(
      context,
      CreditParty(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        type: _type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add party'),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'customer', label: Text('Customer')),
              ButtonSegment(value: 'supplier', label: Text('Supplier')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.party});
  final CreditParty party;
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _type = widget.party.type == 'customer'
      ? 'credit_sale'
      : 'credit_purchase';
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  String? _error;

  List<String> get _types => widget.party.type == 'customer'
      ? ['credit_sale', 'payment_received', 'adjustment']
      : ['credit_purchase', 'payment_made', 'adjustment'];
  bool get _isCredit => _type == 'credit_sale' || _type == 'credit_purchase';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.pop(
      context,
      CreditTransaction(
        partyId: widget.party.id!,
        date: DateTime.now(),
        type: _type,
        amount: value,
        dueDate: _isCredit ? _due : null,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.party.name),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _types)
                  ChoiceChip(
                    label: Text(_cap(t)),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note'),
              onSubmitted: (_) => _save(),
            ),
            if (_isCredit)
              TextButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _due,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _due = d);
                },
                icon: const Icon(Icons.event),
                label: Text('Due ${DateFormat('dd MMM yyyy').format(_due)}'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

// ---------------------------------------------------------------- Cash book

class _CashTab extends StatefulWidget {
  const _CashTab();
  @override
  State<_CashTab> createState() => _CashTabState();
}

class _CashTabState extends State<_CashTab> {
  CashSession? session;
  List<CashTransaction> rows = [];
  Map<String, double> net = {};
  bool busy = true;

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
    final db = DatabaseService.instance;
    final s = await db.cashSession(DateTime.now());
    if (s == null) {
      if (mounted) {
        setState(() {
          session = null;
          rows = [];
          net = {};
          busy = false;
        });
      }
      return;
    }
    final r = await db.cashTransactions(s.id!);
    final b = await db.cashBalances(s.id!);
    if (!mounted) return;
    setState(() {
      session = s;
      rows = r;
      net = b;
      busy = false;
    });
  }

  double get expectedCash =>
      (session?.openingBalance ?? 0) + (net['cash'] ?? 0);

  Future<void> open() async {
    final v = await showAmountDialog(
      context,
      title: 'Opening cash',
      label: 'Cash in drawer',
      allowZero: true,
      confirmLabel: 'Open day',
    );
    if (v == null) return;
    await DatabaseService.instance.openCashSession(DateTime.now(), v);
    await load();
  }

  Future<void> movement() async {
    final entry = await Navigator.of(context).push<CashTransaction>(
      MaterialPageRoute(builder: (_) => _CashMovementPage(sessionId: session!.id!)),
    );
    if (entry == null) return;
    await DatabaseService.instance.addCashTransaction(entry);
    HapticFeedback.lightImpact();
    await load();
  }

  Future<void> close() async {
    final v = await showAmountDialog(
      context,
      title: 'Close day',
      label: 'Cash counted',
      initial: expectedCash,
      allowZero: true,
      confirmLabel: 'Close',
    );
    if (v == null) return;
    await DatabaseService.instance.closeCashSession(session!.id!, v);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (busy) return const Center(child: CircularProgressIndicator());
    final s = session;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (s == null)
            FilledButton.icon(
              onPressed: open,
              icon: const Icon(Icons.lock_open),
              label: const Text('Open today’s cash book'),
            )
          else ...[
            LayoutBuilder(
              builder: (context, box) {
                final count = box.maxWidth > 700 ? 3 : 2;
                final w = (box.maxWidth - (count - 1) * 10) / count;
                final tiles = <Widget>[
                  StatCard(
                    title: 'Opening cash',
                    value: FinanceCalculator.money(s.openingBalance),
                    icon: Icons.lock_open,
                  ),
                  StatCard(
                    title: 'Expected cash',
                    value: FinanceCalculator.money(expectedCash),
                    icon: Icons.payments_outlined,
                    color: AppColors.positive,
                  ),
                  for (final m in ['cash', 'upi', 'card', 'bank'])
                    StatCard(
                      title: '${m.toUpperCase()} net',
                      value: FinanceCalculator.money(net[m] ?? 0),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  if (s.status == 'closed') ...[
                    StatCard(
                      title: 'Counted cash',
                      value: FinanceCalculator.money(s.closingBalance ?? 0),
                      icon: Icons.fact_check_outlined,
                    ),
                    StatCard(
                      title: 'Variance',
                      value: FinanceCalculator.money(
                        (s.closingBalance ?? 0) - expectedCash,
                      ),
                      icon: Icons.balance,
                      color: AppColors.warning,
                    ),
                  ],
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final t in tiles) SizedBox(width: w, child: t),
                  ],
                );
              },
            ),
            if (s.status == 'open') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: movement,
                      icon: const Icon(Icons.add),
                      label: const Text('Add movement'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: close,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Close day'),
                    ),
                  ),
                ],
              ),
            ],
            const SectionHeader('Movements'),
            if (rows.isEmpty)
              const EmptyState(
                title: 'No movements yet',
                icon: Icons.payments_outlined,
              ),
            for (final r in rows)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (r.direction == 'in' ? context.good : context.caution)
                            .withValues(alpha: .14),
                    child: Icon(
                      r.direction == 'in' ? Icons.south_west : Icons.north_east,
                      color: r.direction == 'in'
                          ? context.good
                          : context.caution,
                    ),
                  ),
                  title: Text(
                    r.note.isEmpty ? r.method.toUpperCase() : r.note,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${r.direction == 'in' ? 'In' : 'Out'} • ${r.method.toUpperCase()}',
                  ),
                  trailing: MaskedText(
                    '${r.direction == 'in' ? '+' : '−'}${FinanceCalculator.money(r.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: r.direction == 'in' ? context.good : context.ink,
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({required this.sessionId});
  final int sessionId;
  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _direction = 'in';
  String _method = 'cash';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.pop(
      context,
      CashTransaction(
        sessionId: widget.sessionId,
        date: DateTime.now(),
        direction: _direction,
        method: _method,
        amount: value,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cash movement'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 'in',
                  label: Text('Money in'),
                  icon: Icon(Icons.south_west),
                ),
                ButtonSegment(
                  value: 'out',
                  label: Text('Money out'),
                  icon: Icon(Icons.north_east),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in ['cash', 'upi', 'card', 'bank'])
                  ChoiceChip(
                    label: Text(m.toUpperCase()),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Description'),
              onSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}


class _PartyEntryPage extends StatefulWidget {
  const _PartyEntryPage();
  @override
  State<_PartyEntryPage> createState() => _PartyEntryPageState();
}
class _PartyEntryPageState extends State<_PartyEntryPage> {
  final _name = TextEditingController(), _phone = TextEditingController();
  String _type = 'customer';
  String? _error;
  @override
  void dispose() { _name.dispose(); _phone.dispose(); super.dispose(); }
  void _save() {
    if (_name.text.trim().isEmpty) { setState(() => _error = 'Enter a name'); return; }
    Navigator.pop(context, CreditParty(name: _name.text.trim(), phone: _phone.text.trim(), type: _type));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add party'), actions: [TextButton(onPressed: _save, child: const Text('Save'))]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: ListView(padding: const EdgeInsets.all(20), children: [
      SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'customer', label: Text('Customer')), ButtonSegment(value: 'supplier', label: Text('Supplier'))], selected: {_type}, onSelectionChanged: (v) => setState(() => _type = v.first)),
      const SizedBox(height: 16),
      TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Name', errorText: _error)),
      const SizedBox(height: 12),
      TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
      const SizedBox(height: 20),
      FilledButton(onPressed: _save, child: const Text('Save party')),
    ]))),
  );
}

class _PartyHistoryPage extends StatelessWidget {
  const _PartyHistoryPage({required this.party, required this.history});
  final CreditParty party;
  final List<CreditTransaction> history;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(party.name), actions: [TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add entry'))]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: ListView(padding: const EdgeInsets.all(16), children: [
      if (history.isEmpty) const EmptyState(title: 'No entries yet', icon: Icons.receipt_long_outlined),
      for (final t in history) Card(child: ListTile(
        title: Text(_cap(t.type)),
        subtitle: Text(DateFormat('dd MMM yyyy').format(t.date) + (t.dueDate == null ? '' : ' • Due ${DateFormat('dd MMM yyyy').format(t.dueDate!)}') + (t.note.isEmpty ? '' : ' • ${t.note}')),
        trailing: Text(FinanceCalculator.money(t.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
      )),
    ]))),
  );
}

class _CreditEntryPage extends StatefulWidget {
  const _CreditEntryPage({required this.party});
  final CreditParty party;
  @override
  State<_CreditEntryPage> createState() => _CreditEntryPageState();
}
class _CreditEntryPageState extends State<_CreditEntryPage> {
  final _amount = TextEditingController(), _note = TextEditingController();
  late String _type = widget.party.type == 'customer' ? 'credit_sale' : 'credit_purchase';
  DateTime _due = DateTime.now().add(const Duration(days: 7));
  String? _error;
  List<String> get _types => widget.party.type == 'customer' ? ['credit_sale', 'payment_received', 'adjustment'] : ['credit_purchase', 'payment_made', 'adjustment'];
  bool get _isCredit => _type == 'credit_sale' || _type == 'credit_purchase';
  @override
  void dispose() { _amount.dispose(); _note.dispose(); super.dispose(); }
  void _save() {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0) { setState(() => _error = 'Enter a valid amount'); return; }
    Navigator.pop(context, CreditTransaction(partyId: widget.party.id!, date: DateTime.now(), type: _type, amount: value, dueDate: _isCredit ? _due : null, note: _note.text.trim()));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Add entry · ${widget.party.name}'), actions: [TextButton(onPressed: _save, child: const Text('Save'))]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: ListView(padding: const EdgeInsets.all(20), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [for (final t in _types) ChoiceChip(label: Text(_cap(t)), selected: _type == t, onSelected: (_) => setState(() => _type = t))]),
      const SizedBox(height: 16),
      TextField(controller: _amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Amount', prefixText: '₹ ', errorText: _error)),
      const SizedBox(height: 12),
      TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note')),
      if (_isCredit) ...[const SizedBox(height: 12), DateField(value: _due, onChanged: (d) => setState(() => _due = d)), Text('Due date: ${DateFormat('dd MMM yyyy').format(_due)}')],
      const SizedBox(height: 20),
      FilledButton(onPressed: _save, child: const Text('Save entry')),
    ]))),
  );
}

class _CashMovementPage extends StatefulWidget {
  const _CashMovementPage({required this.sessionId});
  final int sessionId;
  @override
  State<_CashMovementPage> createState() => _CashMovementPageState();
}
class _CashMovementPageState extends State<_CashMovementPage> {
  final _amount = TextEditingController(), _note = TextEditingController();
  String _direction = 'in', _method = 'cash';
  String? _error;
  @override
  void dispose() { _amount.dispose(); _note.dispose(); super.dispose(); }
  void _save() {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0) { setState(() => _error = 'Enter a valid amount'); return; }
    Navigator.pop(context, CashTransaction(sessionId: widget.sessionId, date: DateTime.now(), direction: _direction, method: _method, amount: value, note: _note.text.trim()));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cash movement'), actions: [TextButton(onPressed: _save, child: const Text('Save'))]),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: ListView(padding: const EdgeInsets.all(20), children: [
      SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'in', label: Text('Money in'), icon: Icon(Icons.south_west)), ButtonSegment(value: 'out', label: Text('Money out'), icon: Icon(Icons.north_east))], selected: {_direction}, onSelectionChanged: (v) => setState(() => _direction = v.first)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [for (final m in ['cash', 'upi', 'card', 'bank']) ChoiceChip(label: Text(m.toUpperCase()), selected: _method == m, onSelected: (_) => setState(() => _method = m))]),
      const SizedBox(height: 16),
      TextField(controller: _amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Amount', prefixText: '₹ ', errorText: _error)),
      const SizedBox(height: 12),
      TextField(controller: _note, decoration: const InputDecoration(labelText: 'Description')),
      const SizedBox(height: 20),
      FilledButton(onPressed: _save, child: const Text('Save movement')),
    ]))),
  );
}
