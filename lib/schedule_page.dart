import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/appointment.dart';
import 'models/user_profile.dart'; // Import UserProfile
import 'package:intl/intl.dart';
import 'widgets/review_dialog.dart';
import 'widgets/empty_state_widget.dart';
import 'services/payment_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final supabase = Supabase.instance.client;
  List<Appointment> _appointments = [];
  Map<String, UserProfile> _profiles = {}; // Cache for profiles
  bool _isLoading = true;
  String _filter = 'all'; // all, pending, confirmed

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from('appointments')
          .select()
          .or('host_id.eq.${user.id},attendee_id.eq.${user.id}')
          .order('start_time', ascending: true);

      final List<Appointment> loaded =
          (data as List).map((e) => Appointment.fromJson(e)).toList();

      // Collect all User IDs (Hosts and Attendees)
      final userIds = <String>{};
      for (var a in loaded) {
        userIds.add(a.hostId);
        userIds.add(a.attendeeId);
      }

      // Fetch Profiles
      if (userIds.isNotEmpty) {
        final profilesData = await supabase
            .from('profiles')
            .select()
            .filter('user_id', 'in', userIds.toList());

        final newProfiles = <String, UserProfile>{};
        for (var p in profilesData) {
          final profile = UserProfile.fromJson(p);
          newProfiles[profile.userId] = profile;
        }

        // Update cache
        if (mounted) {
          _profiles = newProfiles;
        }
      }

      setState(() {
        _appointments = loaded;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      // Refund Logic: If status becomes declined or cancelled (from paid status)
      // Check if it was paid first?
      // The refundPayment method checks 'is_paid' inside it, effectively safe to call.
      if (newStatus == 'declined' || newStatus == 'cancelled') {
        await paymentService.refundPayment(
            id); // Will return false/true but safely handles checks
      }

      await supabase
          .from('appointments')
          .update({'status': newStatus}).eq('id', id);
      _fetchAppointments(); // Refresh
      if (mounted) {
        String msg = "Appointment marked as $newStatus";
        if (newStatus == 'declined' || newStatus == 'cancelled') {
          msg += " (Payment refunded if applicable)";
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: newStatus == 'confirmed' ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _rescheduleAppointment(Appointment appt) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: appt.startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appt.startTime.toLocal()),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );
    if (pickedTime == null) return;

    final newStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final duration = appt.endTime.difference(appt.startTime);
    final newEnd = newStart.add(duration);

    try {
      await supabase.from('appointments').update({
        'start_time': newStart.toUtc().toIso8601String(),
        'end_time': newEnd.toUtc().toIso8601String(),
        'status': 'pending', // Reset to pending for re-approval
        'message':
            "${appt.message}\n(Rescheduled from ${DateFormat('MM/dd HH:mm').format(appt.startTime.toLocal())})",
      }).eq('id', appt.id);

      _fetchAppointments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Rescheduled! Sent for approval."),
              backgroundColor: Colors.amber),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Reschedule failed: $e")));
      }
    }
  }

  Future<void> _deleteAppointment(String id) async {
    try {
      await supabase.from('appointments').delete().eq('id', id);
      _fetchAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text("Appointment removed."),
              backgroundColor: Theme.of(context).disabledColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      }
    }
  }

  Future<void> _showReviewDialog(Appointment appt, UserProfile? profile) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReviewDialog(
        revieweeName: profile?.fullName ?? "User",
      ),
    );

    if (result != null && mounted) {
      final rating = result['rating'] as int;
      final comment = result['comment'] as String?;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      // Determine who is being reviewed (the OTHER person)
      final revieweeId = user.id == appt.hostId ? appt.attendeeId : appt.hostId;

      try {
        await supabase.from('reviews').insert({
          'reviewer_id': user.id,
          'reviewee_id': revieweeId,
          'appointment_id': appt.id,
          'rating': rating,
          'comment': comment,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Review submitted!"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        final msg = e.toString().contains("duplicate key")
            ? "You have already reviewed this session."
            : "Error submitting review: $e";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Login required")));
    }

    final filtered = _appointments.where((a) {
      if (_filter == 'all') return true;
      return a.status == _filter;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("My Schedule",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Confirmed', 'confirmed'),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: theme.primaryColor))
                : filtered.isEmpty
                    ? Center(
                        child: EmptyStateWidget(
                          icon: Icons.calendar_today_outlined,
                          title: "No appointments",
                          subtitle: _filter == 'all'
                              ? "You haven't booked any sessions yet."
                              : "No $_filter sessions found.",
                          actionLabel: _filter == 'all' ? "Find a Tutor" : null,
                          onAction: _filter == 'all'
                              ? () {
                                  if (mounted) {
                                    Navigator.of(context)
                                        .popUntil((route) => route.isFirst);
                                  }
                                }
                              : null,
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final appt = filtered[index];
                          final isHost = appt.hostId == user.id;
                          final otherId =
                              isHost ? appt.attendeeId : appt.hostId;
                          final otherProfile = _profiles[otherId];
                          final dateStr = DateFormat('MMM d, h:mm a')
                              .format(appt.startTime.toLocal());

                          return Container(
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: theme.cardTheme.shadowColor != null
                                  ? [
                                      BoxShadow(
                                          color: theme.cardTheme.shadowColor!,
                                          blurRadius: 10,
                                          offset: const Offset(0, 4))
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Avatar
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: theme.dividerColor
                                                  .withOpacity(0.1)),
                                        ),
                                        child: CircleAvatar(
                                          radius: 24,
                                          backgroundColor: theme.primaryColor
                                              .withOpacity(0.1),
                                          backgroundImage: otherProfile
                                                      ?.avatarUrl !=
                                                  null
                                              ? (otherProfile!.avatarUrl!
                                                      .startsWith('assets/')
                                                  ? AssetImage(otherProfile
                                                          .avatarUrl!)
                                                      as ImageProvider
                                                  : NetworkImage(
                                                      otherProfile.avatarUrl!))
                                              : null,
                                          child: otherProfile?.avatarUrl == null
                                              ? Icon(Icons.person,
                                                  color: theme.primaryColor)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    otherProfile?.fullName ??
                                                        (isHost
                                                            ? "Unknown Student"
                                                            : "Unknown Tutor"),
                                                    style: theme
                                                        .textTheme.titleMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                _buildStatusBadge(appt.status),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              otherProfile?.intentTag ??
                                                  (isHost
                                                      ? "Student"
                                                      : "Tutor"),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme
                                                    .textTheme.bodySmall?.color
                                                    ?.withOpacity(0.6),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time,
                                                    size: 14,
                                                    color: theme.primaryColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dateStr,
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (appt.message != null &&
                                      appt.message!.isNotEmpty) ...[
                                    Container(
                                      margin: const EdgeInsets.only(top: 16),
                                      padding: const EdgeInsets.all(12),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme.surfaceContainerHighest
                                            .withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "\"${appt.message}\"",
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                fontStyle: FontStyle.italic,
                                                color: theme
                                                    .textTheme.bodyMedium?.color
                                                    ?.withOpacity(0.8)),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 20),

                                  // Simplified Action Buttons
                                  _buildActionButtons(appt, isHost, context),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final theme = Theme.of(context);
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) => setState(() => _filter = value),
      selectedColor: theme.primaryColor.withOpacity(0.2),
      backgroundColor: theme.cardColor,
      labelStyle: TextStyle(
        color:
            selected ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final theme = Theme.of(context);
    Color color;
    String label = status.toUpperCase();
    switch (status) {
      case 'confirmed':
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'completion_pending':
        color = Colors.amber;
        label = "AWAITING";
        break;
      case 'declined':
      case 'cancelled':
      case 'disputed':
        color = theme.colorScheme.error;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons(
      Appointment appt, bool isHost, BuildContext context) {
    if (appt.status == 'pending') {
      if (isHost) {
        return Row(
          children: [
            Expanded(
                child: FilledButton(
                    onPressed: () => _updateStatus(appt.id, 'confirmed'),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Accept"))),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton(
                    onPressed: () => _updateStatus(appt.id, 'declined'),
                    child: const Text("Decline"))),
          ],
        );
      } else {
        return SizedBox(
            width: double.infinity,
            child: OutlinedButton(
                onPressed: () => _updateStatus(appt.id, 'cancelled'),
                child: const Text("Cancel Request")));
      }
    } else if (appt.status == 'confirmed') {
      if (isHost && appt.endTime.isBefore(DateTime.now())) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _updateStatus(appt.id, 'completion_pending'),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text("Mark Complete"),
          ),
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _rescheduleAppointment(appt),
                icon: const Icon(Icons.edit_calendar, size: 16),
                label: const Text("Reschedule"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateStatus(appt.id, 'cancelled'),
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text("Cancel"),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      }
    } else if (appt.status == 'completion_pending') {
      if (!isHost) {
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _updateStatus(appt.id, 'completed'),
                icon: const Icon(Icons.thumb_up, size: 16),
                label: const Text("Confirm"),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateStatus(appt.id, 'disputed'),
                icon: const Icon(Icons.report_problem, size: 16),
                label: const Text("Report"),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      } else {
        return const Center(
            child: Text("Waiting for confirmation...",
                style: TextStyle(fontStyle: FontStyle.italic)));
      }
    } else if (appt.status == 'completed') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showReviewDialog(appt, null),
          icon: const Icon(Icons.star, size: 16),
          label: const Text("Review"),
          style: FilledButton.styleFrom(backgroundColor: Colors.amber[700]),
        ),
      );
    } else if (['cancelled', 'declined', 'disputed'].contains(appt.status)) {
      return SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => _deleteAppointment(appt.id),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text("Remove"),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
