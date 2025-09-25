import 'package:flutter/material.dart';
import 'role_access.dart';
import 'content_management.dart';
import 'admin_analytics.dart';
import 'admin_monitoring.dart';
import 'community_moderation.dart';
import 'admin_settings.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Admin Backend'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildRoleAccessCard(context),
            const SizedBox(height: 24),
            _buildContentManagementCard(context),
            const SizedBox(height: 24),
            _buildAnalyticsCard(context),
            const SizedBox(height: 24),
            _buildMonitoringCard(context),
            const SizedBox(height: 24),
            _buildCommunityModerationCard(context),
            const SizedBox(height: 24),
            _buildSettingsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleAccessCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.security, color: Color(0xFFD62828)),
        title: const Text('Role-Based Access'),
        subtitle: const Text('Manage user roles and permissions'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RoleAccessPage()),
          );
        },
      ),
    );
  }

  Widget _buildContentManagementCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Color(0xFFD62828)),
        title: const Text('Content Management'),
        subtitle: const Text('Create, edit, and delete platform content'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContentManagementPage()),
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
        subtitle: const Text('View platform-wide analytics'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminAnalyticsPage()),
          );
        },
      ),
    );
  }

  Widget _buildMonitoringCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.monitor, color: Color(0xFFD62828)),
        title: const Text('Monitoring'),
        subtitle: const Text('Monitor system health and usage'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminMonitoringPage()),
          );
        },
      ),
    );
  }

  Widget _buildCommunityModerationCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.forum, color: Color(0xFFD62828)),
        title: const Text('Community Moderation'),
        subtitle: const Text('Moderate discussions and user content'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CommunityModerationPage()),
          );
        },
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.settings, color: Color(0xFFD62828)),
        title: const Text('Settings'),
        subtitle: const Text('Configure platform settings'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminSettingsPage()),
          );
        },
      ),
    );
  }
}
