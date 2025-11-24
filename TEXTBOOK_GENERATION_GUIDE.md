# AI Textbook Generation System

## Overview

The Uriel Academy platform now includes a comprehensive AI-powered textbook generation system using **Claude 3.5 Sonnet** (Anthropic). This system can automatically generate high-quality educational content aligned with Ghana's NACCA curriculum.

## Features

✅ **Full Lesson Generation** - Comprehensive study materials with objectives, explanations, examples, and practice questions  
✅ **Quick Summaries** - Concise revision materials  
✅ **Practice Questions** - BECE/WASSCE-style assessments with marking schemes  
✅ **Worked Examples** - Step-by-step solutions  
✅ **Multi-language Support** - English, Twi, Ewe, Ga  
✅ **Batch Processing** - Generate multiple topics simultaneously  
✅ **Chapter Organization** - Group related topics into chapters  

## Architecture

### Cloud Functions (`functions/src/textbook_generator.ts`)

**Main Functions:**

1. **`generateTextbookContent`** - Generate content for a single topic
   - Input: subject, topic, grade, content type, language
   - Output: Generated content with metadata
   - Model: Claude 3.5 Sonnet
   - Max execution time: 9 minutes
   - Memory: 1GB

2. **`generateChapter`** - Generate entire chapter with multiple topics
   - Processes topics sequentially with rate limiting
   - Creates chapter document linking all sections

3. **`bulkGenerateContent`** - Batch generate multiple topics
   - Background processing with progress tracking
   - Configurable batch sizes (1-10 topics)
   - Job status monitoring

4. **`publishTextbookContent`** - Publish draft content to students
   - Admin-only function
   - Moves content from draft to published status

### Flutter Service (`lib/services/textbook_generation_service.dart`)

**Key Methods:**

```dart
// Generate single topic
await TextbookGenerationService().generateContent(
  subject: 'Mathematics',
  topic: 'Quadratic Equations',
  grade: 'BECE',
  contentType: 'full_lesson',
  language: 'en',
);

// Generate chapter
await TextbookGenerationService().generateChapter(
  subject: 'Science',
  chapterTitle: 'Human Biology',
  topics: [
    {'title': 'Digestive System', 'syllabusRef': 'NACCA 2024 B3.1'},
    {'title': 'Respiratory System', 'syllabusRef': 'NACCA 2024 B3.2'},
  ],
  grade: 'JHS 3',
);

// Bulk generation
await TextbookGenerationService().bulkGenerateContent(
  subject: 'English',
  topics: [...], // List of topics
  grade: 'SHS 1',
  batchSize: 5,
);
```

### Admin UI (`lib/screens/textbook_generator_page.dart`)

A split-panel interface for administrators/teachers:
- **Left Panel**: Input form for generation parameters
- **Right Panel**: Live preview of generated content
- **Export Options**: Save as PDF, Word, or Markdown

## Content Structure

Generated lessons follow this structure:

```markdown
## Learning Objectives
- Objective 1
- Objective 2

## Introduction
[Engaging overview with Ghanaian context]

## Main Content
### Subtopic 1
[Detailed explanation]

### Subtopic 2
[Step-by-step breakdown]

## Worked Examples
[3-5 examples with solutions]

## Key Terms & Definitions
- **Term 1**: Definition
- **Term 2**: Definition

## Practice Questions
[15 questions: 5 MCQ, 5 short answer, 5 essay]

## Summary
- Key point 1
- Key point 2

## Real-World Applications
[Ghanaian context and career connections]
```

## Usage Instructions

### 1. Setup (Already Completed)

```bash
# Anthropic API key configured
firebase functions:config:set anthropic.key="YOUR_KEY"

# Dependencies installed
cd functions
npm install @anthropic-ai/sdk
```

### 2. Deploy Cloud Functions

```bash
firebase deploy --only functions:generateTextbookContent,functions:generateChapter,functions:bulkGenerateContent,functions:publishTextbookContent
```

### 3. Access the Generator

**For Admins/Teachers:**
- Navigate to Admin Dashboard
- Select "Textbook Generator" from menu
- Fill in subject, topic, and parameters
- Click "Generate with AI"
- Review, edit, and publish

**For Students:**
- Access published content through the textbooks section
- Search by subject, grade, or topic
- Read, download, or print materials

## Firestore Collections

### `textbook_content`
```javascript
{
  subject: 'Mathematics',
  topic: 'Quadratic Equations',
  content: '[Full markdown content]',
  syllabusReference: 'NACCA 2024 B3.2',
  grade: 'BECE',
  contentType: 'full_lesson',
  language: 'en',
  wordCount: 2500,
  estimatedReadingTime: 13, // minutes
  status: 'published', // draft, published, archived
  generatedAt: Timestamp,
  generatedBy: 'uid',
  model: 'claude-3-5-sonnet-20241022',
  metadata: {
    tokensUsed: 15000,
    inputTokens: 1000,
    outputTokens: 14000,
  }
}
```

### `textbook_chapters`
```javascript
{
  subject: 'Science',
  title: 'Human Biology',
  grade: 'JHS 3',
  sections: [
    {
      topicTitle: 'Digestive System',
      contentId: 'doc_id_1',
      wordCount: 2000,
    },
    // ... more sections
  ],
  totalSections: 5,
  status: 'draft',
  createdAt: Timestamp,
  createdBy: 'uid',
}
```

### `textbook_generation_jobs`
```javascript
{
  subject: 'Mathematics',
  grade: 'SHS 2',
  topics: [...],
  totalTopics: 10,
  processedTopics: 7,
  status: 'processing', // processing, completed, failed
  results: [
    {
      topicTitle: 'Topic 1',
      contentId: 'doc_id',
      status: 'success',
    },
    // ... more results
  ],
  createdAt: Timestamp,
  createdBy: 'uid',
}
```

## Cost Estimation

**Claude 3.5 Sonnet Pricing:**
- Input: $3.00 per 1M tokens
- Output: $15.00 per 1M tokens

**Typical Generation:**
- Full lesson: ~1,000 input + ~8,000 output tokens
- Cost per lesson: ~$0.12
- 100 lessons: ~$12

**vs. OpenAI GPT-4:**
- GPT-4: ~$0.45 per lesson
- **Claude is 73% cheaper** with better educational content!

## Example Syllabus Topics

### Mathematics (BECE)
1. Numbers and Numerals
2. Fractions, Decimals, and Percentages
3. Ratio, Proportion, and Rate
4. Algebraic Expressions
5. Linear Equations
6. Quadratic Equations
7. Geometry (Lines, Angles, Shapes)
8. Mensuration (Area, Perimeter, Volume)
9. Statistics and Probability
10. Graphs and Coordinate Geometry

### Science (JHS)
1. Cell Biology
2. Human Body Systems
3. Reproduction
4. Ecology and Environment
5. Energy and Work
6. Forces and Motion
7. Matter and States
8. Chemical Reactions
9. Acids, Bases, and Salts
10. Electricity and Magnetism

### English (BECE)
1. Grammar Fundamentals
2. Parts of Speech
3. Sentence Structure
4. Punctuation and Capitalization
5. Vocabulary Building
6. Reading Comprehension
7. Essay Writing
8. Letter Writing
9. Summary Writing
10. Literature Analysis

## Best Practices

### Content Generation

1. **Be Specific**: Use detailed topic names
   - ❌ "Biology"
   - ✅ "The Human Digestive System and Nutrient Absorption"

2. **Include Syllabus References**: Helps Claude align with curriculum
   - Example: "NACCA 2024 Science B3.2 - Digestive System"

3. **Review Before Publishing**: Always have a teacher review AI-generated content

4. **Use Batch Generation Wisely**: Start with 3-5 topics, don't overwhelm the system

5. **Monitor Token Usage**: Track costs in Firestore metadata

### Quality Control

1. **Fact-Check**: Verify scientific accuracy, especially for Science/Math
2. **Cultural Sensitivity**: Ensure examples are appropriate for Ghanaian context
3. **Language Quality**: Check grammar, spelling, British English standards
4. **Accessibility**: Ensure content is age-appropriate for grade level
5. **Practice Questions**: Verify answer keys are correct

## Troubleshooting

### "API rate limit exceeded"
- Wait 60 seconds between requests
- Use batch generation with smaller batch sizes
- Monitor your Anthropic account usage

### "API authentication failed"
- Verify Anthropic API key: `firebase functions:config:get`
- Re-set key: `firebase functions:config:set anthropic.key="NEW_KEY"`
- Redeploy functions

### "Content too generic"
- Add more specific syllabus references
- Include example questions in your prompt
- Use the "worked_examples" content type first to see approach

### "Generation timeout"
- Reduce content complexity
- Split large topics into smaller subtopics
- Increase function timeout in code (max 540 seconds)

## Future Enhancements

- [ ] PDF export with formatting
- [ ] Image generation for diagrams
- [ ] Interactive quizzes embedded in content
- [ ] Audio narration (text-to-speech)
- [ ] Student feedback loop for content improvement
- [ ] Version control for content updates
- [ ] Collaborative editing for teachers
- [ ] AI-powered content recommendations

## Support

For questions or issues:
- Check Firestore `auditLogs` collection for generation history
- Review Cloud Functions logs: `firebase functions:log`
- Contact: [Your support email]

---

**Last Updated**: November 23, 2025  
**Author**: Uriel Academy Development Team  
**AI Model**: Claude 3.5 Sonnet (Anthropic)
