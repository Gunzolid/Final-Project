import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/services/firebase_parking_service.dart';

class AdminSpotListPage extends StatefulWidget {
  const AdminSpotListPage({super.key});

  @override
  State<AdminSpotListPage> createState() => _AdminSpotListPageState();
}

class _AdminSpotListPageState extends State<AdminSpotListPage> {
  final FirebaseParkingService _parkingService = FirebaseParkingService();
  String _filter = 'All'; // All, Available, Occupied, Unavailable

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('parking_spots')
                  .orderBy('id')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  if (_filter == 'All') return true;
                  final status = (doc['status'] ?? '').toString().toLowerCase();
                  return status == _filter.toLowerCase();
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    return _buildSpotCard(context, filteredDocs[index].id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Manage Spots',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              // Filter Dropdown
              DropdownButton<String>(
                value: _filter,
                underline: Container(),
                items: ['All', 'Available', 'Occupied', 'Unavailable']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _filter = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmBulkAction('available'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Set All Available'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade700,
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmBulkAction('unavailable'),
                  icon: const Icon(Icons.block),
                  label: const Text('Set All Unavailable'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpotCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final id = data['id'];
    final status = (data['status'] ?? 'unknown').toString().toLowerCase();
    final note = data['note'] as String?;

    Color color;
    IconData icon;
    switch (status) {
      case 'available':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'occupied':
        color = Colors.red;
        icon = Icons.directions_car;
        break;
      case 'unavailable':
        color = Colors.grey;
        icon = Icons.block;
        break;
      case 'held':
        color = Colors.orange;
        icon = Icons.timer;
        break;
      default:
        color = Colors.blue;
        icon = Icons.help;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEditDialog(docId, id, status, note),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spot $id',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              if (note != null && note.isNotEmpty)
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(String docId, int id, String currentStatus, String? currentNote) async {
    String selectedStatus = currentStatus;
    final noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit Spot $id'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['available', 'occupied', 'unavailable', 'held']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 16),
                if (selectedStatus == 'unavailable')
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (Reason)',
                      hintText: 'e.g. Maintenance',
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final updates = <String, dynamic>{'status': selectedStatus};
                  if (selectedStatus == 'unavailable') {
                    updates['note'] = noteController.text.trim();
                    updates['start_time'] = null;
                  } else if (selectedStatus == 'available') {
                    updates['start_time'] = null;
                    updates['note'] = null;
                  } else if (selectedStatus == 'occupied') {
                    updates['start_time'] = Timestamp.now();
                    updates['note'] = null;
                  }
                  
                  await _parkingService.updateParkingStatus(docId, updates);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmBulkAction(String status) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Action'),
        content: Text('Are you sure you want to set ALL spots to "$status"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _parkingService.updateAllSpotsStatus(status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All spots set to $status')),
        );
      }
    }
  }
}
