import 'package:flutter/material.dart';

class TriviaPage extends StatefulWidget {
  final int questionCount;
  const TriviaPage({super.key, this.questionCount = 20});

  @override
  State<TriviaPage> createState() => _TriviaPageState();
}

class _TriviaPageState extends State<TriviaPage> {
  final List<String> categories = [
    'General',
    'World History',
    'Science',
    'Africa History',
    'Maths',
    'Geography',
    'Sports',
    'Entertainment',
  ];

  final Map<String, List<Map<String, dynamic>>> questions = {
    'General': List.generate(50, (i) => {
      'question': 'General Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'A',
    }),
    'World History': List.generate(50, (i) => {
      'question': 'World History Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'B',
    }),
    'Science': List.generate(50, (i) => {
      'question': 'Science Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'C',
    }),
    'Africa History': List.generate(50, (i) => {
      'question': 'Africa History Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'D',
    }),
    'Maths': List.generate(50, (i) => {
      'question': 'Maths Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'A',
    }),
    'Geography': List.generate(50, (i) => {
      'question': 'Geography Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'B',
    }),
    'Sports': List.generate(50, (i) => {
      'question': 'Sports Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'C',
    }),
    'Entertainment': List.generate(50, (i) => {
      'question': 'Entertainment Question ${i + 1}?',
      'options': ['A', 'B', 'C', 'D'],
      'answer': 'D',
    }),
  };

  String selectedCategory = 'General';
  int currentIndex = 0;
  int score = 0;
  bool showResult = false;

  void _nextQuestion(bool correct) {
    if (correct) score++;
    if (currentIndex < questions[selectedCategory]!.length - 1) {
      setState(() {
        currentIndex++;
      });
    } else {
      setState(() {
        showResult = true;
      });
    }
  }

  void _restart() {
    setState(() {
      currentIndex = 0;
      score = 0;
      showResult = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final qList = questions[selectedCategory]!;
    final q = qList[currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trivia'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: selectedCategory,
              items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedCategory = val;
                    currentIndex = 0;
                    score = 0;
                    showResult = false;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            if (!showResult) ...[
              Text('Question ${currentIndex + 1} of 50', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(q['question'], style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ...List.generate(4, (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _nextQuestion(q['options'][i] == q['answer']),
                  child: Text(q['options'][i]),
                ),
              )),
            ] else ...[
              Text('Quiz Complete!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Your score: $score / 50', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _restart,
                child: const Text('Restart'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
