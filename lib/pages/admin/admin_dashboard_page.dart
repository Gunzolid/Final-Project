import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mtproject/models/parking_layout_config.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('parking_spots').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading data'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final total = kTotalSpots;
          final available =
              docs
                  .where(
                    (d) => d['status'] == 'available' || d['status'] == 'held',
                  )
                  .length;
          final occupied = docs.where((d) => d['status'] == 'occupied').length;

          final unavailable =
              docs.where((d) => d['status'] == 'unavailable').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard Overview',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isDesktop = width > 600;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatCard(
                          context,
                          'Total Spots',
                          '$total',
                          Icons.local_parking,
                          Colors.blue,
                          width:
                              isDesktop ? (width - 48) / 4 : (width - 16) / 2,
                        ),
                        _buildStatCard(
                          context,
                          'Available',
                          '$available',
                          Icons.check_circle,
                          Colors.green,
                          width:
                              isDesktop ? (width - 48) / 4 : (width - 16) / 2,
                        ),
                        _buildStatCard(
                          context,
                          'Occupied',
                          '$occupied',
                          Icons.directions_car,
                          Colors.red,
                          width:
                              isDesktop ? (width - 48) / 4 : (width - 16) / 2,
                        ),
                        _buildStatCard(
                          context,
                          'Unavailable',
                          '$unavailable',
                          Icons.block,
                          Colors.grey,
                          width:
                              isDesktop ? (width - 48) / 4 : (width - 16) / 2,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  'Recent Activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildRecentActivityList(docs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList(List<QueryDocumentSnapshot> docs) {
    final occupiedDocs = docs.where((d) => d['status'] == 'occupied').toList();
    // Sort by start_time descending if available
    occupiedDocs.sort((a, b) {
      final tA = a['start_time'] as Timestamp?;
      final tB = b['start_time'] as Timestamp?;
      if (tA == null) return 1;
      if (tB == null) return -1;
      return tB.compareTo(tA);
    });

    if (occupiedDocs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No recent activity'),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: occupiedDocs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final data = occupiedDocs[index].data() as Map<String, dynamic>;
          final id = data['id'];
          final startTime = (data['start_time'] as Timestamp?)?.toDate();
          final timeStr =
              startTime != null
                  ? '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}'
                  : 'Unknown';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              child: const Icon(
                Icons.directions_car,
                color: Colors.red,
                size: 20,
              ),
            ),
            title: Text('Spot $id is occupied'),
            subtitle: Text('Started at $timeStr'),
          );
        },
      ),
    );
  }
}
