import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class SystemMonitoringPage extends StatefulWidget {
  const SystemMonitoringPage({super.key});

  @override
  State<SystemMonitoringPage> createState() => _SystemMonitoringPageState();
}

class _SystemMonitoringPageState extends State<SystemMonitoringPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Real-time data streams
  StreamSubscription<QuerySnapshot>? _activeUsersStream;
  StreamSubscription<QuerySnapshot>? _activeQuizzesStream;
  StreamSubscription<QuerySnapshot>? _recentErrorsStream;
  StreamSubscription<QuerySnapshot>? _xpTransactionsStream;

  // Live metrics
  List<Map<String, dynamic>> _activeUsers = [];
  List<Map<String, dynamic>> _ongoingQuizzes = [];
  List<Map<String, dynamic>> _recentErrors = [];
  List<Map<String, dynamic>> _recentXPTransactions = [];
  List<Map<String, dynamic>> _systemAlerts = [];

  // Performance metrics
  double _avgResponseTime = 0.0;
  int _totalRequests = 0;
  int _failedRequests = 0;
  double _errorRate = 0.0;

  // System health indicators
  bool _firestoreHealthy = true;
  bool _authHealthy = true;
  bool _functionsHealthy = true;
  DateTime? _lastHealthCheck;

  @override
  void initState() {
    super.initState();
    _startRealTimeMonitoring();
    _performHealthCheck();
  }

  @override
  void dispose() {
    _activeUsersStream?.cancel();
    _activeQuizzesStream?.cancel();
    _recentErrorsStream?.cancel();
    _xpTransactionsStream?.cancel();
    super.dispose();
  }

  void _startRealTimeMonitoring() {
    // Monitor active users (online in last 5 minutes)
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    _activeUsersStream = _firestore
        .collection('users')
        .where('lastSeen', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _activeUsers = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['displayName'] ?? data['firstName'] ?? 'Unknown',
            'role': data['role'] ?? 'student',
            'lastSeen': data['lastSeen'],
            'school': data['school'] ?? 'N/A',
          };
        }).toList();
      });
      _checkForAnomalies();
    });

    // Monitor ongoing quizzes (started in last 30 minutes, not completed)
    final thirtyMinutesAgo =
        DateTime.now().subtract(const Duration(minutes: 30));
    _activeQuizzesStream = _firestore
        .collection('quizzes')
        .where('startedAt', isGreaterThan: Timestamp.fromDate(thirtyMinutesAgo))
        .where('completedAt', isNull: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _ongoingQuizzes = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'userId': data['userId'] ?? 'Unknown',
            'subject': data['subject'] ?? 'N/A',
            'startedAt': data['startedAt'],
            'questionCount': data['totalQuestions'] ?? 0,
          };
        }).toList();
      });
    });

    // Monitor recent XP transactions (last 10 minutes)
    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
    _xpTransactionsStream = _firestore
        .collection('xp_transactions')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(tenMinutesAgo))
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _recentXPTransactions = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'userId': data['userId'] ?? 'Unknown',
            'amount': data['amount'] ?? 0,
            'reason': data['reason'] ?? 'Unknown',
            'timestamp': data['timestamp'],
          };
        }).toList();
      });
    });

    // Monitor error logs (if you have an errors collection)
    _recentErrorsStream = _firestore
        .collection('errors')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _recentErrors = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'message': data['message'] ?? 'Unknown error',
            'code': data['code'] ?? 'N/A',
            'userId': data['userId'],
            'timestamp': data['timestamp'],
            'severity': data['severity'] ?? 'error',
          };
        }).toList();
      });
    }, onError: (error) {
      // Errors collection might not exist yet
      debugPrint('Error monitoring errors collection: $error');
    });
  }

  Future<void> _performHealthCheck() async {
    setState(() => _lastHealthCheck = DateTime.now());

    try {
      // Check Firestore health
      await _firestore.collection('users').limit(1).get();
      setState(() => _firestoreHealthy = true);
    } catch (e) {
      setState(() => _firestoreHealthy = false);
      _addAlert('Firestore', 'Firestore connection failed', 'critical');
    }

    try {
      // Check Auth health
      FirebaseAuth.instance.currentUser;
      setState(() => _authHealthy = true);
    } catch (e) {
      setState(() => _authHealthy = false);
      _addAlert('Authentication', 'Auth service unavailable', 'critical');
    }

    // Check for high error rates
    if (_recentErrors.length > 10) {
      _addAlert(
          'Error Rate',
          'High error rate detected: ${_recentErrors.length} errors',
          'warning');
    }
  }

  void _checkForAnomalies() {
    // Check for unusual number of active users
    if (_activeUsers.length > 100) {
      _addAlert('Traffic',
          'Unusually high active users: ${_activeUsers.length}', 'info');
    }

    // Check for stuck quizzes (started more than 20 minutes ago)
    final twentyMinutesAgo =
        DateTime.now().subtract(const Duration(minutes: 20));
    final stuckQuizzes = _ongoingQuizzes.where((quiz) {
      final startedAt = (quiz['startedAt'] as Timestamp?)?.toDate();
      return startedAt != null && startedAt.isBefore(twentyMinutesAgo);
    }).length;

    if (stuckQuizzes > 0) {
      _addAlert('Quizzes', '$stuckQuizzes quizzes may be stuck', 'warning');
    }
  }

  void _addAlert(String category, String message, String severity) {
    setState(() {
      // Prevent duplicate alerts
      final exists = _systemAlerts.any((alert) =>
          alert['category'] == category && alert['message'] == message);

      if (!exists) {
        _systemAlerts.insert(0, {
          'category': category,
          'message': message,
          'severity': severity,
          'timestamp': DateTime.now(),
        });

        // Keep only last 10 alerts
        if (_systemAlerts.length > 10) {
          _systemAlerts = _systemAlerts.sublist(0, 10);
        }
      }
    });
  }

  void _dismissAlert(int index) {
    setState(() {
      _systemAlerts.removeAt(index);
    });
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Invalid';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFDC3545);
      case 'warning':
        return const Color(0xFFFFC107);
      case 'info':
        return const Color(0xFF007AFF);
      default:
        return Colors.grey;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'student':
        return const Color(0xFF007AFF);
      case 'teacher':
        return const Color(0xFF2ECC71);
      case 'school_admin':
        return const Color(0xFF9B59B6);
      case 'super_admin':
        return const Color(0xFFF77F00);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.monitor_heart,
                          color: Color(0xFF007AFF),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System Monitoring',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1A1E3F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real-time operations and system health',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _performHealthCheck,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Run health check',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Last health check indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2ECC71)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2ECC71),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live monitoring • Last check: ${_lastHealthCheck != null ? _formatTimestamp(_lastHealthCheck!) : 'Never'}',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: const Color(0xFF2ECC71),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // System Health Status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Health',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHealthCard(
                          'Firestore',
                          _firestoreHealthy,
                          Icons.cloud,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildHealthCard(
                          'Authentication',
                          _authHealthy,
                          Icons.lock,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildHealthCard(
                          'Functions',
                          _functionsHealthy,
                          Icons.functions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Active Alerts
          if (_systemAlerts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Alerts',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._systemAlerts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final alert = entry.value;
                      return _buildAlertCard(alert, index);
                    }),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

          // Live Activity Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Users
                  Expanded(
                    child: _buildActivitySection(
                      'Active Users',
                      _activeUsers.length.toString(),
                      Icons.people,
                      const Color(0xFF007AFF),
                      _buildActiveUsersList(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Ongoing Quizzes
                  Expanded(
                    child: _buildActivitySection(
                      'Ongoing Quizzes',
                      _ongoingQuizzes.length.toString(),
                      Icons.quiz,
                      const Color(0xFF9B59B6),
                      _buildOngoingQuizzesList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Recent Activity Streams
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // XP Transactions
                  Expanded(
                    child: _buildActivitySection(
                      'Recent XP Transactions',
                      _recentXPTransactions.length.toString(),
                      Icons.star,
                      const Color(0xFF2ECC71),
                      _buildXPTransactionsList(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Recent Errors
                  Expanded(
                    child: _buildActivitySection(
                      'Recent Errors',
                      _recentErrors.length.toString(),
                      Icons.error,
                      const Color(0xFFDC3545),
                      _buildErrorsList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHealthCard(String title, bool isHealthy, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isHealthy
                      ? const Color(0xFF2ECC71)
                      : const Color(0xFFDC3545))
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color:
                  isHealthy ? const Color(0xFF2ECC71) : const Color(0xFFDC3545),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isHealthy ? 'Operational' : 'Down',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color:
                  isHealthy ? const Color(0xFF2ECC71) : const Color(0xFFDC3545),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, int index) {
    final severity = alert['severity'] as String;
    final color = _getSeverityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              severity == 'critical'
                  ? Icons.error
                  : severity == 'warning'
                      ? Icons.warning
                      : Icons.info,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['category'],
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert['message'],
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _dismissAlert(index),
            icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(
    String title,
    String count,
    IconData icon,
    Color color,
    Widget content,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        count,
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUsersList() {
    if (_activeUsers.isEmpty) {
      return _buildEmptyState('No active users');
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _activeUsers.length,
      itemBuilder: (context, index) {
        final user = _activeUsers[index];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: _getRoleColor(user['role']).withValues(alpha: 0.1),
            child: Text(
              (user['name'] as String).isNotEmpty
                  ? (user['name'] as String)[0]
                  : '?',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getRoleColor(user['role']),
              ),
            ),
          ),
          title: Text(
            user['name'],
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          subtitle: Text(
            '${user['role']} • ${user['school']}',
            style:
                GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
          ),
          trailing: Text(
            _formatTimestamp(user['lastSeen']),
            style:
                GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500]),
          ),
        );
      },
    );
  }

  Widget _buildOngoingQuizzesList() {
    if (_ongoingQuizzes.isEmpty) {
      return _buildEmptyState('No ongoing quizzes');
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _ongoingQuizzes.length,
      itemBuilder: (context, index) {
        final quiz = _ongoingQuizzes[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.quiz, size: 20, color: Color(0xFF9B59B6)),
          title: Text(
            quiz['subject'],
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          subtitle: Text(
            '${quiz['questionCount']} questions',
            style:
                GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
          ),
          trailing: Text(
            _formatTimestamp(quiz['startedAt']),
            style:
                GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500]),
          ),
        );
      },
    );
  }

  Widget _buildXPTransactionsList() {
    if (_recentXPTransactions.isEmpty) {
      return _buildEmptyState('No recent XP transactions');
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _recentXPTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _recentXPTransactions[index];
        final amount = transaction['amount'] as int;
        return ListTile(
          dense: true,
          leading: Icon(
            amount > 0 ? Icons.arrow_upward : Icons.arrow_downward,
            size: 20,
            color:
                amount > 0 ? const Color(0xFF2ECC71) : const Color(0xFFDC3545),
          ),
          title: Text(
            transaction['reason'],
            style: GoogleFonts.montserrat(fontSize: 13),
          ),
          subtitle: Text(
            '${amount > 0 ? '+' : ''}$amount XP',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: amount > 0
                  ? const Color(0xFF2ECC71)
                  : const Color(0xFFDC3545),
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Text(
            _formatTimestamp(transaction['timestamp']),
            style:
                GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500]),
          ),
        );
      },
    );
  }

  Widget _buildErrorsList() {
    if (_recentErrors.isEmpty) {
      return _buildEmptyState('No recent errors');
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _recentErrors.length,
      itemBuilder: (context, index) {
        final error = _recentErrors[index];
        return ListTile(
          dense: true,
          leading: Icon(
            Icons.error,
            size: 20,
            color: _getSeverityColor(error['severity']),
          ),
          title: Text(
            error['message'],
            style: GoogleFonts.montserrat(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Code: ${error['code']}',
            style:
                GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
          ),
          trailing: Text(
            _formatTimestamp(error['timestamp']),
            style:
                GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }
}
