import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/haptic_service.dart';
import 'widgets/ui_components.dart';
import 'pay/wallet_page.dart';
import 'admin/admin_dashboard.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  bool _ghostMode = false;
  bool _notificationsEnabled = true;
  bool _isAdmin = false;

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

    // Check if user is admin
    final user = supabase.auth.currentUser;
    if (user != null) {
      final res = await supabase
          .from('profiles')
          .select('is_admin')
          .eq('user_id', user.id)
          .single();
      if (mounted && res['is_admin'] == true) {
        setState(() => _isAdmin = true);
      }
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _changePassword() async {
    hapticService.mediumImpact();
    final passwordController = TextEditingController();
    // Capture theme before async gap to avoid BuildContext issues if possible,
    // but showDialog provides a context. We will use Theme.of(context) inside builder.

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          title: Text('Change Password', style: theme.textTheme.titleLarge),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'New Password',
              hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5)),
              enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: theme.dividerColor.withOpacity(0.2)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.primaryColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text('Cancel', style: TextStyle(color: theme.disabledColor)),
            ),
            FilledButton(
              onPressed: () async {
                final newPass = passwordController.text.trim();
                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Password must be at least 6 characters',
                            style: TextStyle(color: theme.colorScheme.onError)),
                        backgroundColor: theme.colorScheme.error),
                  );
                  return;
                }
                Navigator.pop(dialogContext); // Close dialog first

                try {
                  await supabase.auth
                      .updateUser(UserAttributes(password: newPass));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: const Text('Password updated successfully!'),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e',
                              style:
                                  TextStyle(color: theme.colorScheme.onError)),
                          backgroundColor: theme.colorScheme.error),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    hapticService.mediumImpact();
    await showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          title: Text('Sign Out?', style: theme.textTheme.titleLarge),
          content: Text(
            'Are you sure you want to sign out?',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text('Cancel', style: TextStyle(color: theme.disabledColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    ).then((confirm) async {
      if (confirm == true) {
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Settings',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
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
              activeColor: theme.primaryColor,
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
              activeColor: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          if (_isAdmin)
            SettingsTile(
              icon: Icons.admin_panel_settings,
              title: 'Admin Portal',
              iconColor: theme.colorScheme.secondary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                );
              },
            ),
          const SectionHeader(title: 'PAYMENTS'),
          SettingsTile(
            icon: Icons.account_balance_wallet,
            title: 'My Wallet',
            iconColor: Colors.blueAccent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletPage()),
              );
            },
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
            titleColor: theme.colorScheme.error,
            iconColor: theme.colorScheme.error,
            onTap: _signOut,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Version 1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }
}
