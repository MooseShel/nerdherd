import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';

class AppointmentManagementPage extends StatefulWidget {
  const AppointmentManagementPage({super.key});

  @override
  State<AppointmentManagementPage> createState() =>
      _AppointmentManagementPageState();
}

class _AppointmentManagementPageState extends State<AppointmentManagementPage> {
  final supabase = Supabase.instance.client;
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, pending, confirmed, completed, cancelled

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      setState(() => _isLoading = true);

      PostgrestFilterBuilder query = supabase.from('appointments').select();

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      final response =
          await query.order('created_at', ascending: false).limit(50);

      final List<dynamic> data = response;
      if (mounted) {
        setState(() {
          _appointments =
              data.map((json) => Appointment.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Simple status filter chips
    final filterChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['all', 'pending', 'confirmed', 'completed', 'cancelled']
            .map((status) {
          final isSelected = _filterStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _filterStatus = status;
                  });
                  _fetchAppointments();
                }
              },
              selectedColor: theme.primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.primaryColor
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );

    return Column(
      children: [
        filterChips,
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _appointments.isEmpty
                  ? Center(
                      child: Text('No appointments found',
                          style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      itemCount: _appointments.length,
                      itemBuilder: (context, index) {
                        final appointment = _appointments[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.dividerColor.withOpacity(0.1)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(appointment.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    appointment.status.toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color:
                                          _getStatusColor(appointment.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  DateFormat('MMM d, y HH:mm')
                                      .format(appointment.startTime),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('Host ID: ${appointment.hostId}',
                                    style: theme.textTheme.bodySmall),
                                Text('Attendee ID: ${appointment.attendeeId}',
                                    style: theme.textTheme.bodySmall),
                                if (appointment.message != null &&
                                    appointment.message!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '"${appointment.message}"',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontStyle: FontStyle.italic),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                    '\$${appointment.price.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
