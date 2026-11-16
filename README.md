# Billit Finance

Standalone Flutter application for the finance-monitoring functionality extracted from Billit. The original `NaurasShaji/Billit` repository is not modified by this project.

## Current implementation

- SQLite local persistence for expense records, employees and payroll payments.
- Expense management: add, edit, search/filter, delete and custom categories.
- Employee management for daily-wage and monthly-salary employees.
- Payroll payment recording with duplicate-period protection and retained payment history.
- Monthly expense/payroll overview.
- Daily, monthly and yearly finance reports with PDF and CSV download and sharing.
- Google Drive OAuth connection, JSON backup, backup listing and restore.
- Single local administrator account. First launch creates the admin password; later launches require that password.
- Billit logo and launcher icon assets/configuration.

## Data and backup behavior

The local SQLite database is `billit_finance.db` and currently contains `expenses`, `employees` and `payroll_payments`. Google Drive backups include these tables only.

The Drive restore service accepts this app's finance backup format and compatible legacy Billit JSON backups containing expense and employee arrays. Legacy salary expenses remain in the expense ledger; they are not silently converted into structured payroll payment records. Restore replaces the corresponding local finance tables, so verify the selected backup before restoring.

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

Repository files have been updated through GitHub. A Flutter build, device-level Google OAuth test, Drive backup/restore round-trip, and end-to-end UI validation still need to be run in a configured Flutter environment. Do not treat Google Drive as production-ready until OAuth client configuration and restore testing are complete.
