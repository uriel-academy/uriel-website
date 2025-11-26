import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TextbookAdminPage extends StatefulWidget {
  const TextbookAdminPage({super.key});

  @override
  State<TextbookAdminPage> createState() => _TextbookAdminPageState();
}

class _TextbookAdminPageState extends State<TextbookAdminPage> {
  final _functions = FirebaseFunctions.instance;
  final _firestore = FirebaseFirestore.instance;
  
  bool _isGenerating = false;
  bool _isAdmin = false;
  String? _generationLog;
  final Map<String, bool> _yearStatus = {
    'JHS 1': false,
    'JHS 2': false,
    'JHS 3': false,
  };

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _checkExistingTextbooks();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isAdmin = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final userData = doc.data();
      setState(() {
        _isAdmin = userData?['isSuperAdmin'] == true || 
                   userData?['isAdmin'] == true;
      });
    } catch (e) {
      setState(() => _isAdmin = false);
    }
  }

  Future<void> _checkExistingTextbooks() async {
    try {
      for (final year in ['JHS 1', 'JHS 2', 'JHS 3']) {
        final doc = await _firestore
            .collection('textbooks')
            .doc('english_$year'.replaceAll(' ', '_').toLowerCase())
            .get();
        
        setState(() {
          _yearStatus[year] = doc.exists;
        });
      }
    } catch (e) {
      debugPrint('Error checking textbooks: $e');
    }
  }

  Future<void> _generateTextbook(String year) async {
    setState(() {
      _isGenerating = true;
      _generationLog = 'Starting generation for $year...\n';
    });

    try {
      // Call Cloud Function
      final callable = _functions.httpsCallable(
        'generateEnglishTextbooks',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );

      _updateLog('Calling Cloud Function...');
      
      final result = await callable.call({
        'year': year,
      });

      _updateLog('Generation complete!');
      _updateLog('Result: ${result.data}');

      // Refresh status
      await _checkExistingTextbooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully generated $year textbook'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _updateLog('Error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating textbook: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _updateLog(String message) {
    setState(() {
      _generationLog = '${_generationLog ?? ''}$message\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Access Required'),
          backgroundColor: const Color(0xFF1A1E3F),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'You do not have admin access',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Textbook Admin'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          const Text(
            'English Textbook Generation',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1E3F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate comprehensive interactive English textbooks for JHS students',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Year cards
          ..._yearStatus.entries.map((entry) {
            final year = entry.key;
            final exists = entry.value;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          exists ? Icons.check_circle : Icons.circle_outlined,
                          color: exists ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                year,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1E3F),
                                ),
                              ),
                              Text(
                                exists ? 'Already generated' : 'Not yet generated',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: exists ? Colors.green : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Info boxes
                    Row(
                      children: [
                        _buildInfoBox('5', 'Chapters'),
                        const SizedBox(width: 12),
                        _buildInfoBox('25', 'Sections'),
                        const SizedBox(width: 12),
                        _buildInfoBox('145', 'Questions'),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating
                            ? null
                            : () => _showConfirmDialog(year, exists),
                        icon: Icon(exists ? Icons.refresh : Icons.auto_awesome),
                        label: Text(
                          exists ? 'Regenerate' : 'Generate',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD62828),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 32),

          // Generate all button
          Card(
            color: const Color(0xFF1A1E3F),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Generate All Years',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This will generate all 3 textbooks sequentially.\nEach takes approximately 5-8 minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _generateAllTextbooks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD62828),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Generate All',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Generation log
          if (_generationLog != null) ...[
            const SizedBox(height: 32),
            const Text(
              'Generation Log',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.grey[900],
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Text(
                    _generationLog!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (_isGenerating) ...[
            const SizedBox(height: 20),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Generating... This may take 5-8 minutes',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFD62828).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD62828),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConfirmDialog(String year, bool exists) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${exists ? "Regenerate" : "Generate"} $year Textbook?'),
        content: Text(
          exists
              ? 'This will replace the existing $year textbook. User progress will be preserved. Continue?'
              : 'This will generate a comprehensive English textbook for $year with:\n\n'
                  '• 5 chapters\n'
                  '• 25 sections (5 per chapter)\n'
                  '• 145 interactive questions\n'
                  '• XP rewards system\n\n'
                  'Generation takes approximately 5-8 minutes. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: Text(exists ? 'Regenerate' : 'Generate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _generateTextbook(year);
    }
  }

  Future<void> _generateAllTextbooks() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate All Textbooks?'),
        content: const Text(
          'This will generate all 3 English textbooks (JHS 1, 2, and 3) sequentially.\n\n'
          'Total time: Approximately 15-25 minutes.\n\n'
          'You can leave this page running in the background. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final year in ['JHS 1', 'JHS 2', 'JHS 3']) {
      await _generateTextbook(year);
      // Small delay between generations
      if (year != 'JHS 3') {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
}
