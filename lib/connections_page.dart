import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_profile.dart';
import 'chat_page.dart';
import 'requests_page.dart';
import 'widgets/ui_components.dart';
import 'widgets/skeleton_loader.dart';
import 'services/logger_service.dart';
import 'services/haptic_service.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});

  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final supabase = Supabase.instance.client;
  List<UserProfile> _connections = [];
  Map<String, String> _connectionIds = {}; // Map<OtherUserId, ConnectionRowId>
  List<UserProfile> _filteredConnections = [];
  bool _isLoading = true;
  int _unreadRequestCount = 0;
  String _filter = 'all'; // 'all', 'students', 'tutors'
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchConnections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchConnections() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _isLoading = true);
    try {
      // Fetch connections where I'm either user_id_1 or user_id_2
      // CHANGE: Select 'id' (primary key) as well
      final data = await supabase
          .from('connections')
          .select('id, user_id_1, user_id_2')
          .or('user_id_1.eq.$myId,user_id_2.eq.$myId');

      final newConnectionMap = <String, String>{};
      final otherUserIds = data.map((conn) {
        final otherId =
            (conn['user_id_1'] == myId) ? conn['user_id_2'] : conn['user_id_1'];

        // Store the mapping for deletion later
        newConnectionMap[otherId] = conn['id'];
        return otherId;
      }).toList();

      if (otherUserIds.isEmpty) {
        setState(() {
          _connections = [];
          _filteredConnections = [];
          _connectionIds = {};
          _isLoading = false;
        });
        return;
      }

      // Fetch profiles for all connected users
      final profiles = await supabase
          .from('profiles')
          .select()
          .inFilter('user_id', otherUserIds);

      setState(() {
        _connections = profiles.map((p) => UserProfile.fromJson(p)).toList();
        _connectionIds = newConnectionMap;
        _applyFilter();
        _isLoading = false;
      });

      // Fetch unread requests count
      final requestsCount = await supabase
          .from('collab_requests')
          .count(CountOption.exact)
          .eq('receiver_id', myId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _unreadRequestCount = requestsCount;
        });
      }
    } catch (e) {
      logger.error("Error fetching connections", error: e);
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackBar(context, 'Error loading connections: $e');
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredConnections = _connections.where((conn) {
        // Filter by type
        bool matchesType = _filter == 'all' ||
            (_filter == 'tutors' && conn.isTutor) ||
            (_filter == 'students' && !conn.isTutor);

        // Filter by search query
        bool matchesSearch = query.isEmpty ||
            (conn.fullName?.toLowerCase().contains(query) ?? false) ||
            (conn.intentTag?.toLowerCase().contains(query) ?? false);

        return matchesType && matchesSearch;
      }).toList();
    });
  }

  Future<void> _removeConnection(UserProfile user) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text('Remove Connection?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove ${user.fullName ?? user.intentTag ?? "this user"} from your connections?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final connectionId = _connectionIds[user.userId];
      if (connectionId == null) {
        throw "Connection ID not found locally";
      }

      // CHANGE: Delete by specific Row ID (Robust)
      await supabase.from('connections').delete().eq('id', connectionId);

      // Remove from local list
      setState(() {
        _connections.removeWhere((c) => c.userId == user.userId);
        _applyFilter();
      });

      if (mounted) {
        showSuccessSnackBar(context, 'Connection removed');
      }
    } catch (e) {
      logger.error("Error removing connection", error: e);
      if (mounted) {
        showErrorSnackBar(context, 'Failed to remove: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('My Connections'),
        backgroundColor: const Color(0xFF0F111A),
        foregroundColor: Colors.white,
        actions: [
          // Requests Icon (New)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.cyanAccent),
                onPressed: () async {
                  hapticService.mediumImpact();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RequestsPage()),
                  );
                  // Refresh connections/counts when returning
                  _fetchConnections();
                },
              ),
              if (_unreadRequestCount > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          // Connection count badge
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent),
                ),
                child: Text(
                  '${_connections.length}',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search connections...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Students', 'students'),
                const SizedBox(width: 8),
                _buildFilterChip('Tutors', 'tutors'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Connections List
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 8,
                    itemBuilder: (context, index) => const SkeletonListTile(),
                  )
                : _filteredConnections.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchConnections,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredConnections.length,
                          itemBuilder: (context, index) {
                            final conn = _filteredConnections[index];
                            return _buildConnectionCard(conn);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        hapticService.lightImpact();
        setState(() {
          _filter = value;
          _applyFilter();
        });
      },
      backgroundColor: Colors.white.withOpacity(0.05),
      selectedColor: Colors.cyanAccent.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.cyanAccent : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? Colors.cyanAccent : Colors.white24,
      ),
    );
  }

  Widget _buildConnectionCard(UserProfile conn) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Hero(
              tag: 'avatar_${conn.userId}',
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black54,
                backgroundImage: conn.avatarUrl != null
                    ? (conn.avatarUrl!.startsWith('assets/')
                        ? AssetImage(conn.avatarUrl!) as ImageProvider
                        : NetworkImage(conn.avatarUrl!))
                    : null,
                child: conn.avatarUrl == null
                    ? Icon(
                        conn.isTutor ? Icons.school : Icons.person,
                        color: conn.isTutor ? Colors.amber : Colors.cyanAccent,
                        size: 30,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          conn.fullName ?? conn.intentTag ?? 'Unknown User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: conn.isTutor
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.cyanAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          conn.isTutor ? 'TUTOR' : 'STUDENT',
                          style: TextStyle(
                            color:
                                conn.isTutor ? Colors.amber : Colors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conn.intentTag ?? 'No status',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chat button
                IconButton(
                  icon: const Icon(Icons.chat_bubble, color: Colors.cyanAccent),
                  onPressed: () {
                    hapticService.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(otherUser: conn),
                      ),
                    );
                  },
                ),
                // Remove button
                IconButton(
                  icon:
                      const Icon(Icons.person_remove, color: Colors.redAccent),
                  onPressed: () {
                    hapticService.mediumImpact();
                    _removeConnection(conn);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    if (_searchController.text.isNotEmpty) {
      message = 'No connections match your search';
    } else if (_filter == 'students') {
      message = 'No student connections yet';
    } else if (_filter == 'tutors') {
      message = 'No tutor connections yet';
    } else {
      message = 'No connections yet';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send collaboration requests to build your network!',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
