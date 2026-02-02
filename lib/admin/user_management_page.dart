import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final supabase = Supabase.instance.client;
  List<UserProfile> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      setState(() => _isLoading = true);
      // In a real app, use pagination. Fetching 50 recent users for now.
      final response = await supabase
          .from('profiles')
          .select()
          .order('last_updated', ascending: false)
          .limit(50);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _users = data.map((json) => UserProfile.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActiveStatus(UserProfile user) async {
    try {
      final newStatus = !user.isActive;
      await supabase
          .from('profiles')
          .update({'is_active': newStatus}).eq('user_id', user.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'User activated' : 'User deactivated'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
        _fetchUsers(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleBan(UserProfile user) async {
    try {
      final newStatus = !user.isBanned;
      await supabase
          .from('profiles')
          .update({'is_banned': newStatus}).eq('user_id', user.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'User banned' : 'User unbanned'),
            backgroundColor: newStatus ? Colors.redAccent : Colors.green,
          ),
        );
        _fetchUsers(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter locally for MVP
    final filteredUsers = _users.where((user) {
      final name = user.fullName?.toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
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
              hintText: 'Search users...',
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
              : filteredUsers.isEmpty
                  ? Center(
                      child: Text('No users found',
                          style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
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
                            onTap: () => _showUserDetails(user),
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(user.fullName?.substring(0, 1) ?? 'U')
                                  : null,
                            ),
                            title: Text(
                              user.fullName ?? 'Unknown User',
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              user.isBanned
                                  ? 'BANNED'
                                  : (!user.isActive
                                      ? 'INACTIVE'
                                      : (user.isTutor ? 'Tutor' : 'Student')),
                              style: TextStyle(
                                color: user.isBanned
                                    ? Colors.red
                                    : (!user.isActive
                                        ? Colors.grey
                                        : theme.textTheme.bodySmall?.color),
                                fontWeight: user.isBanned
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    user.isBanned
                                        ? Icons.check_circle_outline
                                        : Icons.block,
                                    color: user.isBanned
                                        ? Colors.green
                                        : Colors.redAccent,
                                  ),
                                  onPressed: () => _toggleBan(user),
                                ),
                                IconButton(
                                  icon: Icon(
                                    user.isActive
                                        ? Icons.person
                                        : Icons.person_off_outlined,
                                    color: user.isActive
                                        ? Colors.blueAccent
                                        : Colors.grey,
                                  ),
                                  tooltip: user.isActive
                                      ? 'Deactivate User'
                                      : 'Activate User',
                                  onPressed: () => _toggleActiveStatus(user),
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

  void _showUserDetails(UserProfile user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.fullName ?? 'User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.avatarUrl != null)
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(user.avatarUrl!),
                  ),
                ),
              const SizedBox(height: 16),
              _detailRow('ID', user.userId),
              if (user.universityId != null)
                _detailRow('University ID', user.universityId!),
              if (user.intentTag != null) _detailRow('Intent', user.intentTag!),
              if (user.bio != null) _detailRow('Bio', user.bio!),
              if (user.address != null) _detailRow('Address', user.address!),
              _detailRow('Role',
                  user.isTutor ? 'Tutor (\$${user.hourlyRate}/hr)' : 'Student'),
              _detailRow('Status', user.isBanned ? 'Banned' : 'Active'),
              _detailRow(
                  'Updated', user.lastUpdated?.toString().split(' ')[0] ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
