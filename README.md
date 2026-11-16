# Billit Finance

A standalone Flutter application containing the existing Billit finance-monitoring scope. It uses SQLite locally and keeps the Billit brand identity.

## Included

- Expense records: add, edit, search, filter, delete and create custom categories.
- Employee records: daily-wage and monthly-salary employees.
- Payroll payment records.
- Monthly finance overview for expenses and payroll.
- Daily, monthly and yearly PDF/CSV report downloads and sharing.
- Google Drive backup and restore for this app's expenses, employees and payroll data, including import of compatible legacy Billit backups.
- One local administrator login. The first launch asks the administrator to create a password.

No separate income register, bank reconciliation, COGS/stock-cost module, sales ledger or staff roles are included.

## Storage

The local database is `billit_finance.db`, with `expenses`, `employees` and `payroll_payments` tables. Google Drive backups contain only those three tables. When restoring an older full-Billit JSON backup, expense and employee records are imported; legacy salary entries remain in the expense ledger and are not automatically converted into structured payroll-payment rows.

## Google Drive setup

Google Drive backup uses Google Sign-In OAuth and the Drive `drive.file` scope. Configure the Android OAuth client for the app's application ID and signing certificate in Google Cloud Console, enable the Google Drive API, and configure the platform-specific OAuth client before testing Drive backup. The admin password and Google account authorization are separate.

## Branding

The launcher configuration points to `assets/icon/billit_icon.png`; the Billit logo asset is retained in `assets/icon/`. Android application ID is `com.example.billitfinance` so this app can be installed alongside the original Billit app.

## Run

Requires Flutter and Dart 3.6 or later.

```bash
flutter pub get
dart run flutter_launcher_icons
flutter run
```
