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
  Map<String, Map<String, dynamic>> _lastMessages =
      {}; // NEW: Map<PeerId, MessageData>
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

      // Fetch recent messages for previews
      final messages = await supabase
          .from('messages')
          .select('id, sender_id, receiver_id, content, created_at, read_at')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: false)
          .limit(200);

      final newLastMessages = <String, Map<String, dynamic>>{};
      for (final msg in messages) {
        final otherId =
            (msg['sender_id'] == myId) ? msg['receiver_id'] : msg['sender_id'];

        // Only store the FIRST (latest) message encountered for each peer
        if (!newLastMessages.containsKey(otherId) &&
            otherUserIds.contains(otherId)) {
          newLastMessages[otherId] = msg;
        }
      }

      // Fetch unread requests count
      final requestsCount = await supabase
          .from('collab_requests')
          .count(CountOption.exact)
          .eq('receiver_id', myId)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _connections = profiles.map((p) => UserProfile.fromJson(p)).toList();
          _connectionIds = newConnectionMap;
          _lastMessages = newLastMessages;

          // Sort by Last Message Time (Recent first)
          _connections.sort((a, b) {
            final timeAStr = _lastMessages[a.userId]?['created_at'];
            final timeBStr = _lastMessages[b.userId]?['created_at'];
            if (timeAStr == null && timeBStr == null) return 0;
            if (timeAStr == null) {
              return 1; // B has message, A doesn't -> B first
            }
            if (timeBStr == null) return -1;
            return DateTime.parse(timeBStr).compareTo(DateTime.parse(timeAStr));
          });

          _applyFilter();
          _isLoading = false;
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
        backgroundColor: Theme.of(context).cardTheme.color,
        title: Text('Remove Connection?',
            style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          'Are you sure you want to remove ${user.fullName ?? user.intentTag ?? "this user"} from your connections?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Theme.of(context).disabledColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Connections',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        actions: [
          // Requests Icon (New)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: theme.primaryColor),
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
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
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
                  color: theme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor),
                ),
                child: Text(
                  '${_connections.length}',
                  style: TextStyle(
                    color: theme.primaryColor,
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
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search connections...',
                hintStyle: TextStyle(
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                filled: true,
                fillColor: theme.cardTheme.color,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.1)),
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
                _buildFilterChip(context, 'All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'Students', 'students'),
                const SizedBox(width: 8),
                _buildFilterChip(context, 'Tutors', 'tutors'),
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
                            return _buildConnectionCard(context, conn);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          hapticService.lightImpact();
          setState(() {
            _filter = value;
            _applyFilter();
          });
        }
      },
      backgroundColor: theme.cardTheme.color,
      selectedColor: theme.primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected
            ? theme.primaryColor
            : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? theme.primaryColor
            : theme.dividerColor.withValues(alpha: 0.1),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildConnectionCard(BuildContext context, UserProfile conn) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Hero(
              tag: 'avatar_${conn.userId}',
              child: CircleAvatar(
                radius: 30,
                backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                backgroundImage: conn.avatarUrl != null
                    ? (conn.avatarUrl!.startsWith('assets/')
                        ? AssetImage(conn.avatarUrl!) as ImageProvider
                        : NetworkImage(conn.avatarUrl!))
                    : null,
                child: conn.avatarUrl == null
                    ? Icon(
                        conn.isTutor ? Icons.school : Icons.person,
                        color: conn.isTutor ? Colors.amber : theme.primaryColor,
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
                          style: theme.textTheme.titleMedium?.copyWith(
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
                              ? Colors.amber.withValues(alpha: 0.2)
                              : theme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          conn.isTutor ? 'TUTOR' : 'STUDENT',
                          style: TextStyle(
                            color: conn.isTutor
                                ? Colors.amber
                                : theme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Message Preview
                  if (_lastMessages.containsKey(conn.userId)) ...[
                    Text(
                      _lastMessages[conn.userId]!['content'] ?? 'Sent an image',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _isUnread(_lastMessages[conn.userId]!)
                            ? theme.textTheme.bodyMedium?.color
                            : theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: _isUnread(_lastMessages[conn.userId]!)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      conn.intentTag ?? 'No status',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Time & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_lastMessages.containsKey(conn.userId))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 8),
                    child: Text(
                      _formatTime(_lastMessages[conn.userId]!['created_at']),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.5),
                          fontSize: 10),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Log Session Button
                    if (!conn.isTutor)
                      IconButton(
                        icon: const Icon(Icons.class_, color: Colors.amber),
                        tooltip: "Log Session",
                        onPressed: () => _logSession(conn),
                      ),
                    IconButton(
                      icon: Icon(Icons.chat_bubble, color: theme.primaryColor),
                      onPressed: () {
                        hapticService.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(otherUser: conn),
                          ),
                        ).then((_) => _fetchConnections()); // Refresh on return
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.person_remove,
                          color: theme.colorScheme.error),
                      onPressed: () {
                        hapticService.mediumImpact();
                        _removeConnection(conn);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isUnread(Map<String, dynamic> msg) {
    final myId = supabase.auth.currentUser?.id;
    return msg['receiver_id'] == myId && msg['read_at'] == null;
  }

  String _formatTime(String isoString) {
    final date = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }

  Future<void> _logSession(UserProfile student) async {
    final theme = Theme.of(context);
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    hapticService.mediumImpact();

    // Optimistic UI / Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color,
        title: Text('Log Session?', style: theme.textTheme.titleLarge),
        content: Text(
          'Confirm that you have completed a session with ${student.fullName ?? "this student"}.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.disabledColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('sessions').insert({
        'tutor_id': myId,
        'student_id': student.userId,
        'source': 'manual',
      });

      if (mounted) {
        showSuccessSnackBar(context, 'Session logged successfully!');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to log session: $e');
      }
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
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
            color: theme.iconTheme.color?.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send collaboration requests to build your network!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
