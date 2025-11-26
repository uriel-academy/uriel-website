import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import 'dart:async';

class TheoryQuestionViewer extends StatefulWidget {
  final String questionId;
  final String? subject;
  final String? year;

  const TheoryQuestionViewer({
    super.key,
    required this.questionId,
    this.subject,
    this.year,
  });

  @override
  State<TheoryQuestionViewer> createState() => _TheoryQuestionViewerState();
}

class _TheoryQuestionViewerState extends State<TheoryQuestionViewer> {
  final ChatService _chatService = ChatService(
    Uri.parse("https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatHttp"),
  );
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Map<String, dynamic>> _messages = [];
  String _currentAnswer = '';
  bool _isLoading = false;
  bool _isSendingMessage = false;
  StreamSubscription? _chatSubscription;
  Map<String, dynamic>? _questionData;
  bool _isLoadingQuestion = true;
  String? _systemPrompt;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
    _initializeChat();
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    try {
      final doc = await _firestore
          .collection('theoryQuestions')
          .doc(widget.questionId)
          .get();

      if (doc.exists) {
        setState(() {
          _questionData = doc.data();
          _isLoadingQuestion = false;
        });
      } else {
        setState(() {
          _isLoadingQuestion = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Question not found')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingQuestion = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading question: $e')),
        );
      }
    }
  }

  void _initializeChat() {
    // Prepare system message with question context
    if (_questionData != null) {
      _systemPrompt = '''
You are a patient and encouraging tutor helping a BECE student (age 14-15) with a theory question.

Question Details:
Subject: ${_questionData!['subjectDisplay'] ?? _questionData!['subject']}
Year: ${_questionData!['year']}
Marks: ${_questionData!['marks']}

Question:
${_questionData!['questionText']}

Guidelines:
1. Guide with Socratic questions, don't give direct answers
2. Break down complex concepts into simple steps
3. Be encouraging and patient
4. Use simple language appropriate for 14-15 year olds
5. Help them think critically
6. When they ask for the answer, guide them to discover it themselves
7. For math questions, use LaTeX notation: \$expression\$ for inline, \$\$expression\$\$ for blocks

Start by asking what they already know about this topic.
''';

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content':
              "Hi! I'm here to help you work through this question. Don't worry, we'll figure it out together! 😊\n\nFirst, what do you already know about this topic?",
          'timestamp': DateTime.now(),
        });
      });
    }
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSendingMessage) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add({
        'role': 'user',
        'content': userMessage,
        'timestamp': DateTime.now(),
      });
      _isSendingMessage = true;
      _currentAnswer = '';
    });

    _scrollToBottom();

    try {
      // Prepare history for API (convert messages to role/content format)
      final history = _messages
          .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
          .map((msg) => {
                'role': msg['role'] as String,
                'content': msg['content'] as String,
              })
          .toList();

      _chatSubscription?.cancel();
      _chatSubscription = _chatService.stream.listen(
        (chunk) {
          if (!mounted) return;

          setState(() {
            _currentAnswer += chunk.delta ?? '';
          });

          _scrollToBottom();
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            _isSendingMessage = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
        onDone: () {
          if (!mounted) return;

          if (_currentAnswer.isNotEmpty) {
            setState(() {
              _messages.add({
                'role': 'assistant',
                'content': _currentAnswer,
                'timestamp': DateTime.now(),
              });
              _currentAnswer = '';
              _isSendingMessage = false;
            });

            _scrollToBottom();
          } else {
            setState(() {
              _isSendingMessage = false;
            });
          }
        },
      );

      await _chatService.ask(
        message: userMessage,
        system: _systemPrompt,
        history: history,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingMessage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Future<void> _submitAnswer() async {
    // Extract student's answer from chat messages
    final studentMessages = _messages
        .where((msg) => msg['role'] == 'user' && msg['content'] != null)
        .map((msg) => msg['content'] as String)
        .join('\n\n');

    if (studentMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please discuss the question first before submitting')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final submissionData = {
        'studentId': userId,
        'questionId': widget.questionId,
        'subject': _questionData!['subject'],
        'year': _questionData!['year'],
        'questionText': _questionData!['questionText'],
        'marks': _questionData!['marks'],
        'studentAnswer': studentMessages,
        'chatHistory': _messages
            .map((msg) => {
                  'role': msg['role'],
                  'content': msg['content'],
                  'timestamp': (msg['timestamp'] as DateTime?)?.toIso8601String(),
                })
            .toList(),
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending_review',
        'score': null,
        'teacherFeedback': null,
      };

      await _firestore
          .collection('theoryAnswers')
          .doc('${userId}_${widget.questionId}')
          .set(submissionData);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Answer Submitted! ✅'),
          content: const Text(
              'Your answer has been submitted for teacher review. You\'ll receive feedback soon!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to question list
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting answer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: Text(_questionData != null
            ? '${_questionData!['subjectDisplay'] ?? _questionData!['subject']} Theory'
            : 'Theory Question'),
        actions: [
          if (!_isLoadingQuestion && _questionData != null)
            IconButton(
              icon: const Icon(Icons.send),
              tooltip: 'Submit Answer',
              onPressed: _isLoading ? null : _submitAnswer,
            ),
        ],
      ),
      body: _isLoadingQuestion
          ? const Center(child: CircularProgressIndicator())
          : _questionData == null
              ? const Center(child: Text('Question not found'))
              : isMobile
                  ? _buildMobileLayout()
                  : _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.question_answer), text: 'Question'),
              Tab(icon: Icon(Icons.chat), text: 'AI Tutor'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildQuestionPane(),
                _buildChatPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Question pane (40%)
        Expanded(
          flex: 4,
          child: _buildQuestionPane(),
        ),
        const VerticalDivider(width: 1),
        // Chat pane (60%)
        Expanded(
          flex: 6,
          child: _buildChatPane(),
        ),
      ],
    );
  }

  Widget _buildQuestionPane() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject badge
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(_questionData!['subjectDisplay'] ??
                      _questionData!['subject']),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                ),
                Chip(
                  label: Text('${_questionData!['year']}'),
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                ),
                Chip(
                  label: Text('${_questionData!['marks']} marks'),
                  backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Question number
            Text(
              'Question ${_questionData!['questionNumber']}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            // Question text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: SelectableText(
                _questionData!['questionText'],
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Instructions',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Use the AI Tutor to help you think through the question\n'
                    '• The tutor will guide you with hints, not give direct answers\n'
                    '• Take your time to develop your answer\n'
                    '• Click the submit button when ready for teacher review',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPane() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.school, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Tutor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Here to guide you',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.where((m) => m['role'] != 'system').length +
                  (_currentAnswer.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                final visibleMessages =
                    _messages.where((m) => m['role'] != 'system').toList();

                if (index < visibleMessages.length) {
                  final message = visibleMessages[index];
                  return _buildMessageBubble(
                    message['content'],
                    message['role'] == 'user',
                  );
                } else {
                  // Current streaming message
                  return _buildMessageBubble(_currentAnswer, false);
                }
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your thoughts or questions...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _isSendingMessage ? null : _sendMessage,
                  icon: _isSendingMessage
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: SelectableText(
          content,
          style: TextStyle(
            color: isUser
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
