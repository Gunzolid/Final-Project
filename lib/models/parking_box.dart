import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =================================================================================
// กล่องแสดงสถานะช่องจอด (PARKING BOX WIDGET)
// use for User Side: แสดงสีตามสถานะ รับ click ดูรายละเอียด
// =================================================================================

class ParkingBox extends StatefulWidget {
  final String docId; // ID เอกสารใน Firestore
  final int id; // หมายเลขช่องจอด
  final Axis direction; // แนวการวาง (ตั้ง/นอน)
  final int? recommendedId; // ID ที่ระบบแนะนำ (ถ้าตรงกับ ID นี้จะกะพริบ)
  final bool offlineMode; // โหมดไม่มีเน็ต
  final VoidCallback? onSelect; // เมื่อกดเลือก

  const ParkingBox({
    super.key,
    required this.docId,
    required this.id,
    this.direction = Axis.vertical,
    this.recommendedId,
    this.offlineMode = false,
    this.onSelect,
  });

  @override
  State<ParkingBox> createState() => _ParkingBoxState();
}

class _ParkingBoxState extends State<ParkingBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller; // ตัวคุม Animation กะพริบ
  late Animation<Color?> _blinkColor; // ค่าสีที่จะเปลี่ยนไปมา

  // ตัวแปรสำหรับตรวจสอบการเปลี่ยนแปลงสถานะเพื่อแจ้งเตือน
  String? _lastHoldBy;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    // ตั้งค่า Animation ให้กะพริบทุกๆ 0.8 วินาที
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // กำหนดสีตอนกะพริบ (Green <-> Yellow)
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

  // ฟังก์ชันสั่งเริ่ม/หยุดการกะพริบ
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

  // ฟังก์ชันตรวจสอบและแจ้งเตือนเมื่อสถานะการจองเปลี่ยนไป (เช่น หมดเวลา)
  void _checkAndAlertStatusChange(
    BuildContext context,
    String currentStatus,
    String? currentHoldBy,
    String? currentUid,
  ) {
    if (_isFirstLoad || currentUid == null) {
      _lastHoldBy = currentHoldBy;
      _isFirstLoad = false;
      return;
    }

    // ถ้าเราเคยจองช่องนี้อยู่
    if (_lastHoldBy == currentUid) {
      // แล้วตอนนี้ไม่ได้จองแล้ว
      if (currentHoldBy != currentUid) {
        String? message;
        if (currentStatus == 'available') {
          message = 'การจองช่อง ${widget.id} ของคุณหมดเวลาแล้ว';
        } else if (currentStatus == 'occupied') {
          message = 'ช่อง ${widget.id} ถูกใช้งานแล้ว';
        } else if (currentStatus == 'unavailable') {
          message = 'ช่อง ${widget.id} ไม่พร้อมใช้งาน';
        }

        // แสดง SnackBar แจ้งเตือน
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
                        () =>
                            ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  ),
                ),
              );
            }
          });
        }
      }
    }
    _lastHoldBy = currentHoldBy;
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);

    // กำหนดสีตามสถานะต่างๆ
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

    // กรณี Offline Mode: แสดงสีเทา
    if (widget.offlineMode) {
      _ensureBlinking(false);
      return _buildBox(offlineColor, textColor: offlineTextColor);
    }

    // กรณี Online: ใช้ StreamBuilder ดึงข้อมูล Real-time
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('parking_spots')
              .doc(widget.docId)
              .snapshots(),
      builder: (context, snapshot) {
        // กรณีโหลดไม่สำเร็จ หรือไม่มีข้อมูล
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

        // ดึงข้อมูลสถานะจาก Snapshot
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String status =
            (data['status'] ?? 'available').toString().toLowerCase();
        final Timestamp? startTime = data['start_time'] as Timestamp?;
        final Timestamp? lastUpdated = data['last_updated'] as Timestamp?;
        final String? note = data['note'] as String?;
        final String? holdBy = data['hold_by'] as String?;

        // ตรวจสอบการแจ้งเตือน
        _checkAndAlertStatusChange(context, status, holdBy, currentUid);

        // ตรวจสอบเงื่อนไขการกะพริบ (เป็นช่องแนะนำ และเราเป็นคนจอง)
        final bool isHeldByCurrentUser =
            currentUid != null && holdBy == currentUid;
        final bool isRecommended = widget.recommendedId == widget.id;
        final bool blink = isRecommended && isHeldByCurrentUser;

        // เลือกสีพื้นหลังตามสถานะ
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
            baseColor = heldColor; // สีส้ม (มีคนจอง)
            break;
          default:
            baseColor = defaultColor;
        }

        _ensureBlinking(blink);

        // สร้าง Widget กล่องสี่เหลี่ยม
        return GestureDetector(
          onTap: () {
            // ถ้าไม่ว่าง กดแล้วจะขึ้นรายละเอียด popup
            if (status.toLowerCase() != 'available') {
              _showStatusDialog(
                context: context,
                status: status,
                since: _resolveReferenceTime(status, startTime, lastUpdated),
                note: note,
                holdBy: holdBy,
              );
            } else {
              // ถ้าว่าง กดแล้วเลือกได้ (ตาม callback ที่ส่งมา)
              widget.onSelect?.call();
            }
          },
          child:
              blink
                  // ถ้าต้องกะพริบ ใช้ AnimatedBuilder
                  ? AnimatedBuilder(
                    animation: _blinkColor,
                    builder:
                        (context, child) =>
                            _buildBox(_blinkColor.value ?? availableColor),
                  )
                  // ถ้าไม่ต้องกะพริบ แสดงสีปกติ
                  : _buildBox(baseColor),
        );
      },
    );
  }

  // สร้าง UI กล่องสี่เหลี่ยม
  Widget _buildBox(Color color, {Color? textColor}) {
    // เลือกสีตัวอักษรให้ตัดกับพื้นหลังอัตโนมัติ
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
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

  // เลือกเวลาที่จะแสดง (เวลาเริ่มจอด หรือเวลาอัปเดตล่าสุด)
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

  // Popup แสดงรายละเอียดสถานะช่องจอด
  Future<void> _showStatusDialog({
    required BuildContext context,
    required String status,
    DateTime? since,
    String? note,
    String? holdBy,
  }) async {
    if (!context.mounted) return;

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

    await showDialog(
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
        '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return '$date $clock น.';
  }
}
