# Billit Finance

Standalone finance-monitoring application extracted from the finance-related areas of the main Billit app. Built with Flutter and SQLite (sqflite). This is an independent app: it does not connect to or modify the original Billit Hive database.

## Modules

- **Overview:** monthly income, expenses, payroll, COGS adjustments and net operating result.
- **Income register:** record income by source and date.
- **Expense ledger:** categorize, add, edit, search, filter and delete expenses.
- **Payroll:** daily-wage and monthly-salary employees with period-based payment recording.
- **Bank reconciliation:** create bank accounts, enter statement transactions, and match them to expense/income entries.
- **COGS / stock costs:** record purchase costs, opening costs and issued/sold adjustments.

## SQLite

Database: `billit_finance.db`

Schema v1 creates:
`expenses`, `employees`, `payroll_payments`, `bank_accounts`, `bank_transactions`, `stock_costs`, `income_entries`, and `reconciliation_links`.

## Branding

The original Billit SVG logo, source launcher PNG and Android density-specific launcher images are retained. Android uses the `@mipmap/launcher_icon` resource. The package/application ID is `com.example.billitfinance`, separate from the main app.

To regenerate launcher resources:
```bash
flutter pub get
dart run flutter_launcher_icons
```

## Run

Requires Flutter with Dart 3.6+.
```bash
flutter pub get
flutter run
```

## Accounting boundaries

- Income is entered in this application. It is not automatically imported from Billit sales; dashboard income reflects only data recorded here.
- Payroll payouts are stored only in `payroll_payments`, not duplicated in `expenses`. The dashboard includes payroll separately in outflows.
- Bank reconciliation is manual and local. It matches statement transactions to ledger rows based on amount; there is no direct bank connection or statement file parser yet.
- The COGS figure is the total of entries marked as issued/sold adjustments. It is not perpetual inventory valuation or a FIFO/weighted-average accounting engine.
- This application is a finance tracker, not a GST filing or statutory accounting product.

## Source modules reviewed

The extraction was based on the main Billit app's expense model and logic, expense list, CSV/PDF export service, employee model, add-employee flow, daily-wage and monthly-salary payment screens, payroll report, dashboard financial metrics, and finance-related Archive destinations.
