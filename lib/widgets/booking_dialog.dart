import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/payment_service.dart';
import '../services/logger_service.dart';

class BookingDialog extends StatefulWidget {
  final String tutorId;
  final String tutorName;
  final double hourlyRate;

  const BookingDialog({
    super.key,
    required this.tutorId,
    required this.tutorName,
    this.hourlyRate = 0.0,
  });

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _messageController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Please select date and time.'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Combine Date and Time
    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final end = start.add(const Duration(hours: 1)); // Default 1 hour duration
    final cost = widget.hourlyRate; // Assuming 1 hour block for MVP

    try {
      // Process Payment first if cost > 0
      if (cost > 0) {
        // This will throw if insufficient funds
        await paymentService.processPayment(user.id, widget.tutorId, cost,
            "Booking with ${widget.tutorName} (${start.toString().split('.')[0]})");
      }

      await Supabase.instance.client.from('appointments').insert({
        'host_id': widget.tutorId,
        'attendee_id': user.id,
        'start_time': start.toUtc().toIso8601String(),
        'end_time': end.toUtc().toIso8601String(),
        'status': 'pending',
        'message': _messageController.text.trim(),
        'price': cost,
        'is_paid': cost > 0,
      });

      if (mounted) {
        Navigator.pop(context, true); // Success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(cost > 0
                  ? 'Payment successful! Request sent.'
                  : 'Request sent! Wait for tutorial confirmation.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      logger.error("Booking error", error: e);
      // ROLLBACK: If payment was made but booking failed, refund immediately
      if (cost > 0) {
        try {
          // Reverse: Tutor pays Student back
          await paymentService.processPayment(widget.tutorId, user.id, cost,
              "Auto-refund: Booking failed (${e.toString().split(':')[0]})");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Booking failed from server, but you have been refunded.'),
                  backgroundColor: Colors.orange),
            );
          }
        } catch (refundError) {
          logger.error("CRITICAL: Refund failed after booking error",
              error: refundError);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'CRITICAL: Booking failed AND refund failed. Please contact support.'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Booking Failed"),
              content: SelectableText("Error: ${e.toString()}"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close"),
                )
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = widget.hourlyRate;

    return Dialog(
      backgroundColor: theme.cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  "Book Session",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text("with ${widget.tutorName}",
                  style: theme.textTheme.bodyMedium),
              if (cost > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        "Rate: \$${cost.toStringAsFixed(2)} / hr",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon:
                          Icon(Icons.calendar_today, color: theme.primaryColor),
                      label: FittedBox(
                        child: Text(
                          _selectedDate == null
                              ? "Select Date"
                              : "${_selectedDate!.month}/${_selectedDate!.day}",
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: Icon(Icons.access_time, color: theme.primaryColor),
                      label: FittedBox(
                        child: Text(
                          _selectedTime == null
                              ? "Select Time"
                              : _selectedTime!.format(context),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: "Reason / Topic (e.g. Calculus Help)",
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.5)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          cost > 0 ? Colors.green : theme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(cost > 0
                          ? "Pay & Book (\$${cost.toStringAsFixed(2)})"
                          : "Request Appointment"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
