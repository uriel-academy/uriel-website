import 'package:flutter/material.dart';
import 'package:uriel_mainapp/services/textbook_generation_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TextbookGeneratorPage extends StatefulWidget {
  const TextbookGeneratorPage({super.key});

  @override
  State<TextbookGeneratorPage> createState() => _TextbookGeneratorPageState();
}

class _TextbookGeneratorPageState extends State<TextbookGeneratorPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();
  final _syllabusController = TextEditingController();
  
  final _service = TextbookGenerationService();
  
  String _selectedGrade = 'BECE';
  String _selectedContentType = 'full_lesson';
  String _selectedLanguage = 'en';
  bool _isGenerating = false;
  String? _generatedContent;
  Map<String, dynamic>? _metadata;

  final List<String> _grades = [
    'BECE',
    'WASSCE',
    'JHS 1',
    'JHS 2',
    'JHS 3',
    'SHS 1',
    'SHS 2',
    'SHS 3',
  ];

  final Map<String, String> _contentTypes = {
    'full_lesson': 'Full Lesson (Comprehensive)',
    'summary': 'Summary (Quick Review)',
    'practice_questions': 'Practice Questions',
    'worked_examples': 'Worked Examples',
  };

  final Map<String, String> _languages = {
    'en': 'English',
    'tw': 'Twi (Akan)',
    'ee': 'Ewe',
    'ga': 'Ga',
  };

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    _syllabusController.dispose();
    super.dispose();
  }

  Future<void> _generateContent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _generatedContent = null;
      _metadata = null;
    });

    try {
      final result = await _service.generateContent(
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        syllabusReference: _syllabusController.text.trim().isEmpty 
            ? null 
            : _syllabusController.text.trim(),
        grade: _selectedGrade,
        contentType: _selectedContentType,
        language: _selectedLanguage,
      );

      if (result['success'] == true) {
        setState(() {
          _generatedContent = result['content'];
          _metadata = result['metadata'];
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Content generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Textbook Generator'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          if (_generatedContent != null)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export Content',
              onPressed: () {
                // TODO: Implement export functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export feature coming soon')),
                );
              },
            ),
        ],
      ),
      body: Row(
        children: [
          // Left panel: Input form
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                right: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Generate Educational Content',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Powered by Claude AI (Anthropic)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Subject
                    TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        hintText: 'e.g., Mathematics, Science, English',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.book),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Topic
                    TextFormField(
                      controller: _topicController,
                      decoration: const InputDecoration(
                        labelText: 'Topic *',
                        hintText: 'e.g., Quadratic Equations, Cell Biology',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.topic),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a topic';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Grade
                    DropdownButtonFormField<String>(
                      value: _selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                      items: _grades.map((grade) {
                        return DropdownMenuItem(
                          value: grade,
                          child: Text(grade),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedGrade = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Content Type
                    DropdownButtonFormField<String>(
                      value: _selectedContentType,
                      decoration: const InputDecoration(
                        labelText: 'Content Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.article),
                      ),
                      items: _contentTypes.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedContentType = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Language
                    DropdownButtonFormField<String>(
                      value: _selectedLanguage,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language),
                      ),
                      items: _languages.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedLanguage = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Syllabus Reference (Optional)
                    TextFormField(
                      controller: _syllabusController,
                      decoration: const InputDecoration(
                        labelText: 'Syllabus Reference (Optional)',
                        hintText: 'e.g., NACCA 2024 Mathematics B3.2',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.library_books),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    
                    // Generate Button
                    ElevatedButton(
                      onPressed: _isGenerating ? null : _generateContent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD62828),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isGenerating
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Generating...'),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome),
                                SizedBox(width: 8),
                                Text(
                                  'Generate with AI',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    
                    if (_metadata != null) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        'Generation Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMetadataItem(
                        'Word Count',
                        '${_metadata!['wordCount']} words',
                        Icons.text_fields,
                      ),
                      _buildMetadataItem(
                        'Reading Time',
                        '~${_metadata!['estimatedReadingTime']} min',
                        Icons.schedule,
                      ),
                      _buildMetadataItem(
                        'Tokens Used',
                        '${_metadata!['tokensUsed'] ?? 'N/A'}',
                        Icons.data_usage,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Right panel: Generated content preview
          Expanded(
            child: Container(
              color: Colors.white,
              child: _generatedContent == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Generated content will appear here',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Markdown(
                      data: _generatedContent!,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1E3F),
                        ),
                        h2: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1E3F),
                        ),
                        h3: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1E3F),
                        ),
                        p: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                        listBullet: const TextStyle(fontSize: 16),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1E3F),
            ),
          ),
        ],
      ),
    );
  }
}
