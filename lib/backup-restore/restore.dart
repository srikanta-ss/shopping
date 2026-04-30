import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RestoreBackupPage extends StatefulWidget {
  const RestoreBackupPage({super.key});

  @override
  State<RestoreBackupPage> createState() => _RestoreBackupPageState();
}

class _RestoreBackupPageState extends State<RestoreBackupPage> {
  bool _isRestoring = false;
  String? _selectedFileName;
  String? _statusMessage;

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
      final stringList = value.map((e) => e.toString()).toList();
      await prefs.setStringList(key, stringList);
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
      _statusMessage = null;
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
        _selectedFileName = selected.name;
        _statusMessage =
            'Restore complete. Restored $restoredCount data entries from ${selected.name}.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore completed successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Restore failed: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Backup'),
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
                      'Restore From File',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a backup JSON file from Google Drive, OneDrive, or local storage. Existing shopping data will be replaced by backup data.',
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
                          : const Icon(Icons.folder_open),
                      label: Text(
                        _isRestoring ? 'Restoring...' : 'Choose Backup File',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedFileName != null || _statusMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Restore',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 8),
                        Text('File: $_selectedFileName'),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(_statusMessage!),
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
