// lib/models/parking_box.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingBox extends StatefulWidget {
  final String docId;
  final int id;
  final Axis direction;
  final int? recommendedId;
  final bool offlineMode;

  const ParkingBox({
    super.key,
    required this.docId,
    required this.id,
    this.direction = Axis.vertical,
    this.recommendedId,
    this.offlineMode = false,
  });

  @override
  State<ParkingBox> createState() => _ParkingBoxState();
}

class _ParkingBoxState extends State<ParkingBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _blinkColor;

  // Track previous state for notifications
  String? _lastStatus;
  String? _lastHoldBy;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  // ... (didChangeDependencies, dispose, _ensureBlinking, _buildBox remain same)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _blinkColor = ColorTween(
      begin:
          theme.brightness == Brightness.dark
              ? Colors.green.shade300
              : Colors.green,
      end:
          theme.brightness == Brightness.dark
              ? Colors.yellow.shade300
              : Colors.yellow,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ensureBlinking(bool shouldBlink) {
    if (shouldBlink) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  Widget _buildBox(Color color, {Color? textColor}) {
    final boxTextColor =
        textColor ??
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black);

    return Container(
      width: widget.direction == Axis.vertical ? 30 : 45,
      height: widget.direction == Axis.vertical ? 45 : 30,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.white.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Text(
          '${widget.id}',
          style: TextStyle(color: boxTextColor, fontSize: 12),
        ),
      ),
    );
  }

  void _checkAndAlertStatusChange(
    BuildContext context,
    String currentStatus,
    String? currentHoldBy,
    String? currentUid,
  ) {
    // Skip if first load or user not logged in
    if (_isFirstLoad || currentUid == null) {
      _lastStatus = currentStatus;
      _lastHoldBy = currentHoldBy;
      _isFirstLoad = false;
      return;
    }

    // Check if I WAS holding this spot
    if (_lastHoldBy == currentUid) {
      // If I am NO LONGER holding it
      if (currentHoldBy != currentUid) {
        String? message;
        if (currentStatus == 'available') {
          message = 'การจองช่อง ${widget.id} ของคุณหมดเวลาแล้ว';
        } else if (currentStatus == 'occupied') {
          // If it became occupied, it might be the user parking, or someone else.
          // We can't distinguish easily, but we can inform.
          message = 'ช่อง ${widget.id} ถูกใช้งานแล้ว';
        } else if (currentStatus == 'unavailable') {
          message = 'ช่อง ${widget.id} ไม่พร้อมใช้งาน';
        }

        if (message != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message!),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'ตกลง',
                    onPressed:
                        () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  ),
                ),
              );
            }
          });
        }
      }
    }

    // Update last state
    _lastStatus = currentStatus;
    _lastHoldBy = currentHoldBy;
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    final theme = Theme.of(context);
    final availableColor =
        theme.brightness == Brightness.dark
            ? Colors.green.shade300
            : Colors.green;
    final occupiedColor =
        theme.brightness == Brightness.dark ? Colors.red.shade300 : Colors.red;
    final heldColor =
        theme.brightness == Brightness.dark
            ? Colors.orange.shade300
            : Colors.orange;
    final unavailableColor = Colors.grey.shade600;
    final defaultColor =
        theme.brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.black;
    final offlineColor =
        theme.brightness == Brightness.dark
            ? Colors.grey.shade800
            : Colors.grey.shade300;
    final offlineTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    if (widget.offlineMode) {
      _ensureBlinking(false);
      return _buildBox(offlineColor, textColor: offlineTextColor);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('parking_spots')
              .doc(widget.docId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.data() == null) {
          _ensureBlinking(false);
          if (snapshot.hasError) {
            return Tooltip(
              message: "Offline: ${snapshot.error}",
              child: _buildBox(offlineColor, textColor: offlineTextColor),
            );
          }
          return _buildBox(offlineColor, textColor: offlineTextColor);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String status =
            (data['status'] ?? 'available').toString().toLowerCase();
        final Timestamp? startTime = data['start_time'] as Timestamp?;
        final Timestamp? lastUpdated = data['last_updated'] as Timestamp?;
        final String? note = data['note'] as String?;
        final String? holdBy = data['hold_by'] as String?;

        // Check for status changes and alert
        _checkAndAlertStatusChange(context, status, holdBy, currentUid);

        final bool isHeldByCurrentUser =
            currentUid != null && holdBy == currentUid;
        final bool isRecommended = widget.recommendedId == widget.id;
        final bool blink = isRecommended && isHeldByCurrentUser;

        Color baseColor;
        switch (status) {
          case 'available':
            baseColor = availableColor;
            break;
          case 'occupied':
            baseColor = occupiedColor;
            break;
          case 'unavailable':
            baseColor = unavailableColor;
            break;
          case 'held':
            baseColor = heldColor;
            break;
          default:
            baseColor = defaultColor;
        }

        _ensureBlinking(blink);

        return GestureDetector(
          onTap: () {
            if (status.toLowerCase() != 'available') {
              _showStatusDialog(
                context: context,
                status: status,
                since: _resolveReferenceTime(status, startTime, lastUpdated),
                note: note,
              );
            }
          },
          child:
              blink
                  ? AnimatedBuilder(
                    animation: _blinkColor,
                    builder:
                        (_, __) =>
                            _buildBox(_blinkColor.value ?? availableColor),
                  )
                  : _buildBox(baseColor),
        );
      },
    );
  }

  DateTime? _resolveReferenceTime(
    String status,
    Timestamp? start,
    Timestamp? lastUpdated,
  ) {
    if (status == 'occupied' && start != null) {
      return start.toDate();
    }
    return lastUpdated?.toDate();
  }

  void _showStatusDialog({
    required BuildContext context,
    required String status,
    DateTime? since,
    String? note,
  }) {
    final buffer = <Widget>[];
    if (since != null) {
      buffer.add(Text('อยู่ในสถานะนี้มาแล้ว ${_formatDuration(since)}'));
      buffer.add(const SizedBox(height: 8));
      buffer.add(Text('ตั้งแต่ ${_formatTimestamp(since)}'));
    } else {
      buffer.add(const Text('ไม่มีข้อมูลเวลาอัปเดตล่าสุด'));
    }

    if (note != null && note.isNotEmpty) {
      buffer.add(const SizedBox(height: 8));
      buffer.add(Text('หมายเหตุ: $note'));
    }

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('ช่อง ${widget.id} - ${status.toUpperCase()}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: buffer,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ],
          ),
    );
  }

  String _formatDuration(DateTime since) {
    final diff = DateTime.now().difference(since);
    final totalMinutes = diff.inMinutes;
    if (totalMinutes >= 60) {
      final hours = (totalMinutes / 60).toStringAsFixed(1);
      return '$hours ชั่วโมง';
    }
    return '$totalMinutes นาที';
  }

  String _formatTimestamp(DateTime time) {
    final date =
        '${time.day.toString().padLeft(2, '0')}/'
        '${time.month.toString().padLeft(2, '0')}';
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return '$date $clock น.';
  }
}
