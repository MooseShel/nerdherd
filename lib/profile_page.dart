import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/user_profile.dart'; // Ensure this matches your project structure
import 'requests_page.dart';
import 'connections_page.dart';
import 'settings_page.dart';
import 'schedule_page.dart';
import 'services/logger_service.dart';
import 'university/university_selection_page.dart';
import 'conversations_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/wallet_provider.dart';
import 'wallet_page.dart';
import 'package:intl/intl.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _intentController = TextEditingController();
  final _classesController = TextEditingController(); // Comma separated
  final _avatarController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isTutor = false;
  bool _isLoading = true;
  int _connectionCount = 0;
  int _pendingRequestCount = 0;
  String? _verificationDocUrl;
  String _verificationStatus = 'pending';

  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchConnectionCount();
    _fetchReviewStats();
  }

  double _averageRating = 0.0;
  int _reviewCount = 0;

  Future<void> _fetchReviewStats() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final data = await supabase
          .from('reviews')
          .select('rating')
          .eq('reviewee_id', myId);

      if (data.isNotEmpty) {
        final List<dynamic> ratings = data.map((e) => e['rating']).toList();
        final sum =
            ratings.fold(0, (previous, current) => previous + (current as int));
        setState(() {
          _averageRating = sum / ratings.length;
          _reviewCount = ratings.length;
        });
      }
    } catch (e) {
      logger.error("Error fetching review stats", error: e);
    }
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        final profile = UserProfile.fromJson(data);
        _nameController.text = profile.fullName ?? '';
        _intentController.text = profile.intentTag ?? '';
        _classesController.text = profile.currentClasses.join(', ');
        _avatarController.text = profile.avatarUrl ?? '';
        _hourlyRateController.text = profile.hourlyRate?.toString() ?? '';
        _bioController.text = profile.bio ?? '';
        setState(() {
          _isTutor = profile.isTutor;
          _verificationDocUrl = profile.verificationDocumentUrl;
          _verificationStatus = profile.verificationStatus;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Could not load profile. Please refresh.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      await _uploadImage(image);
    } catch (e) {
      if (mounted) {
        _showSnack('Could not pick image. Please try again.', isError: true);
      }
    }
  }

  Future<void> _uploadImage(XFile image) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: image.mimeType),
          );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      setState(() {
        _avatarController.text = imageUrl;
      });

      if (mounted) {
        _showSnack('Image uploaded! Remember to Save.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        // Show the raw error to help debugging
        _showSnack('Upload failed: $msg', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1. Validation Logic
    final intent = _intentController.text.trim();
    if (intent.isEmpty) {
      _showSnack('Please enter your Status/Intent (e.g., "Studying Calculus").',
          isError: true);
      return;
    }

    final avatarUrl = _avatarController.text.trim();
    if (avatarUrl.isEmpty) {
      _showSnack('Profile picture not found. Please upload a photo.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Parse classes
    final classesList = _classesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      await supabase.from('profiles').upsert({
        'user_id': user.id,
        'full_name': _nameController.text.trim(),
        'intent_tag': intent,
        'current_classes': classesList,
        'is_tutor': _isTutor,
        'avatar_url': avatarUrl,
        'bio': _bioController.text.trim(),
        'hourly_rate': _isTutor && _hourlyRateController.text.isNotEmpty
            ? int.tryParse(_hourlyRateController.text.trim())
            : null,
        'verification_document_url': _verificationDocUrl,
        // We don't reset status here, but we could if doc changes.
        // For now, let's just keep it as is.
        'last_updated': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnack('Profile saved successfully!', isError: false);
        Navigator.pop(context); // Return to map
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Save failed: ${e.toString()}', isError: true);
        logger.error('Error saving profile', error: e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchConnectionCount() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final data = await supabase
          .from('connections')
          .select('id')
          .or('user_id_1.eq.$myId,user_id_2.eq.$myId');

      setState(() {
        _connectionCount = data.length;
      });
    } catch (e) {
      logger.error("Error fetching connection count", error: e);
    }
  }

  Future<void> _fetchPendingRequestCount() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final data = await supabase
          .from('collab_requests')
          .select('id')
          .eq('receiver_id', myId)
          .eq('status', 'pending');

      setState(() {
        _pendingRequestCount = data.length;
      });
    } catch (e) {
      logger.error("Error fetching request count", error: e);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.tertiary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showHelpDialog() async {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Center'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How can we help you today?'),
            const SizedBox(height: 16),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                  labelText: 'Subject', hintText: 'Bug, Billing, etc.'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                  labelText: 'Message', hintText: 'Describe your issue...'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white),
            child: const Text('Submit Ticket'),
          ),
        ],
      ),
    );

    if (result == true &&
        subjectController.text.isNotEmpty &&
        messageController.text.isNotEmpty) {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      try {
        await supabase.from('support_tickets').insert({
          'user_id': user.id,
          'subject': subjectController.text.trim(),
          'message': messageController.text.trim(),
          'status': 'open',
        });
        if (mounted) {
          _showSnack('Support ticket submitted! We will contact you soon.',
              isError: false);
        }
      } catch (e) {
        if (mounted) _showSnack('Error submitting ticket: $e', isError: true);
      }
    }
  }

  Future<void> _pickVerificationDoc() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName =
          '${user.id}/verification_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('verification_docs').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: image.mimeType),
          );

      final docUrl =
          supabase.storage.from('verification_docs').getPublicUrl(fileName);

      setState(() {
        _verificationDocUrl = docUrl;
        _verificationStatus = 'pending'; // Reset status if new doc uploaded
      });

      if (mounted) {
        _showSnack('Verification document uploaded! Remember to Save.',
            isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Edit Profile',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: theme.iconTheme.color),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Section
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isTutor
                                        ? Colors.amber
                                        : theme.primaryColor)
                                    .withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: theme.cardTheme.color,
                            backgroundImage: _avatarController.text.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    _avatarController.text)
                                : null,
                            child: _avatarController.text.isEmpty
                                ? Icon(Icons.person,
                                    size: 60,
                                    color: theme.iconTheme.color
                                        ?.withValues(alpha: 0.5))
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: theme.scaffoldBackgroundColor,
                                    width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _pickImage,
                      child: Text("Change Photo",
                          style: TextStyle(color: theme.primaryColor)),
                    ),
                  ),
                  if (_reviewCount > 0) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "($_reviewCount Reviews)",
                              style: TextStyle(
                                  color: theme.textTheme.bodySmall?.color,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildLabel(context, 'Full Name'),
                  _buildTextField(context,
                      controller: _nameController, hint: 'e.g. John Doe'),
                  const SizedBox(height: 20),

                  _buildLabel(context, 'Status / Intent'),
                  _buildTextField(context,
                      controller: _intentController,
                      hint: 'e.g. Studying Calculus'),
                  const SizedBox(height: 20),

                  _buildLabel(context, 'Current Classes'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          context,
                          controller: _classesController,
                          hint: 'No classes imported',
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.school),
                        color: theme.primaryColor,
                        tooltip: 'Import from University',
                        onPressed: () async {
                          // Navigate to University Selection
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const UniversitySelectionPage()));
                          // Refresh profile on return to seeing updated classes
                          _loadProfile();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Avatar URL (Hidden or Optional Manual Input)
                  ExpansionTile(
                    title: Text("Advanced: Manual Avatar URL",
                        style: theme.textTheme.bodySmall),
                    children: [
                      _buildTextField(context,
                          controller: _avatarController,
                          hint: 'https://...',
                          onChanged: (val) => setState(() {})),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'I am a Tutor',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: _isTutor,
                        onChanged: (val) => setState(() => _isTutor = val),
                        activeThumbColor: Colors.amber,
                      ),
                    ],
                  ),

                  if (_isTutor) ...[
                    const SizedBox(height: 20),
                    _buildLabel(context, 'Hourly Rate (\$/hr)'),
                    _buildTextField(context,
                        controller: _hourlyRateController,
                        hint: 'e.g. 25',
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 24),
                    _buildLabel(context, 'Tutor Verification'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Status:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_verificationStatus == 'verified'
                                          ? Colors.green
                                          : _verificationStatus == 'rejected'
                                              ? Colors.red
                                              : Colors.orange)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _verificationStatus.toUpperCase(),
                                  style: TextStyle(
                                    color: _verificationStatus == 'verified'
                                        ? Colors.green
                                        : _verificationStatus == 'rejected'
                                            ? Colors.red
                                            : Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_verificationDocUrl != null) ...[
                            const Text('Verification Document:',
                                style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: _verificationDocUrl!,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _pickVerificationDoc,
                              icon: const Icon(Icons.upload_file),
                              label: Text(_verificationDocUrl == null
                                  ? 'Upload ID / Certificate'
                                  : 'Update Document'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _buildLabel(context, 'Bio / About Me'),
                  _buildTextField(context,
                      controller: _bioController,
                      hint: 'Tell others about yourself...',
                      maxLines: 4),

                  const SizedBox(height: 32),

                  // Wallet Button
                  Consumer(
                    builder: (context, ref, child) {
                      final balanceAsync = ref.watch(walletBalanceProvider);
                      return _buildMenuButton(
                        context,
                        icon: Icons.account_balance_wallet_outlined,
                        label: "My Wallet",
                        count: balanceAsync.maybeWhen(
                          data: (val) => null, // We'll show text instead
                          orElse: () => null,
                        ),
                        trailing: balanceAsync.when(
                          data: (val) => Text(
                            "\$${NumberFormat('#,##0.00').format(val)}",
                            style: TextStyle(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          error: (_, __) => const Text("\$ --"),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const WalletPage()),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // My Connections Button
                  _buildMenuButton(
                    context,
                    icon: Icons.people,
                    label: "My Connections",
                    count: _connectionCount,
                    countColor: theme.primaryColor,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ConnectionsPage()),
                      );
                      _fetchConnectionCount();
                    },
                  ),

                  const SizedBox(height: 16),

                  // Requests Button
                  _buildMenuButton(
                    context,
                    icon: Icons.notifications_active,
                    label: "Manage Requests",
                    count: _pendingRequestCount,
                    countColor: theme.colorScheme.error,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RequestsPage()),
                      );
                      _fetchPendingRequestCount();
                    },
                  ),

                  const SizedBox(height: 16),

                  // My Chats Button
                  _buildMenuButton(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: "My Chats",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ConversationsPage()),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // My Schedule Button
                  _buildMenuButton(
                    context,
                    icon: Icons.calendar_today,
                    label: "My Schedule",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SchedulePage()),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Help Center Button
                  _buildMenuButton(
                    context,
                    icon: Icons.help_outline,
                    label: "Help Center",
                    onTap: _showHelpDialog,
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(BuildContext context,
      {required TextEditingController controller,
      required String hint,
      TextInputType? keyboardType,
      int maxLines = 1,
      bool readOnly = false,
      Function(String)? onChanged}) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
        filled: true,
        fillColor:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? count,
    Color? countColor,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.iconTheme.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: countColor?.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: countColor ?? Colors.grey)),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: countColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (trailing != null) trailing,
            if (trailing == null)
              Icon(Icons.chevron_right,
                  size: 16,
                  color: theme.iconTheme.color?.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
