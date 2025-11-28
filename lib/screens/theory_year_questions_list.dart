import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';

class TheoryYearQuestionsList extends StatefulWidget {
  final String? subject;
  final int year;

  const TheoryYearQuestionsList({
    super.key,
    this.subject,
    required this.year,
  });

  @override
  State<TheoryYearQuestionsList> createState() => _TheoryYearQuestionsListState();
}

class _TheoryYearQuestionsListState extends State<TheoryYearQuestionsList> {
  int? _selectedQuestionIndex;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  late ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(Uri.parse(
        'https://uriel-backend-api-836591016471.us-central1.run.app/api/chat/stream'));
    
    // Listen to chat service stream
    _chatService.stream.listen(
      (chunk) {
        if (chunk.delta != null) {
          setState(() {
            if (_messages.isEmpty || _messages.last['role'] != 'assistant') {
              _messages.add({'role': 'assistant', 'content': chunk.delta!});
            } else {
              final lastContent = _messages.last['content'] as String;
              _messages.last['content'] = lastContent + chunk.delta!;
            }
          });
          
          // Auto-scroll
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_chatScrollController.hasClients) {
              _chatScrollController.animateTo(
                _chatScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        } else if (chunk.error != null) {
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': 'Sorry, I encountered an error: ${chunk.error}',
            });
            _isLoading = false;
          });
        } else if (chunk.done) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    final firestore = FirebaseFirestore.instance;
    Query<Map<String, dynamic>> query = firestore
        .collection('questions')
        .where('type', isEqualTo: 'essay')
        .where('year', isEqualTo: widget.year.toString());

    if (widget.subject != null) {
      query = query.where('subject', isEqualTo: _convertToSubjectValue(widget.subject!));
    }

    return query.orderBy('questionNumber');
  }

  String _convertToSubjectValue(String displayName) {
    // Convert display names back to enum values
    final mapping = {
      'Mathematics': 'mathematics',
      'English': 'english',
      'Integrated Science': 'integratedScience',
      'Social Studies': 'socialStudies',
      'Ga': 'ga',
      'Asante Twi': 'asanteTwi',
      'French': 'french',
      'ICT': 'ict',
      'Religious & Moral Education': 'religiousMoralEducation',
      'Creative Arts': 'creativeArts',
      'Career Technology': 'careerTechnology',
    };
    return mapping[displayName] ?? displayName.toLowerCase().replaceAll(' ', '');
  }

  String _formatSubject(String subjectValue) {
    // Convert enum values to display names
    final mapping = {
      'mathematics': 'Mathematics',
      'english': 'English',
      'integratedScience': 'Integrated Science',
      'socialStudies': 'Social Studies',
      'ga': 'Ga',
      'asanteTwi': 'Asante Twi',
      'french': 'French',
      'ict': 'ICT',
      'religiousMoralEducation': 'Religious & Moral Education',
      'creativeArts': 'Creative Arts',
      'careerTechnology': 'Career Technology',
    };
    return mapping[subjectValue] ?? subjectValue;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'BECE ${widget.subject ?? 'Theory'} ${widget.year}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          final questions = snapshot.data?.docs ?? [];

          if (questions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 80,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No questions available',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for updates',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Desktop: Split view with questions on left, AI chat on right
          if (isDesktop) {
            return Row(
              children: [
                // Left side: Questions list (40%)
                Expanded(
                  flex: 4,
                  child: _buildQuestionsList(questions),
                ),
                // Divider
                Container(
                  width: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
                // Right side: AI Chat (60%)
                Expanded(
                  flex: 6,
                  child: _buildAIChat(questions),
                ),
              ],
            );
          }

          // Mobile: Questions list with floating AI button
          return Stack(
            children: [
              _buildQuestionsList(questions),
              if (_selectedQuestionIndex != null)
                Positioned(
                  bottom: 24,
                  right: 20,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      _showAIChatSheet(context, questions);
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 4,
                    icon: const Icon(Icons.psychology_rounded, size: 22),
                    label: const Text(
                      'AI Tutor',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuestionsList(List<QueryDocumentSnapshot<Map<String, dynamic>>> questions) {
    // Parse questions and group by parts
    String? paperInstructions;
    final partGroups = <String, List<Map<String, dynamic>>>{}; // partHeader -> questions
    
    for (int i = 0; i < questions.length; i++) {
      final data = questions[i].data();
      
      // Extract paper instructions from first question
      if (i == 0 && data['paperInstructions'] != null && (data['paperInstructions'] as String).isNotEmpty) {
        paperInstructions = data['paperInstructions'] as String;
      }
      
      final partHeader = data['partHeader'] as String? ?? 'Questions';
      if (!partGroups.containsKey(partHeader)) {
        partGroups[partHeader] = [];
      }
      
      partGroups[partHeader]!.add({
        'index': i,
        'doc': questions[i],
        'data': data,
      });
    }
    
    // Convert entries to list to avoid iterator issues
    final partGroupsList = partGroups.entries.toList();
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Paper instructions card (non-clickable, centered)
        if (paperInstructions != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Text(
              paperInstructions,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
        
        // Group questions by parts
        ...partGroupsList.asMap().entries.map((entry) {
          final index = entry.key;
          final partEntry = entry.value;
          final partHeader = partEntry.key;
          final questionsInPart = partEntry.value;
          
          // Check if this part is selected
          final isPartSelected = questionsInPart.any((q) => q['index'] == _selectedQuestionIndex);
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == partGroupsList.length - 1 ? 80 : 12,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // When card is clicked, select the first question and prepare all questions for AI
                  final firstQuestionIndex = questionsInPart.first['index'] as int;
                  setState(() {
                    _selectedQuestionIndex = firstQuestionIndex;
                    _messages.clear();
                  });
                  
                  // Combine all questions in this part
                  final allQuestionsText = questionsInPart.map((q) {
                    final data = q['data'] as Map<String, dynamic>;
                    final qNum = data['questionNumber'];
                    final qText = _cleanQuestionText(data['questionText'] as String? ?? '');
                    return 'Question $qNum:\n$qText';
                  }).join('\n\n---\n\n');
                  
                  // Auto-send to AI
                  setState(() {
                    _messages.add({
                      'role': 'user',
                      'content': 'Please help me understand and answer these questions:\n\n$allQuestionsText',
                    });
                    _isLoading = true;
                  });
                  
                  // Scroll to bottom
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_chatScrollController.hasClients) {
                      _chatScrollController.animateTo(
                        _chatScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                  
                  // Send to AI
                  try {
                    final systemPrompt = _buildSystemPrompt(allQuestionsText);
                    
                    await _chatService.ask(
                      message: 'Please help me understand and answer these questions:\n\n$allQuestionsText',
                      system: systemPrompt,
                      history: [],
                    );
                  } catch (e) {
                    setState(() {
                      _messages.add({
                        'role': 'assistant',
                        'content': 'Sorry, I encountered an error. Please try again.',
                      });
                      _isLoading = false;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  decoration: BoxDecoration(
                    color: isPartSelected
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPartSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                          : Theme.of(context).colorScheme.outline.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Part header
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isPartSelected
                                        ? [
                                            Theme.of(context).colorScheme.primary,
                                            Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                          ]
                                        : [
                                            Theme.of(context).colorScheme.primaryContainer,
                                            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  partHeader,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: isPartSelected
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            if (isPartSelected) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 18,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // All questions in this part
                        ...questionsInPart.asMap().entries.map((qEntry) {
                          final qIndex = qEntry.key;
                          final questionMap = qEntry.value;
                          final data = questionMap['data'] as Map<String, dynamic>;
                          
                          // Clean question text
                          String questionText = data['questionText'] as String? ?? '';
                          questionText = _cleanQuestionText(questionText);
                          
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: qIndex == questionsInPart.length - 1 ? 0 : 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question number and marks
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Question ${data['questionNumber']}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '${data['marks']} marks',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Question text
                                Text(
                                  questionText,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    height: 1.65,
                                    letterSpacing: 0.15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                if (qIndex != questionsInPart.length - 1) ...[
                                  const SizedBox(height: 16),
                                  Divider(
                                    color: Theme.of(context).dividerColor.withOpacity(0.2),
                                    thickness: 1,
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  
  String _cleanQuestionText(String text) {
    // Remove paper instructions
    text = text.replaceAll(RegExp(r'^THEORY QUESTIONS[\s\S]*?orderly presentation of material\.?\s*', multiLine: true), '');
    
    // Remove part headers
    text = text.replaceAll(RegExp(r'^PART [A-C].*?\n.*?\n', multiLine: true), '');
    
    // Don't modify sub-question formatting - keep original line breaks
    
    return text.trim();
  }

  Widget _buildAIChat(List<QueryDocumentSnapshot<Map<String, dynamic>>> questions) {
    if (_selectedQuestionIndex == null) {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/uri.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Select a question to begin',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your AI tutor will guide you through\nthe answer step by step',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/uri.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Tutor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ask anything, get guided help',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
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
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.waving_hand_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Hi! I\'m your AI tutor',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'I\'ll help you work through this question step by step. Ask me anything!',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      return _buildChatBubble(
                        message['content']!,
                        isUser,
                        context,
                      );
                    },
                  ),
          ),
          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: 'Ask your tutor...',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(questions),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: _isLoading
                          ? null
                          : LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              ],
                            ),
                      color: _isLoading
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : () => _sendMessage(questions),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      iconSize: 24,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String message, bool isUser, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/uri.webp',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addSystemMessage(String questionText) {
    // Initialize with system context but don't show to user
    // This will be used in the API call
  }
  
  String _buildSystemPrompt(String questionText) {
    return '''You are Uri, an expert AI tutor helping students with BECE (Basic Education Certificate Examination) theory questions for ${widget.subject ?? 'this subject'}.

IMPORTANT: Base your guidance on the official NACCA (National Council for Curriculum and Assessment) and GES (Ghana Education Service) curriculum and syllabus for Junior High School (JHS 1-3). The curriculum documents are available in the system for reference.

The question(s) the student needs help with:
$questionText

Your role as Uri:
1. Guide students through understanding and answering questions using the Socratic method
2. Reference the NACCA/GES curriculum standards and learning indicators when relevant
3. Ask probing questions to help students think critically
4. Provide hints and explanations aligned with the official syllabus
5. Break down complex concepts into simpler parts as taught in the curriculum
6. Encourage students to explain their reasoning
7. Provide positive reinforcement and constructive feedback
8. When discussing topics, mention which part of the JHS 1-3 curriculum they relate to

Curriculum Context:
- Subject: ${widget.subject ?? 'General'}
- Exam Level: BECE (Basic Education Certificate Examination)
- Year: ${widget.year}
- Curriculum: NACCA/GES Standard-Based Curriculum for JHS

Be supportive, patient, and encouraging. Help them learn following the official curriculum guidelines, don't just give answers. When appropriate, reference specific learning outcomes and competencies from the NACCA syllabus.''';
  }

  Future<void> _sendMessage(List<QueryDocumentSnapshot<Map<String, dynamic>>> questions) async {
    if (_chatController.text.trim().isEmpty || _selectedQuestionIndex == null) return;

    final userMessage = _chatController.text.trim();
    _chatController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final questionData = questions[_selectedQuestionIndex!].data();
      final questionText = questionData['questionText'] ?? '';

      final systemPrompt = _buildSystemPrompt(questionText);

      // Build history for the API (exclude current user message as it's in the 'message' param)
      final history = _messages
          .where((msg) => msg['role'] != null && msg['content'] != null)
          .take(_messages.length - 1) // Exclude the message we just added
          .map((msg) => {
                'role': msg['role'] as String,
                'content': msg['content'] as String,
              })
          .toList();

      await _chatService.ask(
        message: userMessage,
        system: systemPrompt,
        history: history,
      );
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Sorry, I encountered an error. Please try again.',
        });
        _isLoading = false;
      });
    }
  }

  void _showAIChatSheet(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> questions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: _buildAIChat(questions)),
            ],
          ),
        ),
      ),
    );
  }
}
