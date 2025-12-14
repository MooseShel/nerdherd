import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/haptic_service.dart';
import 'widgets/ui_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  bool _ghostMode = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ghostMode = prefs.getBool('ghost_mode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _changePassword() async {
    hapticService.mediumImpact();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Change Password',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'New Password',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPass = passwordController.text.trim();
              if (newPass.length < 6) {
                // Using context (from State) here is safe because we haven't done async yet?
                // Actually this is synchronous so fine.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password must be at least 6 characters')),
                );
                return;
              }
              Navigator.pop(dialogContext); // Close dialog first

              try {
                await supabase.auth
                    .updateUser(UserAttributes(password: newPass));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password updated successfully!'),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    hapticService.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF0F111A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'PRIVACY'),
          SettingsTile(
            icon: Icons.visibility_off,
            title: 'Ghost Mode',
            subtitle: 'Hide your location from everyone',
            trailing: Switch(
              value: _ghostMode,
              onChanged: (val) {
                hapticService.selectionClick();
                setState(() => _ghostMode = val);
                _saveSetting('ghost_mode', val);
              },
              activeColor: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'NOTIFICATIONS'),
          SettingsTile(
            icon: Icons.notifications,
            title: 'Push Notifications',
            subtitle: 'Requests, messages, and tips',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (val) {
                hapticService.selectionClick();
                setState(() => _notificationsEnabled = val);
                _saveSetting('notifications_enabled', val);
              },
              activeColor: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'ACCOUNT'),
          SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: _changePassword,
          ),
          SettingsTile(
            icon: Icons.logout,
            title: 'Sign Out',
            titleColor: Colors.redAccent,
            iconColor: Colors.redAccent,
            onTap: _signOut,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }
}
