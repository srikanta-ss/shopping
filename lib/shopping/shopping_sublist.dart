import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShoppingSublistPage extends StatefulWidget {
  final String listName;

  const ShoppingSublistPage({super.key, required this.listName});

  @override
  State<ShoppingSublistPage> createState() => _ShoppingSublistPageState();
}

class _ShoppingSublistPageState extends State<ShoppingSublistPage> {
  final TextEditingController _itemController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  // Each item is stored as a map: {'title': String, 'done': bool}
  List<Map<String, dynamic>> _items = [];

  num get _totalCheckedAmount => _items
      .where((m) => (m['done'] as bool? ?? false) && m['amount'] is num)
      .fold<num>(0, (sum, m) => sum + (m['amount'] as num));
  int get _checkedCount =>
      _items.where((m) => (m['done'] as bool? ?? false)).length;

  String _formatAmount(num value) {
    // Show integers without decimal; others with 2 decimals. Prefix with rupee symbol.
    final formatted = (value is int || value == value.roundToDouble())
        ? value.toString()
        : value.toStringAsFixed(2);
    return '₹ $formatted';
  }

  String get _prefsKey => 'sublist_items_${widget.listName}';

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln(widget.listName);
    buffer.writeln();

    var serial = 0;
    for (final item in _items) {
      final title = (item['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;
      serial += 1;
      final done = item['done'] as bool? ?? false;
      final hasAmount = item['amount'] is num;
      final amount = hasAmount ? item['amount'] as num : null;

      if (done && hasAmount) {
        buffer.writeln('$serial. $title - ${_formatAmount(amount!)}');
      } else {
        buffer.writeln('$serial. $title');
      }
    }

    buffer.writeln();
    buffer.writeln('Total items: ${_items.length}');
    buffer.writeln('Total amount: ${_formatAmount(_totalCheckedAmount)}');
    return buffer.toString();
  }

  Future<void> _shareList() async {
    if (_items.isEmpty) return;
    final text = _buildShareText();
    await Share.share(text);
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    setState(() {
      _items = list
          .map((s) => Map<String, dynamic>.from(json.decode(s) as Map))
          .toList();
      _resortItems();
    });
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _items.map((m) => json.encode(m)).toList();
    await prefs.setStringList(_prefsKey, encoded);
  }

  Future<void> _addItem() async {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.insert(0, {'title': text, 'done': false, 'amount': 0});
      _resortItems();
    });
    _itemController.clear();
    await _saveItems();
    _inputFocusNode.requestFocus();
  }

  Future<void> _deleteItem(int index) async {
    final removed = _items.removeAt(index);
    setState(() {});
    await _saveItems();
    if (!mounted) return;
    final title = removed['title'] as String? ?? '';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Removed: $title')));
  }

  Future<void> _toggleDone(int index, bool? value) async {
    if (value == null) return;
    final current = _items[index];
    // Checkbox toggling should only update completion state.
    setState(() {
      current['done'] = value;
      if (!value) {
        current['amount'] = null; // clear amount when item is unchecked
      }
      _resortItems();
    });
    await _saveItems();
  }

  Future<num?> _promptAmount({dynamic initial}) async {
    final controller = TextEditingController(
      text: (initial is num && initial != 0) ? initial.toString() : '',
    );
    final result = await showDialog<num?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.currency_rupee_rounded,
                        color: Colors.green.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter Amount',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enter the price for this item',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.green.shade700,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) {
                    final trimmed = v.trim();
                    final n = trimmed.isEmpty ? 0 : num.tryParse(trimmed);
                    Navigator.of(context).pop(n ?? 0);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final v = controller.text.trim();
                        final n = v.isEmpty ? 0 : num.tryParse(v);
                        Navigator.of(context).pop(n ?? 0);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }

  Future<void> _showItemActions(int index) async {
    final item = _items[index];
    final title = item['title'] as String? ?? '';
    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'Item Options' : title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Select an option',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              color: Colors.blue.shade600,
                              onTap: () => Navigator.of(context).pop('edit'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.delete_outline,
                              label: 'Delete',
                              color: Colors.red.shade600,
                              onTap: () => Navigator.of(context).pop('delete'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop('cancel'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
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
    if (choice == 'edit') {
      await _editItem(index);
    } else if (choice == 'delete') {
      await _deleteItem(index);
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editItem(int index) async {
    final current = _items[index];
    final controller = TextEditingController(
      text: current['title'] as String? ?? '',
    );
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.orange.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Item',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Update the item name',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter item name',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.orange.shade700,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (newTitle == null) return;
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      current['title'] = trimmed;
    });
    await _saveItems();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Updated: $trimmed')));
  }

  Future<void> _confirmDeleteCompleted() async {
    final hasCompleted = _items.any((m) => (m['done'] as bool? ?? false));
    if (!hasCompleted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed items to delete.')),
      );
      return;
    }
    final completedCount = _items
        .where((m) => (m["done"] as bool? ?? false))
        .length;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.red.shade700,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete completed items?',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This will permanently remove all checked items in this sublist. You can\'t undo this.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        '$completedCount item${completedCount == 1 ? '' : 's'} selected',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Delete $completedCount item${completedCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    setState(() {
      _items.removeWhere((m) => (m['done'] as bool? ?? false));
    });
    await _saveItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleted all completed items.')),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      // After a manual reorder, keep grouping (unchecked first, checked last)
      _resortItems();
    });
    _saveItems();
  }

  // Keep unchecked items first (preserve relative order within groups) then checked items.
  void _resortItems() {
    final unchecked = <Map<String, dynamic>>[];
    final checked = <Map<String, dynamic>>[];
    for (final m in _items) {
      final done = m['done'] as bool? ?? false;
      if (done) {
        checked.add(m);
      } else {
        unchecked.add(m);
      }
    }
    _items = [...unchecked, ...checked];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 187, 40, 30),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.listName,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Delete completed items',
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _confirmDeleteCompleted,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'No items yet. Add one below.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _items.length,
                    onReorder: _onReorder,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      // Provide a Material ancestor to support Checkbox during drag; solid blue background.
                      return Material(
                        color: Colors.blue.shade200,
                        elevation: 2,
                        borderRadius: BorderRadius.circular(4),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final title = item['title'] as String? ?? '';
                      final done = item['done'] as bool? ?? false;
                      final hasAmount = item['amount'] is num;
                      final amount = hasAmount ? item['amount'] as num : null;
                      return Column(
                        key: ValueKey('$title-$index'),
                        children: [
                          InkWell(
                            onTap: () async {
                              // Tapping the item should prompt for amount update.
                              final newAmount = await _promptAmount(
                                initial: item['amount'],
                              );
                              if (newAmount == null) return;
                              setState(() {
                                item['amount'] = newAmount;
                                // If not already completed, mark as done when amount is set.
                                if (!(item['done'] as bool? ?? false)) {
                                  item['done'] = true;
                                }
                                _resortItems();
                              });
                              await _saveItems();
                            },
                            onLongPress: () => _showItemActions(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Checkbox(
                                    value: done,
                                    onChanged: (v) => _toggleDone(index, v),
                                  ),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: done ? Colors.grey : null,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (done && hasAmount)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: done
                                            ? Colors.green.shade50
                                            : Colors.blue.shade50,
                                        border: Border.all(
                                          color: done
                                              ? Colors.green.shade200
                                              : Colors.blue.shade200,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _formatAmount(amount!),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: done
                                              ? Colors.green.shade800
                                              : Colors.blue.shade800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(
                                      Icons.drag_handle,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (index < _items.length - 1)
                            const Divider(height: 1, thickness: 1),
                        ],
                      );
                    },
                  ),
          ),
          // Total of checked items (professional row: label left, amount right)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Checked Amount ($_checkedCount)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _formatAmount(_totalCheckedAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  if (_items.isNotEmpty) ...[
                    SizedBox(
                      height: 48,
                      width: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                          backgroundColor: const Color.fromARGB(
                            255,
                            187,
                            40,
                            30,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _shareList,
                        child: const Icon(Icons.share),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      focusNode: _inputFocusNode,
                      controller: _itemController,
                      decoration: InputDecoration(
                        hintText: 'Add item',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor: Color.fromARGB(255, 187, 40, 30),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _addItem,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
