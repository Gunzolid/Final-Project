// lib/models/parking_box.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingBox extends StatefulWidget {
  final String docId;
  final int id;
  final Axis direction;
  final int? recommendedId;

  const ParkingBox({
    super.key,
    required this.docId,
    required this.id,
    this.direction = Axis.vertical,
    this.recommendedId,
  });

  @override
  State<ParkingBox> createState() => _ParkingBoxState();
}

class _ParkingBoxState extends State<ParkingBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _blinkColor;

  @override
  void initState() {
    super.initState();
    // 1. initState() จะมีแค่การตั้งค่า Controller เท่านั้น
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // VVV ลบส่วนที่เรียกใช้ Theme.of(context) ออกจาก initState VVV
    // final theme = Theme.of(context); // <-- ห้ามเรียกในนี้
    // _blinkColor = ColorTween(...).animate(_controller); // <-- ย้ายไป didChangeDependencies
  }

  // 2. ย้ายโค้ดที่ต้องใช้ Theme มาไว้ใน didChangeDependencies()
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // อัปเดตสี blinking ตาม Theme
    // ที่นี่สามารถเรียก Theme.of(context) ได้อย่างปลอดภัย
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

  String _getElapsedTime(Timestamp startTime) {
    final now = DateTime.now();
    final started = startTime.toDate();
    final diff = now.difference(started);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return '$hours ชม. $minutes นาที';
    return '$minutes นาที';
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

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('parking_spots')
              .doc(widget.docId)
              .snapshots(),
      builder: (context, snapshot) {
        // --- 3. ส่วนจัดการ Offline/Loading (ที่เราทำไว้) ---
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

        // --- ถ้ามีข้อมูล (Online) ---
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String status = (data['status'] ?? 'available') as String;
        final Timestamp? startTime = data['start_time'] as Timestamp?;
        final String? holdBy = data['hold_by'] as String?;

        final bool isRecommended = widget.recommendedId == widget.id;
        final bool blink = isRecommended;

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
            if (currentUid != null && holdBy == currentUid) {
              baseColor = heldColor;
            } else {
              baseColor = availableColor;
            }
            break;
          default:
            baseColor = defaultColor;
        }

        _ensureBlinking(blink);

        // --- ส่วน GestureDetector (เหมือนเดิม) ---
        return GestureDetector(
          onTap: () {
            if (status == 'occupied' && startTime != null) {
              final elapsed = _getElapsedTime(startTime);
              showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      title: Text('ช่อง ${widget.id}'),
                      content: Text('ใช้งานมาแล้ว: $elapsed'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ปิด'),
                        ),
                      ],
                    ),
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
}
