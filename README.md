# Billit Finance

Standalone finance-monitoring application extracted from finance-related parts of the original Billit app. Built with Flutter and SQLite (sqflite). This application is separate from the main Billit app and does not read or change its Hive database.

## Current modules

- **Overview:** monthly income, expense, payroll, COGS-adjustment and net operating result totals.
- **Income register:** manually add income by source.
- **Expense ledger:** categorize, add, edit, search, filter and delete expense records.
- **Payroll:** employee register for daily-wage and monthly-salary staff, plus period-based payment tracking.
- **Bank reconciliation:** bank-account register, manually entered statement lines, and amount-based matching to income/expense ledger entries.
- **COGS / stock costs:** store purchase, opening-cost and issued/sold adjustment records.

## Local SQLite database

Database file: `billit_finance.db`

Schema version 1:
`expenses`, `employees`, `payroll_payments`, `bank_accounts`, `bank_transactions`, `stock_costs`, `income_entries`, `reconciliation_links`.

## Branding and Android identity

The original Billit SVG logo, source launcher PNG, and all five density-specific Android launcher PNGs are retained. The Android manifest references `@mipmap/launcher_icon`.

The new Android application ID is `com.example.billitfinance`, separate from the original app's ID, so the two can be installed side by side.

Regenerate launcher resources after icon changes:
```bash
flutter pub get
dart run flutter_launcher_icons
```

## Run

Requires Flutter with Dart 3.6 or later.

```bash
flutter pub get
flutter run
```

## Accounting boundaries and outstanding integration

- Income is entered in this app; it is not automatically imported from Billit sales. Dashboard income therefore only reflects entries added here.
- Payroll is stored separately from ordinary expenses and included as a distinct outflow to avoid double counting.
- Bank reconciliation is manual and local. It supports manual bank-line entry and amount-based matching. There is no direct bank API connection or statement-file import/parser in this initial implementation.
- COGS currently sums entries marked as issued/sold adjustments. It is not a perpetual-inventory calculation, nor a FIFO/weighted-average costing engine. Purchases/opening costs are stored separately and are not automatically deducted from on-hand stock.
- The source app's expense CSV/PDF export service and its sales/GST report workflows have not yet been ported into this initial app.
- This is a local finance tracker, not a GST filing or statutory accounting product.

## Source areas reviewed

The extraction scope was based on the main Billit expense model and helper logic, expense-list workflow, expense CSV/PDF export service, employee model, employee-registration flow, daily-wage and monthly-salary payment screens, payroll report, dashboard financial calculations, and finance-related Archive destinations.
