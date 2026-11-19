import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_settings_action.dart';
import '../widgets/ui_kit.dart';

class BillPhotosScreen extends StatefulWidget {
  const BillPhotosScreen({super.key, this.embedInAccounts = false});
  final bool embedInAccounts;

  @override
  State<BillPhotosScreen> createState() => _BillPhotosScreenState();
}

class _BillPhotosScreenState extends State<BillPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = true;
  List<Map<String, Object?>> _photos = [];

  @override
  void initState() {
    super.initState();
    DatabaseService.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DatabaseService.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await DatabaseService.instance.billPhotos();
    if (!mounted) return;
    setState(() {
      _photos = rows;
      _loading = false;
    });
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 2200,
        maxHeight: 2200,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _savePhoto(bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not capture bill photo: $e')),
      );
    }
  }

  Future<void> _savePhoto(Uint8List bytes) async {
    final title = TextEditingController();
    DateTime date = DateTime.now();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Save bill photo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(bytes, height: 190, width: double.infinity, fit: BoxFit.contain),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Bill name',
                    hintText: 'e.g. Electricity bill, supplier invoice',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Bill date'),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(date)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save bill photo'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final name = title.text.trim();
    title.dispose();
    if (result != true || !mounted) return;
    try {
      await DatabaseService.instance.addBillPhoto(
        title: name.isEmpty ? 'Bill photo' : name,
        date: date,
        imageBytes: bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill photo saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save bill photo: $e')),
        );
      }
    }
  }

  Future<void> _delete(Map<String, Object?> photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete bill photo?'),
        content: Text('“${photo['title']}” will be permanently deleted from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await DatabaseService.instance.deleteBillPhoto(photo['id'] as int);
  }

  void _view(Map<String, Object?> photo) {
    final bytes = photo['image_data'] as Uint8List;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(photo['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Delete bill photo',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                Navigator.pop(context);
                await _delete(photo);
              },
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: .7,
            maxScale: 5,
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: context.accent.withValues(alpha: .12),
                                    child: Icon(Icons.document_scanner_outlined, color: context.accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Store paper bills digitally', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                        Text('Capture supplier bills, utility receipts and other documents.', style: TextStyle(color: context.muted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final compact = constraints.maxWidth < 440;
                                  final camera = FilledButton.icon(
                                    onPressed: () => _pick(ImageSource.camera),
                                    icon: const Icon(Icons.photo_camera_outlined),
                                    label: const Text('Take photo'),
                                  );
                                  final gallery = OutlinedButton.icon(
                                    onPressed: () => _pick(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library_outlined),
                                    label: const Text('Choose from gallery'),
                                  );
                                  return compact
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [camera, const SizedBox(height: 8), gallery],
                                        )
                                      : Row(children: [Expanded(child: camera), const SizedBox(width: 10), Expanded(child: gallery)]);
                                },
                              ),
                              const SizedBox(height: 10),
                              Text('Photos are stored locally in this app and included in Google Drive backups.', style: TextStyle(color: context.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      SectionHeader(
                        'Stored bills',
                        trailing: Text('${_photos.length}', style: TextStyle(color: context.muted, fontWeight: FontWeight.w700)),
                      ),
                      if (_photos.isEmpty)
                        const EmptyState(
                          title: 'No bill photos stored',
                          icon: Icons.receipt_long_outlined,
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 480 ? 2 : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 250,
                              ),
                              itemCount: _photos.length,
                              itemBuilder: (context, index) {
                                final photo = _photos[index];
                                final bytes = photo['image_data'] as Uint8List;
                                return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => _view(photo),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 36))),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 9, 4, 8),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(photo['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                                    const SizedBox(height: 2),
                                                    Text(DateFormat('dd MMM yyyy').format(DateTime.parse(photo['bill_date'] as String)), style: TextStyle(color: context.muted, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete',
                                                onPressed: () => _delete(photo),
                                                icon: const Icon(Icons.delete_outline),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
        ),
      );
    return widget.embedInAccounts
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Bill Photos'), actions: const [AdminSettingsAction()]),
            body: content,
          );
  }
}
