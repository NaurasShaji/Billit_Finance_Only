# Billit Finance

Standalone Flutter application for the finance-monitoring functionality extracted from Billit. The original `NaurasShaji/Billit` repository is not modified by this project.

## Current implementation

- SQLite local persistence for expenses, employees, payroll, income, payment allocations, credit ledger and daily cash-book sessions.
- Expense management: add, edit, search/filter, delete and custom categories.
- Employee management for daily-wage and monthly-salary employees.
- Payroll payment recording with duplicate-period protection and retained payment history.
- Monthly overview with sales, cost of goods sold, gross profit, expenses, payroll and net operating result.
- Manual income/sales entries with partial collections and payment-method tracking.
- Import of original Billit sales from compatible legacy Google Drive JSON backups, preserving Billit sale IDs to avoid duplicates.
- Customer receivables and supplier payables ledger with transaction history and due-date fields.
- Daily cash book with opening cash, cash/UPI/card/bank movements, expected cash and counted closing cash.
- Daily, monthly and yearly finance reports with sales, cost of goods sold, gross profit, expenses, payroll and net operating result; PDF and CSV download and sharing.
- Google Drive OAuth connection, JSON backup, backup listing and restore.
- Single local administrator account. First launch creates the admin password; later launches require that password.
- Billit logo and launcher icon assets/configuration.

## Data and backup behavior

The local SQLite database is `billit_finance.db` (schema version 4). It contains `expenses`, `employees`, `payroll_payments`, `income_entries`, `income_payments`, `credit_parties`, `credit_transactions`, `cash_sessions` and `cash_transactions`. Google Drive backup version 2 includes all of these tables.

The Drive restore service accepts this app's finance backup format and compatible legacy Billit JSON backups. For legacy Billit backups, it imports sales totals, sale dates, sale IDs, payment methods and total cost into the income ledger, alongside expenses and employees. Legacy salary expenses remain in the expense ledger; they are not silently converted into structured payroll payment records. Restore automatically uploads a safety backup of the current local finance tables to Drive before replacing them. A restore will fail rather than proceed if that safety backup cannot be created.

## Google Drive setup

Google Drive uses Google Sign-In OAuth and the Drive `drive.file` scope. Configure the Android OAuth client for this app's application ID and signing certificate in Google Cloud Console, enable the Google Drive API, and configure any other target platform's OAuth client before testing backup/restore.

The admin password and Google account authorization are separate. Google Drive sign-in does not create another app user.

## Branding and application identity

The original Billit assets are retained under `assets/icon/`. Launcher generation uses `assets/icon/billit_icon.png`; the in-app login uses `assets/icon/billit_logo.svg`. Android application ID is `com.example.billitfinance`, allowing this app to be installed alongside Billit.

## Run

Requires Flutter and Dart 3.6 or later.

```bash
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## Validation status

Repository files have been updated through GitHub. A Flutter build, device-level Google OAuth test, Drive backup/restore round-trip, original Billit sales-import verification, accounting reconciliation and end-to-end UI validation still need to be run in a configured Flutter environment. The displayed net operating result is only as accurate as the recorded COGS and expense/payroll entries; it is not a statutory P&L or GST report. Do not treat Google Drive as production-ready until OAuth client configuration and restore testing are complete.
