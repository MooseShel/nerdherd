import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'models/user_profile.dart'; // Ensure this matches your project structure
import 'requests_page.dart';
import 'connections_page.dart';
import 'settings_page.dart';
import 'services/logger_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _intentController = TextEditingController();
  final _classesController = TextEditingController(); // Comma separated
  final _avatarController = TextEditingController();
  bool _isTutor = false;
  bool _isLoading = true;
  int _connectionCount = 0;
  int _pendingRequestCount = 0;

  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchConnectionCount();
    _fetchPendingRequestCount();
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
        setState(() {
          _isTutor = profile.isTutor;
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
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A), // Matches drawer theme
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
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
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white10,
                          backgroundImage: _avatarController.text.isNotEmpty
                              ? NetworkImage(_avatarController.text)
                              : null,
                          child: _avatarController.text.isEmpty
                              ? const Icon(Icons.person,
                                  size: 60, color: Colors.white54)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.cyanAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
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
                      child: const Text("Change Photo",
                          style: TextStyle(color: Colors.cyanAccent)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('Full Name'),
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration('e.g. John Doe'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Status / Intent'),
                  TextField(
                    controller: _intentController,
                    decoration: _inputDecoration('e.g. Studying Calculus'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Current Classes (comma separated)'),
                  TextField(
                    controller: _classesController,
                    decoration: _inputDecoration('e.g. CS101, MATH200'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  // Avatar URL (Hidden or Optional Manual Input)
                  ExpansionTile(
                    title: const Text("Advanced: Manual Avatar URL",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    children: [
                      TextField(
                        controller: _avatarController,
                        decoration: _inputDecoration('https://...'),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (val) => setState(() {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'I am a Tutor',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: _isTutor,
                        onChanged: (val) => setState(() => _isTutor = val),
                        activeColor: Colors.amber,
                        activeTrackColor: Colors.amberAccent.withOpacity(0.5),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.white12,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // My Connections Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ConnectionsPage()),
                        );
                        // Refresh counts when returning
                        _fetchConnectionCount();
                      },
                      icon: const Icon(Icons.people),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("My Connections"),
                          if (_connectionCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_connectionCount',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Requests Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RequestsPage()),
                        );
                        // Refresh counts when returning
                        _fetchPendingRequestCount();
                      },
                      icon: const Icon(Icons.notifications_active),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Manage Requests"),
                          if (_pendingRequestCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_pendingRequestCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
