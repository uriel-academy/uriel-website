import 'package:flutter/material.dart';


class AdminMonitoringPage extends StatefulWidget {
  const AdminMonitoringPage({super.key});

  @override
  State<AdminMonitoringPage> createState() => _AdminMonitoringPageState();
}

class _AdminMonitoringPageState extends State<AdminMonitoringPage> {
  bool _showAlert = true;
  final List<Map<String, dynamic>> systemHealth = [
    {'label': 'Server Status', 'value': 'Online', 'icon': Icons.cloud_done, 'color': Colors.green},
    {'label': 'API Latency', 'value': '120ms', 'icon': Icons.speed, 'color': Colors.blue},
    {'label': 'Storage Usage', 'value': '75%', 'icon': Icons.storage, 'color': Colors.orange},
    {'label': 'Error Rate', 'value': '0.2%', 'icon': Icons.error_outline, 'color': Colors.red},
    {'label': 'Active Sessions', 'value': 320, 'icon': Icons.people, 'color': Colors.purple},
  ];
  final List<Map<String, String>> logs = [
    {'time': '10:02', 'event': 'User login: Kofi Mensah'},
    {'time': '09:58', 'event': 'Content published: Science Textbook'},
    {'time': '09:45', 'event': 'API error: Timeout'},
    {'time': '09:30', 'event': 'Student registered: Akua Boateng'},
    {'time': '09:15', 'event': 'Server restarted'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Monitoring'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download Logs',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs downloaded (mock)!')),
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
            if (_showAlert)
              Card(
                color: Colors.red[50],
                child: ListTile(
                  leading: const Icon(Icons.warning, color: Colors.red),
                  title: const Text('API error detected!'),
                  subtitle: const Text('Timeout at 09:45. Please check API status.'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _showAlert = false),
                  ),
                ),
              ),
            const Text('System Health', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: systemHealth.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final metric = systemHealth[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(metric['icon'], color: metric['color'], size: 32),
                              const SizedBox(width: 16),
                              Text(metric['label'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Value: ${metric['value']}', style: const TextStyle(fontSize: 16)),
                          if (metric['label'] == 'API Latency')
                            LinearProgressIndicator(
                              value: 0.6,
                              color: Colors.blue,
                              backgroundColor: Colors.blue[50],
                            ),
                          if (metric['label'] == 'Storage Usage')
                            LinearProgressIndicator(
                              value: 0.75,
                              color: Colors.orange,
                              backgroundColor: Colors.orange[50],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('Recent Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    leading: const Icon(Icons.event_note, color: Color(0xFF1A1E3F)),
                    title: Text(log['event']!),
                    subtitle: Text(log['time']!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
