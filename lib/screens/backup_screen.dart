import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/drive_backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_settings_action.dart';
import '../widgets/finance_ui.dart';
import '../widgets/ui_kit.dart';

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

  Future<void> _run(
    Future<void> Function() action, {
    String done = 'Done',
  }) async {
    setState(() => loading = true);
    try {
      await action();
      if (mounted) _message(done);
    } catch (e) {
      if (mounted) _message('Failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(value)));

  Future<void> _connect() => _run(() async {
    final user = await DriveBackupService.instance.signIn();
    account = user?.email;
    backups = await DriveBackupService.instance.listBackups();
  }, done: 'Connected');

  Future<void> _backupNow() => _run(() async {
    await DriveBackupService.instance.createBackup();
    backups = await DriveBackupService.instance.listBackups();
  }, done: 'Backup complete');

  Future<void> _refresh() => _run(() async {
    backups = await DriveBackupService.instance.listBackups();
  }, done: 'Updated');

  Future<void> _restore(DriveBackup backup) async {
    final ok = await FinanceUi.confirm(
      context,
      'Replace current data with this backup?',
      confirmLabel: 'Restore',
    );
    if (!ok) return;
    await _run(() async {
      await DriveBackupService.instance.restore(backup.id);
      DatabaseService.notifyChanged();
    }, done: 'Backup restored');
  }

  @override
  Widget build(BuildContext context) {
    final latest = backups.isEmpty ? null : backups.first.modifiedTime;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
        actions: [
          const AdminSettingsAction(),
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: context.accent.withValues(
                              alpha: .14,
                            ),
                            child: Icon(
                              Icons.cloud_sync_outlined,
                              color: context.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account ?? 'Google Drive',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                if (latest != null)
                                  Text(
                                    'Latest ${DateFormat('dd MMM, hh:mm a').format(latest)}',
                                    style: TextStyle(
                                      color: context.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (account == null)
                            OutlinedButton.icon(
                              onPressed: loading ? null : _connect,
                              icon: const Icon(Icons.login),
                              label: const Text('Connect'),
                            ),
                          FilledButton.icon(
                            onPressed: loading ? null : _backupNow,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Back up now'),
                          ),
                          OutlinedButton.icon(
                            onPressed: loading ? null : _refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              SectionHeader(
                'Backups',
                trailing: backups.isEmpty
                    ? null
                    : Text(
                        '${backups.length}',
                        style: TextStyle(
                          color: context.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (backups.isEmpty)
                const EmptyState(
                  title: 'No backups yet',
                  icon: Icons.cloud_off_outlined,
                ),
              ...backups.map(
                (backup) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.softFill,
                      child: Icon(Icons.backup_outlined, color: context.muted),
                    ),
                    title: Text(
                      backup.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: backup.modifiedTime == null
                        ? null
                        : Text(
                            DateFormat('dd MMM yyyy, hh:mm a')
                                .format(backup.modifiedTime!),
                          ),
                    trailing: IconButton(
                      tooltip: 'Restore',
                      icon: const Icon(Icons.restore),
                      onPressed: loading ? null : () => _restore(backup),
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
