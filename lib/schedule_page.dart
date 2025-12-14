import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/appointment.dart';
import 'package:intl/intl.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final supabase = Supabase.instance.client;
  List<Appointment> _appointments = [];
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
      await supabase
          .from('appointments')
          .update({'status': newStatus}).eq('id', id);
      _fetchAppointments(); // Refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user == null)
      return const Scaffold(body: Center(child: Text("Login required")));

    final filtered = _appointments.where((a) {
      if (_filter == 'all') return true;
      return a.status == _filter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text("My Schedule"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Confirmed', 'confirmed'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text("No appointments found",
                            style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final appt = filtered[index];
                          final isHost = appt.hostId == user.id;
                          final dateStr = DateFormat('MMM d, h:mm a')
                              .format(appt.startTime.toLocal());

                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isHost
                                            ? "Student Request"
                                            : "Session with Tutor", // Ideally fetch names
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      _buildStatusBadge(appt.status),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                        color: Colors.cyanAccent, fontSize: 15),
                                  ),
                                  if (appt.message != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      "\"${appt.message}\"",
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  // Action Buttons
                                  if (appt.status == 'pending') ...[
                                    if (isHost)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _updateStatus(
                                                  appt.id, 'confirmed'),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green),
                                              child: const Text("Accept"),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => _updateStatus(
                                                  appt.id, 'declined'),
                                              style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red),
                                              child: const Text("Decline"),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                          onPressed: () => _updateStatus(
                                              appt.id, 'cancelled'),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red),
                                          child: const Text("Cancel Request"),
                                        ),
                                      ),
                                  ],
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
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) => setState(() => _filter = value),
      backgroundColor: Colors.white10,
      selectedColor: Colors.cyanAccent.withOpacity(0.2),
      labelStyle:
          TextStyle(color: selected ? Colors.cyanAccent : Colors.white70),
      checkmarkColor: Colors.cyanAccent,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = Colors.greenAccent;
        break;
      case 'pending':
        color = Colors.orangeAccent;
        break;
      case 'declined':
      case 'cancelled':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
