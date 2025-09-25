import 'package:flutter/material.dart';

class SchoolDashboardPage extends StatelessWidget {
  const SchoolDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('School Dashboard'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildBulkStudentManagementCard(context),
            const SizedBox(height: 24),
            _buildSubscriptionTrackingCard(context),
            const SizedBox(height: 24),
            _buildAnalyticsCard(context),
            const SizedBox(height: 24),
            _buildTeacherFeedbackCard(context),
            const SizedBox(height: 24),
            _buildReportsExportCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkStudentManagementCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.group, color: Color(0xFFD62828)),
        title: const Text('Bulk Student Management'),
        subtitle: const Text('Add, edit, or remove students in bulk'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BulkStudentManagementPage()),
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionTrackingCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.monetization_on, color: Color(0xFFD62828)),
        title: const Text('Subscription & Commission Tracking'),
        subtitle: const Text('Monitor school subscriptions and commissions'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionTrackingPage()),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.bar_chart, color: Color(0xFFD62828)),
        title: const Text('Analytics'),
        subtitle: const Text('View school-wide performance analytics'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SchoolAnalyticsPage()),
          );
        },
      ),
    );
  }

  Widget _buildTeacherFeedbackCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.feedback, color: Color(0xFFD62828)),
        title: const Text('Teacher Feedback'),
        subtitle: const Text('Review and respond to teacher feedback'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherFeedbackPage()),
          );
        },
      ),
    );
  }

  Widget _buildReportsExportCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.file_download, color: Color(0xFFD62828)),
        title: const Text('Export Reports'),
        subtitle: const Text('Download performance and subscription reports'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsExportPage()),
          );
        },
      ),
    );
  }
}

class BulkStudentManagementPage extends StatelessWidget {
  const BulkStudentManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Student Management'),
      ),
      body: const Center(
        child: Text('Bulk Student Management Page'),
      ),
    );
  }
}

class SubscriptionTrackingPage extends StatelessWidget {
  const SubscriptionTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Tracking'),
      ),
      body: const Center(
        child: Text('Subscription Tracking Page'),
      ),
    );
  }
}

class SchoolAnalyticsPage extends StatelessWidget {
  const SchoolAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Analytics'),
      ),
      body: const Center(
        child: Text('School Analytics Page'),
      ),
    );
  }
}

class TeacherFeedbackPage extends StatelessWidget {
  const TeacherFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Feedback'),
      ),
      body: const Center(
        child: Text('Teacher Feedback Page'),
      ),
    );
  }
}

class ReportsExportPage extends StatelessWidget {
  const ReportsExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Reports'),
      ),
      body: const Center(
        child: Text('Reports Export Page'),
      ),
    );
  }
}
