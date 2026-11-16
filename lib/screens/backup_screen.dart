import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/drive_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}
class _BackupScreenState extends State<BackupScreen> {
  bool loading = false;
  List<DriveBackup> backups = [];
  String? account;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => loading = true);
    try { await action(); if (mounted) _message('Completed.'); }
    catch (e) { if (mounted) _message('Failed: $e'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  Future<void> _connect() async {
    await _run(() async {
      final user = await DriveBackupService.instance.signIn();
      account = user?.email;
      backups = await DriveBackupService.instance.listBackups();
      if (mounted) setState(() {});
    });
  }
  Future<void> _refresh() async {
    await _run(() async { backups = await DriveBackupService.instance.listBackups(); });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Google Drive Backup'), actions: [IconButton(tooltip: 'Log out', onPressed: widget.onLogout, icon: const Icon(Icons.logout))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Finance data backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Backs up expenses, employees and payroll records from this app’s SQLite database.'),
          if (account != null) ...[const SizedBox(height: 8), Text('Connected: $account')],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: loading ? null : _connect, icon: const Icon(Icons.login), label: const Text('Connect Google Drive')),
            FilledButton.icon(onPressed: loading ? null : () => _run(() async {
              await DriveBackupService.instance.createBackup();
              backups = await DriveBackupService.instance.listBackups();
            }), icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Back up now')),
            TextButton.icon(onPressed: loading ? null : _refresh, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          ]),
        ],
      ))),
      const SizedBox(height: 16),
      Text('Available backups', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (loading) const LinearProgressIndicator(),
      if (backups.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Connect Google Drive and refresh to view backups.'))),
      ...backups.map((backup) => Card(child: ListTile(
        leading: const Icon(Icons.cloud_done_outlined),
        title: Text(backup.name),
        subtitle: Text(backup.modifiedTime == null ? 'Google Drive backup' : DateFormat('dd MMM yyyy, hh:mm a').format(backup.modifiedTime!)),
        trailing: IconButton(
          tooltip: 'Restore backup',
          icon: const Icon(Icons.restore),
          onPressed: loading ? null : () => _run(() async {
            await DriveBackupService.instance.restore(backup.id);
          }),
        ),
      ))),
    ]),
  );
}
