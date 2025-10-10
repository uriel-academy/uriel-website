import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';


class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  String _selectedDateRange = 'Last 7 days';
  String _selectedUserType = 'All';

  final List<Map<String, dynamic>> metrics = [
    {'label': 'Active Users', 'value': 1240, 'icon': Icons.people, 'color': Colors.blue},
    {'label': 'Content Published', 'value': 87, 'icon': Icons.book, 'color': Colors.green},
    {'label': 'Exams Taken', 'value': 320, 'icon': Icons.assignment_turned_in, 'color': Colors.orange},
    {'label': 'AI Queries', 'value': 2100, 'icon': Icons.smart_toy, 'color': Colors.purple},
    {'label': 'Reports Exported', 'value': 45, 'icon': Icons.file_download, 'color': Colors.red},
  ];

  final List<String> dateRanges = ['Today', 'Last 7 days', 'Last 30 days', 'All time'];
  final List<String> userTypes = ['All', 'Student', 'Parent', 'School', 'Admin'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Analytics'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Analytics',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics exported (mock)!')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedDateRange,
                  items: dateRanges.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDateRange = val);
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedUserType,
                  items: userTypes.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedUserType = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 1240, color: Colors.blue)]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 87, color: Colors.green)]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 320, color: Colors.orange)]),
                        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 2100, color: Colors.purple)]),
                        BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 45, color: Colors.red)]),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final labels = ['Users', 'Content', 'Exams', 'AI', 'Reports'];
                              return Text(labels[value.toInt()]);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Key Metrics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: metrics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final metric = metrics[i];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: metric['color'],
                            child: Icon(metric['icon'], color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(metric['label'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(metric['value'].toString(), style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('New content published: "Math Textbook"'),
                    subtitle: Text('2 hours ago'),
                  ),
                  ListTile(
                    leading: Icon(Icons.person_add, color: Colors.blue),
                    title: Text('Student registered: Ama Owusu'),
                    subtitle: Text('Today'),
                  ),
                  ListTile(
                    leading: Icon(Icons.assignment_turned_in, color: Colors.orange),
                    title: Text('Mock exam completed: BECE 2024'),
                    subtitle: Text('Yesterday'),
                  ),
                  ListTile(
                    leading: Icon(Icons.smart_toy, color: Colors.purple),
                    title: Text('AI query: "Explain osmosis"'),
                    subtitle: Text('Yesterday'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
