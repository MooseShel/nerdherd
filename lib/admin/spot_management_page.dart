import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/study_spot.dart';

class SpotManagementPage extends StatefulWidget {
  const SpotManagementPage({super.key});

  @override
  State<SpotManagementPage> createState() => _SpotManagementPageState();
}

class _SpotManagementPageState extends State<SpotManagementPage> {
  final supabase = Supabase.instance.client;
  List<StudySpot> _spots = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSpots();
  }

  Future<void> _fetchSpots() async {
    try {
      setState(() => _isLoading = true);
      // Fetch only supabase source spots for management usually, but let's fetch all we have in DB
      final response = await supabase
          .from('study_spots')
          .select()
          .order('created_at',
              ascending: false) // Assuming created_at exists, else remove order
          .limit(50);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _spots = data.map((json) => StudySpot.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      // created_at might not exist in study_spots based on previous knowledge, safely fallback
      try {
        final response = await supabase.from('study_spots').select().limit(50);
        final List<dynamic> data = response;
        if (mounted) {
          setState(() {
            _spots = data.map((json) => StudySpot.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } catch (innerE) {
        debugPrint('Error fetching spots: $innerE');
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSpot(String spotId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Spot?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await supabase.from('study_spots').delete().eq('id', spotId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Spot deleted')));
          _fetchSpots();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _showEditDialog(StudySpot spot) async {
    final nameController = TextEditingController(text: spot.name);
    final typeController = TextEditingController(text: spot.type);
    final imageController = TextEditingController(text: spot.imageUrl);
    bool isVerified = spot.isVerified;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Spot'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                        labelText: 'Type (cafe, library...)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Verified Spot'),
                    subtitle: const Text('Show with Gold Icon'),
                    value: isVerified,
                    onChanged: (val) => setState(() => isVerified = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      try {
        await supabase.from('study_spots').update({
          'name': nameController.text,
          'type': typeController.text,
          'image_url':
              imageController.text.isNotEmpty ? imageController.text : null,
          'is_verified': isVerified,
        }).eq('id', spot.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Spot updated successfully')));
          _fetchSpots();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error updating spot: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredSpots = _spots.where((spot) {
      return spot.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search,
                  color: theme.iconTheme.color?.withValues(alpha: 0.5)),
              hintText: 'Search spots...',
              hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredSpots.isEmpty
                  ? Center(
                      child: Text('No study spots found',
                          style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      itemCount: filteredSpots.length,
                      itemBuilder: (context, index) {
                        final spot = filteredSpots[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.1)),
                          ),
                          child: ListTile(
                            leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: theme.primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    image: spot.imageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(spot.imageUrl!),
                                            fit: BoxFit.cover)
                                        : null),
                                child: spot.imageUrl == null
                                    ? Icon(Icons.place,
                                        color: theme.primaryColor)
                                    : null),
                            title: Text(spot.name,
                                style: theme.textTheme.titleMedium),
                            subtitle: Text(
                                '${spot.type.toUpperCase()} • ${spot.source.toUpperCase()}'
                                '${spot.isVerified ? ' • Verified' : ''}',
                                style: theme.textTheme.bodySmall),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: theme.primaryColor),
                                  onPressed: () => _showEditDialog(spot),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () => _deleteSpot(spot.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
