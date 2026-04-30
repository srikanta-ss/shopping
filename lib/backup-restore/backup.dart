import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _lastBackupPath;
  String? _lastActionMessage;
  String? _lastRestoreFileName;
  String? _lastRestoreMessage;

  bool _isRelevantKey(String key) {
    return key == 'shopping_lists' || key.startsWith('sublist_items_');
  }

  Future<void> _setPreferenceValue({
    required SharedPreferences prefs,
    required String key,
    required dynamic value,
  }) async {
    if (value is String) {
      await prefs.setString(key, value);
      return;
    }
    if (value is bool) {
      await prefs.setBool(key, value);
      return;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return;
    }
    if (value is List) {
      await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      return;
    }

    throw Exception('Unsupported value type for key: $key');
  }

  Future<String> _readSelectedFileContent(PlatformFile file) async {
    if (file.path != null) {
      return File(file.path!).readAsString();
    }
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    throw Exception('Could not read selected file.');
  }

  Future<void> _pickAndRestoreBackup() async {
    setState(() {
      _isRestoring = true;
      _lastRestoreMessage = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (picked == null || picked.files.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Restore cancelled.')));
        return;
      }

      final selected = picked.files.first;
      final content = await _readSelectedFileContent(selected);
      final decoded = json.decode(content);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid backup file format.');
      }

      final data = decoded['data'];
      if (data is! Map) {
        throw Exception('Backup file has no valid data block.');
      }

      final prefs = await SharedPreferences.getInstance();

      final existingKeys = prefs.getKeys().where(_isRelevantKey).toList();
      for (final key in existingKeys) {
        await prefs.remove(key);
      }

      var restoredCount = 0;
      for (final entry in data.entries) {
        final key = entry.key.toString();
        if (!_isRelevantKey(key)) continue;

        await _setPreferenceValue(prefs: prefs, key: key, value: entry.value);
        restoredCount += 1;
      }

      if (!mounted) return;
      setState(() {
        _lastRestoreFileName = selected.name;
        _lastRestoreMessage =
            'Restore complete. Restored $restoredCount data entries from ${selected.name}.';
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Restore Successful',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your data has been restored successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastRestoreMessage = 'Restore failed: $e';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<bool> _confirmGoogleDrivePermission() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Backup To Drive'),
        content: const Text(
          'This app will create a backup file and open the system share sheet. Choose Google Drive there to store the backup in your Drive account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<File> _createLocalBackupFile() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) {
      return key == 'shopping_lists' || key.startsWith('sublist_items_');
    }).toList()..sort();

    final data = <String, dynamic>{};
    for (final key in keys) {
      data[key] = prefs.get(key);
    }

    final payload = <String, dynamic>{
      'app': 'shopping',
      'schemaVersion': 1,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };

    final docsDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(docsDir.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final formattedTimestamp =
        '${twoDigits(now.day)}${twoDigits(now.month)}${now.year}${twoDigits(now.hour)}${twoDigits(now.minute)}';
    final filename = 'shopping_Backup_$formattedTimestamp.json';
    final file = File(p.join(backupsDir.path, filename));
    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);
    await file.writeAsString(prettyJson, flush: true);
    return file;
  }

  Future<void> _shareBackupFileToDrive(File file) async {
    final shouldContinue = await _confirmGoogleDrivePermission();
    if (!shouldContinue) {
      throw const _BackupCancelledException();
    }

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'Shopping backup file',
      subject: p.basename(file.path),
    );
  }

  Future<void> _backupAndUpload() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google Drive backup is supported on Android/iOS only.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    try {
      final backupFile = await _createLocalBackupFile();
      await _shareBackupFileToDrive(backupFile);

      if (!mounted) return;
      setState(() {
        _lastBackupPath = backupFile.path;
        _lastActionMessage =
            'Share sheet opened. Choose Google Drive to finish storing the backup.';
      });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    Icons.cloud_done_rounded,
                    color: Colors.blue.shade600,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Backup Successful',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Backup file created.\nChoose Google Drive or any storage in the share sheet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on _BackupCancelledException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup cancelled.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup/Restore'),
        backgroundColor: const Color.fromARGB(255, 187, 40, 30),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup To Google Drive',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Creates a local JSON backup file from your app data and opens the share sheet so you can save it to Google Drive.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isBackingUp ? null : _backupAndUpload,
                      icon: _isBackingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                        _isBackingUp
                            ? 'Backing up...'
                            : 'Create Backup And Send To Drive',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restore From Backup File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a backup JSON file from Google Drive, OneDrive, or local storage and restore your shopping data.',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isRestoring ? null : _pickAndRestoreBackup,
                      icon: _isRestoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                      label: Text(
                        _isRestoring
                            ? 'Restoring...'
                            : 'Choose Backup File And Restore',
                      ),
                    ),
                    if (_lastRestoreFileName != null ||
                        _lastRestoreMessage != null) ...[
                      const SizedBox(height: 12),
                      if (_lastRestoreFileName != null)
                        Text('File: $_lastRestoreFileName'),
                      if (_lastRestoreMessage != null)
                        Text(_lastRestoreMessage!),
                    ],
                  ],
                ),
              ),
            ),
            if (_lastBackupPath != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Backup',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Local file: $_lastBackupPath'),
                      if (_lastActionMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(_lastActionMessage!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupCancelledException implements Exception {
  const _BackupCancelledException();
}
