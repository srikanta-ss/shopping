import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'shopping_sublist.dart';

class ShoppingHome extends StatefulWidget {
  const ShoppingHome({super.key});

  @override
  State<ShoppingHome> createState() => _ShoppingHomeState();
}

class _ShoppingHomeState extends State<ShoppingHome> {
  final TextEditingController _nameController = TextEditingController();
  List<String> _shoppingLists = [];

  String _sublistPrefsKey(String listName) => 'sublist_items_$listName';

  Future<void> _migrateSublistItems({
    required String fromListName,
    required String toListName,
  }) async {
    if (fromListName == toListName) return;
    final prefs = await SharedPreferences.getInstance();
    final oldKey = _sublistPrefsKey(fromListName);
    final newKey = _sublistPrefsKey(toListName);

    final oldItems = prefs.getStringList(oldKey);
    if (oldItems == null) return;

    // Defensive: if the new key already exists (e.g., stale data), merge.
    final existing = prefs.getStringList(newKey);
    if (existing == null || existing.isEmpty) {
      await prefs.setStringList(newKey, oldItems);
    } else {
      await prefs.setStringList(newKey, [...existing, ...oldItems]);
    }
    await prefs.remove(oldKey);
  }

  @override
  void initState() {
    super.initState();
    _loadShoppingLists();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadShoppingLists() async {
    final prefs = await SharedPreferences.getInstance();
    final lists = prefs.getStringList('shopping_lists') ?? [];
    setState(() {
      _shoppingLists = lists;
    });
  }

  Future<void> _saveShoppingLists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('shopping_lists', _shoppingLists);
  }

  Future<void> _editList(int index) async {
    final originalName = _shoppingLists[index];
    _nameController.text = originalName;
    final newName = await showDialog<String?>(
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
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: Colors.purple.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit List Name',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Update your list name',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter list name',
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
                        color: Colors.purple.shade700,
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
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_nameController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
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

    if (newName != null && newName.isNotEmpty && newName != originalName) {
      final nameAlreadyExists = _shoppingLists.asMap().entries.any(
        (e) => e.key != index && e.value == newName,
      );
      if (nameAlreadyExists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('List already exists: $newName')),
        );
        return;
      }

      await _migrateSublistItems(
        fromListName: originalName,
        toListName: newName,
      );
      setState(() {
        _shoppingLists[index] = newName;
      });
      await _saveShoppingLists();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Renamed to: $newName')));
    }
  }

  void _showItemActionsDialog(int index) {
    final listName = _shoppingLists[index];
    showDialog<void>(
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
                              listName.isEmpty ? 'List Options' : listName,
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
                              onTap: () async {
                                Navigator.of(context).pop();
                                await _editList(index);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.delete_outline,
                              label: 'Delete',
                              color: Colors.red.shade600,
                              onTap: () async {
                                Navigator.of(context).pop();
                                await _deleteList(index);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final String item = _shoppingLists.removeAt(oldIndex);
      _shoppingLists.insert(newIndex, item);
    });
    _saveShoppingLists();
  }

  Future<void> _deleteList(int index) async {
    final listName = _shoppingLists[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "$listName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sublistPrefsKey(listName));
      setState(() {
        _shoppingLists.removeAt(index);
      });
      await _saveShoppingLists();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted: $listName')));
    }
  }

  void _showCreateListDialog() {
    _nameController.clear();
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enter List Name'),
              content: TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'List name'),
                onChanged: (_) => setState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _nameController.text.trim().isEmpty
                      ? null
                      : () async {
                          final name = _nameController.text.trim();
                          Navigator.of(context).pop();

                          // Update the main widget's state after closing the dialog
                          this.setState(() {
                            _shoppingLists.insert(0, name);
                          });
                          await _saveShoppingLists();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Created list: $name')),
                          );
                        },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 187, 40, 30),
        title: const Text(
          'Shopping List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Exit App',
            icon: const Icon(Icons.exit_to_app),
            onPressed: _confirmExit,
          ),
        ],
      ),
      body: _shoppingLists.isEmpty
          ? const Center(
              child: Text(
                'No shopping lists yet!\nTap the + button to create your first list.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _shoppingLists.length,
              onReorder: _onReorder,
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                final listName = _shoppingLists[index];
                return Card(
                  key: ValueKey(listName),
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: const Color.fromARGB(255, 252, 255, 172),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    leading: const Icon(Icons.shopping_cart, color: Colors.red),
                    title: Text(
                      listName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ShoppingSublistPage(listName: listName),
                        ),
                      );
                    },
                    onLongPress: () {
                      _showItemActionsDialog(index);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateListDialog,
        backgroundColor: const Color.fromARGB(255, 187, 40, 30),
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmExit() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        color: Colors.red.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exit Application',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Are you sure you want to exit?',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey.withOpacity(0.2),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                        'No',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Yes',
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
  }
}
