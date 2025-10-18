import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../services/uri_ai.dart';

// Color constants matching design spec
class UrielColors {
  static const deepNavy = Color(0xFF1A1E3F);
  static const urielRed = Color(0xFFD62828);
  static const warmWhite = Color(0xFFFFF8F0);
  static const softGray = Color(0xFFF0F0F0);
  static const accentGreen = Color(0xFF2ECC71);
}

class UriChat extends StatefulWidget {
  final String? userName;
  final String? currentSubject;
  const UriChat({Key? key, this.userName, this.currentSubject}) : super(key: key);

  @override
  UriChatState createState() => UriChatState();
}

class UriChatState extends State<UriChat> with SingleTickerProviderStateMixin {
  bool _open = false;
  final _messages = <Map<String, String>>[]; // {role: 'user'|'bot', text: '...'}
  final _ctrl = TextEditingController();
  bool _loading = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  final FlutterTts _tts = FlutterTts();
  bool _simpleMath = true; // default to student-friendly view

  // Suggestion chips
  // Suggestion chips removed per request

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _tts.stop();
    _bounceController.dispose();
    super.dispose();
  }

  // Expose a method so parent can open/close programmatically
  void setOpen(bool open) {
    if (!mounted) return;
    setState(() {
      _open = open;
    });
  }

  void _toggle() {
    setState(() => _open = !_open);
  }

  void _showMobileChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: UrielColors.warmWhite,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: UrielColors.warmWhite,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: UrielColors.urielRed,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Ask Uri...',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: UrielColors.deepNavy,
                                    ),
                                  ),
                                ),
                                // Simple/Symbols toggle (compact)
                                Row(
                                  children: [
                                    const Text('Simple', style: TextStyle(fontSize: 12, color: UrielColors.deepNavy)),
                                    Switch(
                                      value: _simpleMath,
                                      activeColor: UrielColors.urielRed,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (v) => setState(() => _simpleMath = v),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: UrielColors.deepNavy, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: UrielColors.softGray),
                    // Messages area
                    Expanded(
                      child: _messages.isEmpty && !_loading
                          ? _buildWelcomeMessage()
                          : _buildMessagesList(MediaQuery.of(context).size.width),
                    ),
                    // Input area with keyboard handling
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: _buildInputArea(),
                    ),
                    // Powered by footer
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Text(
                        'Powered by Uriel AI',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Clear messages when sheet is closed
      setState(() {
        _messages.clear();
        _loading = false;
      });
    });
  }

  // Query Facts API for verified educational information
  Future<String?> _queryFactsAPI(String? userMessage, String? idToken) async {
    if (userMessage == null || userMessage.isEmpty || idToken == null) return null;
    
    try {
      final message = userMessage.toLowerCase();

      // Check for exam dates queries
      if (message.contains('when') && (message.contains('bece') || message.contains('wassce') || message.contains('exam'))) {
        final examType = message.contains('bece') ? 'bece' : 'wassce';
        // Extract year if mentioned
        final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(message);
        final year = yearMatch?.group(1) ?? '2026'; // Default to next year

        final response = await http.get(
          Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/factsApi/v1/exams/$examType/$year/dates'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Origin': 'https://uriel.academy',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['ok'] == true) {
            final examData = data['data'];
            String result = '📅 **${examType.toUpperCase()} $year Update**\n\n';
            result += 'The ${examType.toUpperCase()} will take place from **${examData['start_date'] ?? 'TBD'}** to **${examData['end_date'] ?? 'TBD'}**.\n\n';
            if (examData['status']) result += 'Status: ${examData['status']}\n';
            if (examData['note']) result += 'Note: ${examData['note']}\n\n';
            result += '*Source: ${data['source']['name']} (verified ${data['source']['lastVerifiedISO']?.split('T')?[0] ?? 'Unknown'})*';
            return result;
          }
        }
      }

      // Check for syllabus queries
      if (message.contains('syllabus') || message.contains('curriculum')) {
        // Extract subject from message
        final subjects = ['english', 'mathematics', 'science', 'social studies', 'rme', 'french', 'ict'];
        String? subject;
        for (var s in subjects) {
          if (message.contains(s)) {
            subject = s;
            break;
          }
        }

        // Extract level (JHS1, JHS2, etc.)
        final levelMatch = RegExp(r'\b(jhs\d?|shs\d?)\b', caseSensitive: false).firstMatch(message);
        final level = levelMatch?.group(1)?.toUpperCase() ?? 'JHS1';

        if (subject != null) {
          final response = await http.get(
            Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/factsApi/v1/syllabus/$level/$subject'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Origin': 'https://uriel.academy',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['ok'] == true) {
              final syllabus = data['data'];
              String result = '📚 **${subject.toUpperCase()} Syllabus ($level)**\n\n';
              result += '${syllabus['description'] ?? 'Official syllabus for $subject'}\n\n';
              if (syllabus['topics'] != null && syllabus['topics'].isNotEmpty) {
                result += '**Key Topics:**\n';
                for (var topic in syllabus['topics'].take(5)) {
                  result += '• $topic\n';
                }
                if (syllabus['topics'].length > 5) {
                  result += '• ... and ${syllabus['topics'].length - 5} more topics\n';
                }
              }
              result += '\n*Source: ${data['source']['name']} (verified ${data['source']['lastVerifiedISO']?.split('T')?[0] ?? 'Unknown'})*';
              return result;
            }
          }
        }
      }

      // Check for past questions queries
      if ((message.contains('question') || message.contains('past') || message.contains('practice')) &&
          (message.contains('bece') || message.contains('wassce'))) {
        // Extract subject and year
        final subjects = ['english', 'mathematics', 'science', 'social studies', 'rme', 'ict'];
        String? subject;
        String? year;

        for (var s in subjects) {
          if (message.contains(s)) {
            subject = s;
            break;
          }
        }

        // Extract year (look for 4-digit numbers)
        final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(message);
        if (yearMatch != null) {
          year = yearMatch.group(0);
        }

        final exam = message.contains('bece') ? 'bece' : 'wassce';

        if (subject != null) {
          final url = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/factsApi/v1/questions?exam=$exam&year=${year ?? '2011'}&subject=$subject&type=objective&page=1';

          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Origin': 'https://uriel.academy',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['ok'] == true && data['data']['questions'].isNotEmpty) {
              final questions = data['data']['questions'];
              String result = '📝 **${subject.toUpperCase()} Past Questions**\n\n';
              result += 'Found ${questions.length} questions';

              if (year != null) {
                result += ' from $year';
              }

              result += ':\n\n';

              // Show first 3 questions as examples
              for (var i = 0; i < questions.length && i < 3; i++) {
                final q = questions[i];
                result += '**Q${q['number'] ?? (i + 1)}:** ${q['question'] ?? 'Question text not available'}\n\n';
                if (q['options'] != null && q['options'].isNotEmpty) {
                  for (var j = 0; j < q['options'].length; j++) {
                    result += '${String.fromCharCode(65 + j)}) ${q['options'][j]}\n';
                  }
                  result += '\n**Answer:** ${q['answer'] ?? 'Not available'}\n\n';
                }
              }

              if (questions.length > 3) {
                result += '*... and ${questions.length - 3} more questions available*';
              }

              result += '\n\n*Source: ${data['source']['name']} (verified ${data['source']['lastVerifiedISO']?.split('T')?[0] ?? 'Unknown'})*';
              return result;
            }
          }
        }
      }

      // Check for textbook queries
      if (message.contains('textbook') || message.contains('book') || message.contains('recommended')) {
        final subjects = ['english', 'mathematics', 'science', 'social studies', 'rme', 'ict'];
        String? subject;

        for (var s in subjects) {
          if (message.contains(s)) {
            subject = s;
            break;
          }
        }

        if (subject != null) {
          final response = await http.get(
            Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/factsApi/v1/textbooks/$subject'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Origin': 'https://uriel.academy',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['ok'] == true && data['data']['textbooks'].isNotEmpty) {
              final textbooks = data['data']['textbooks'];
              String result = '📖 **Recommended ${subject.toUpperCase()} Textbooks**\n\n';

              for (var book in textbooks.take(3)) {
                result += '**${book['title'] ?? 'Title not available'}**\n';
                if (book['author'] != null) result += 'Author: ${book['author']}\n';
                if (book['publisher'] != null) result += 'Publisher: ${book['publisher']}\n';
                if (book['classLevel'] != null) result += 'Class: ${book['classLevel']}\n';
                result += '\n';
              }

              if (textbooks.length > 3) {
                result += '*... and ${textbooks.length - 3} more recommended textbooks*';
              }

              result += '\n*Source: ${data['source']['name']} (verified ${data['source']['lastVerifiedISO']?.split('T')?[0] ?? 'Unknown'})*';
              return result;
            }
          }
        }
      }

      // Check for NaCCA curriculum queries
      if (message.contains('nacca') || message.contains('curriculum') || message.contains('competenc')) {
        final subjects = ['english', 'mathematics', 'science', 'social studies', 'rme', 'french', 'ict'];
        String? subject;

        for (var s in subjects) {
          if (message.contains(s)) {
            subject = s;
            break;
          }
        }

        // Extract level (JHS1, JHS2, etc.)
        final levelMatch = RegExp(r'\b(jhs\d?|shs\d?)\b', caseSensitive: false).firstMatch(message);
        final level = levelMatch?.group(1)?.toUpperCase() ?? 'JHS1';

        if (subject != null) {
          final response = await http.get(
            Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/factsApi/v1/curriculum/nacca/$level/$subject'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Origin': 'https://uriel.academy',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['ok'] == true) {
              final curriculum = data['data'];
              String result = '🎯 **NaCCA Curriculum: ${subject.toUpperCase()} ($level)**\n\n';
              result += '${curriculum['description'] ?? 'NaCCA-aligned curriculum for $subject'}\n\n';
              if (curriculum['competencies'] != null && curriculum['competencies'].isNotEmpty) {
                result += '**Key Competencies:**\n';
                for (var competency in curriculum['competencies'].take(5)) {
                  result += '• $competency\n';
                }
                if (curriculum['competencies'].length > 5) {
                  result += '• ... and ${curriculum['competencies'].length - 5} more competencies\n';
                }
              }
              result += '\n*Source: ${data['source']['name']} (verified ${data['source']['lastVerifiedISO']?.split('T')?[0] ?? 'Unknown'})*';
              return result;
            }
          }
        }
      }

      // General search fallback
      if (message.length > 3) { // Only search if message is substantial
        final response = await http.get(
          Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/factsApi/v1/search').replace(queryParameters: {'query': userMessage}),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Origin': 'https://uriel.academy',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['ok'] == true && data['data']['results'].isNotEmpty) {
            final results = data['data']['results'];
            String result = '🔍 **Search Results for "$userMessage"**\n\n';

            for (var item in results.take(3)) {
              if (item['type'] == 'question') {
                result += '📝 **Question:** ${item['question'] ?? 'N/A'}\n';
                if (item['subject'] != null) result += 'Subject: ${item['subject']}\n';
                if (item['year'] != null) result += 'Year: ${item['year']}\n';
              } else if (item['type'] == 'syllabus') {
                result += '📚 **Syllabus:** ${item['title'] ?? 'N/A'}\n';
                if (item['subject'] != null) result += 'Subject: ${item['subject']}\n';
              } else if (item['type'] == 'textbook') {
                result += '📖 **Textbook:** ${item['title'] ?? 'N/A'}\n';
                if (item['author'] != null) result += 'Author: ${item['author']}\n';
              }
              result += '\n';
            }

            if (results.length > 3) {
              result += '*... and ${results.length - 3} more results found*';
            }

            result += '\n*Source: ${data['source']['name']} (verified ${data['source']['lastVerifiedISO']?.split('T')?[0] ?? 'Unknown'})*';
            return result;
          }
        }
      }

      return null; // No verified facts found, fall back to AI chat
    } catch (e) {
      debugPrint('Facts API error: $e');
      return null; // Fall back to AI chat on error
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _messages.insert(0, {'role':'user','text':text});
      _loading = true;
      _ctrl.clear();
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      final idToken = await user.getIdToken();

      // First, try to get verified facts from the Facts API
      final factsResponse = await _queryFactsAPI(text, idToken);
      if (factsResponse != null) {
        setState(() { _messages.insert(0, {'role':'bot','text':factsResponse}); });
      } else {
        // Fall back to regular AI chat if no verified facts found
        // Use the UriAI helper which routes queries between aiChat and facts
        final replyRaw = await UriAI.ask(text);
        final reply = _simpleMath ? simplifyMath(replyRaw) : replyRaw;
        setState(() { _messages.insert(0, {'role':'bot','text':reply}); });
      }
    } catch (e) {
      setState(() { _messages.insert(0, {'role':'bot','text':'AI error: ${e.toString()}'}); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.95);
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final buttonSize = isMobile ? 56.0 : 64.0;

    if (isMobile) {
      // Mobile: FAB button at bottom-right that opens modal bottom sheet
      return Positioned(
        right: 16,
        bottom: 80, // Above bottom navigation
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceAnimation.value,
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMobileChatSheet(context),
              borderRadius: BorderRadius.circular(buttonSize / 2),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: UrielColors.urielRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Desktop: Position at bottom-right corner
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 250),
        right: 20,
        bottom: 20,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_open) _buildDesktopSheet(context),
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _bounceAnimation.value,
                    child: child,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggle,
                    borderRadius: BorderRadius.circular(buttonSize / 2),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: UrielColors.urielRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDesktopSheet(BuildContext context) {
    const width = 420.0;
    const height = 600.0; // Will be constrained by 70% viewport

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 0.95, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomRight,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Material(
        elevation: 0,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: height,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: UrielColors.warmWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UrielColors.softGray, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: UrielColors.warmWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: UrielColors.urielRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ask Uri...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: UrielColors.deepNavy,
                              ),
                            ),
                          ),
                          // Simple/Symbols toggle visible on desktop header
                          Row(
                            children: [
                              const Text('Simple', style: TextStyle(fontSize: 13, color: UrielColors.deepNavy)),
                              Switch(
                                value: _simpleMath,
                                activeColor: UrielColors.urielRed,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) => setState(() => _simpleMath = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: UrielColors.deepNavy, size: 20),
                      onPressed: () {
                        setState(() {
                          _open = false;
                          _messages.clear();
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: UrielColors.softGray),
              // Messages area
              Expanded(
                child: _messages.isEmpty && !_loading
                    ? _buildWelcomeMessage()
                    : _buildMessagesList(width),
              ),
              // Input area
              _buildInputArea(),
              // Powered by footer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  'Powered by Uriel AI',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    // Welcome message and suggestion chips removed per request.
    // Return an empty widget so the messages area remains blank when there are no messages.
    return const SizedBox.shrink();
  }

  // Suggestion chips removed — helper intentionally omitted.


  Widget _buildMessagesList(double width) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (_loading && i == 0) {
          return _buildTypingIndicator();
        }
        final m = _messages[i - (_loading ? 1 : 0)];
        final isUser = m['role'] == 'user';
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: width * 0.8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser
                  ? UrielColors.urielRed.withValues(alpha: 0.1) // Light red tint for user
                  : Colors.white, // White background for bot
              border: Border.all(
                color: UrielColors.softGray,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              m['text'] ?? '',
              style: TextStyle(
                color: isUser ? UrielColors.deepNavy : UrielColors.deepNavy,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: UrielColors.warmWhite,
        border: Border(top: BorderSide(color: UrielColors.softGray, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: UrielColors.softGray,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _ctrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                autofocus: true,
                style: const TextStyle(
                  fontSize: 15,
                  color: UrielColors.deepNavy,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask a question…',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: UrielColors.urielRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _loading ? null : _send,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: UrielColors.softGray, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Uri is typing',
              style: TextStyle(
                color: UrielColors.deepNavy,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _bounceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: (index * 0.3 + _bounceController.value) % 1.0,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
