import * as functions from 'firebase-functions';
import OpenAI from 'openai';

export const generateAIQuiz = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '512MB',
  })
  .https.onCall(async (data, context) => {
  const auth = context.auth;
  if (!auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const {
    subject,
    examType,
    numQuestions,
    customTopic,
    difficultyLevel,
    classLevel,
  } = data;

  if (!subject || !examType || !numQuestions) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  // Validate number of questions
  const questionCount = Math.min(Math.max(numQuestions, 1), 40);

  try {
    // Get the OpenAI API key from environment variable set via Firebase config
    // The key is automatically available as OPENAI_KEY env var
    const apiKey = process.env.OPENAI_KEY;

    if (!apiKey) {
      console.error('OPENAI_KEY environment variable not set');
      throw new Error('OPENAI_KEY not configured. Set with: firebase functions:config:set openai.key="sk-..."');
    }

    const openai = new OpenAI({
      apiKey: apiKey,
    });

    // Use provided difficulty level or map based on exam type
    const difficulty = difficultyLevel || (examType === 'BECE' ? 'medium' : 'hard');
    const targetClassLevel = classLevel || 'JHS 3';

    // Check if this is trivia mode - trivia should be fun, global, and diverse
    const isTriviaMode = examType === 'trivia' || subject === 'trivia' || subject === 'General Knowledge';

    // Construct prompt based on mode (trivia vs academic)
    const prompt = isTriviaMode ? 
    `You are creating a FUN, DIVERSE, and ENGAGING trivia quiz for entertainment and general knowledge.

IMPORTANT TRIVIA REQUIREMENTS:
- This is NOT an academic exam - it's for FUN and relaxation
- Questions should be GLOBALLY diverse - cover all continents, countries, cultures
- NO focus on Ghana or any specific country unless explicitly requested
- Make questions HIGHLY VARIED and RANDOMIZED across different themes
- NEVER repeat similar questions or patterns
- Use unexpected topics, interesting facts, pop culture, history, science, geography, sports, entertainment
- Questions should be surprising and engaging, not predictable
- Avoid repetitive question structures

TOPIC: ${customTopic || 'Random Global Trivia'}
DIFFICULTY: ${difficulty}
NUMBER OF QUESTIONS: ${questionCount}

DIVERSITY CHECKLIST (ensure questions cover):
- Different continents and regions (Africa, Asia, Europe, Americas, Oceania)
- Various time periods (ancient history to modern day)
- Multiple domains (science, culture, sports, arts, nature, technology, food, entertainment)
- Mix of famous and lesser-known facts
- Both serious and fun/quirky questions

${customTopic ? `Focus specifically on: ${customTopic} - but make it globally diverse and surprising!` : `Create MAXIMUM variety - no two questions should feel similar. Cover random interesting topics from around the world.`}

Generate ${questionCount} multiple-choice questions following these requirements:
1. Each question should have exactly 4 options (A, B, C, D)
2. Mark the correct answer clearly (must be one of: A, B, C, or D)
3. Include brief explanations for the correct answer
4. Questions should be HIGHLY DIVERSE and UNPREDICTABLE
5. NO repetitive patterns or similar question structures
6. Cover different regions, time periods, and topics for each question`
    :
    `You are an expert Ghanaian educator with deep knowledge of the Ghana National Council for Curriculum and Assessment (NaCCA) standards and BECE examination format.

You are creating a ${examType} level quiz for ${targetClassLevel} students in ${subject}.

CONTEXT: 
- Target class level: ${targetClassLevel}
- Difficulty level: ${difficulty}
- Follow the Ghana NaCCA curriculum framework for Junior High School (JHS) and Senior High School (SHS)
- For BECE: Questions should reflect the Basic Education Certificate Examination format and standards
- For WASSCE: Questions should reflect the West African Senior School Certificate Examination standards
- Use Ghanaian educational terminology, examples, and context
- Reference topics from the official NaCCA curriculum where applicable
- Ensure questions are appropriate for ${targetClassLevel} level students

${customTopic ? `Focus specifically on the topic: ${customTopic}` : `Cover general curriculum topics for this subject appropriate for Ghanaian ${examType} exams as defined in the NaCCA curriculum.`}

Generate ${questionCount} multiple-choice questions following these requirements:
1. Each question should have exactly 4 options (A, B, C, D)
2. Mark the correct answer clearly (must be one of: A, B, C, or D)
3. Include brief explanations for the correct answer
4. Questions should be appropriate for ${difficulty} difficulty level
5. Questions MUST be suitable for ${targetClassLevel} students
6. Questions MUST align with Ghana NaCCA curriculum standards and ${examType} exam format
7. Use clear, educational language suitable for Ghanaian JHS/SHS students
8. For math/science questions, use proper formatting and show working where helpful
9. Ensure questions are culturally relevant to Ghana (use Ghanaian names, places, contexts)
10. Question format and difficulty should match authentic past ${examType} questions
11. Cover key competencies as outlined in the NaCCA framework

Return a valid JSON object with this exact structure:
{
  "questions": [
    {
      "question": "Question text here",
      "options": {
        "A": "Option A text",
        "B": "Option B text",
        "C": "Option C text",
        "D": "Option D text"
      },
      "correctAnswer": "A",
      "explanation": "Brief explanation of why this is correct",
      "difficulty": "${difficulty}",
      "subject": "${subject}",
      "topic": "${customTopic || 'General'}"
    }
  ]
}`;

    console.log('Calling OpenAI API for quiz generation...');

    // Call OpenAI API
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: isTriviaMode ? 
            'You are a creative trivia master with vast knowledge of global facts, pop culture, history, science, and entertainment. Generate highly diverse, surprising, and engaging trivia questions that span all continents, cultures, and topics. Make questions unpredictable and fun. Generate questions in valid JSON format only, without any markdown or additional text.' :
            'You are an expert Ghanaian educator with comprehensive knowledge of the Ghana NaCCA curriculum, BECE examination standards, and WASSCE requirements. You have extensive experience creating authentic exam questions that align with official Ghana education standards. Generate educational quiz questions in valid JSON format only, without any markdown or additional text.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: isTriviaMode ? 1.0 : 0.7, // Higher temperature for trivia = more randomization
      max_tokens: 8192,
      response_format: {type: 'json_object'},
    });

    // Extract and parse the response
    const responseText = completion.choices[0].message.content?.trim() || '';
    if (!responseText) {
      throw new Error('Empty response from OpenAI');
    }

    console.log('OpenAI response received, parsing...');

    // Try to parse the response (OpenAI JSON mode returns clean JSON)
    let parsedResponse;
    try {
      parsedResponse = JSON.parse(responseText);
    } catch (parseError) {
      console.error('JSON parse error:', parseError);
      console.error('Response text:', responseText.substring(0, 500));
      throw new Error('Failed to parse AI response as JSON');
    }

    // OpenAI might wrap the array in an object
    const questions = Array.isArray(parsedResponse) ? 
      parsedResponse : 
      (parsedResponse.questions || parsedResponse.data || []);

    if (!Array.isArray(questions) || questions.length === 0) {
      throw new Error('Invalid response format from AI - expected non-empty array');
    }

    // Validate and sanitize each question
    const validatedQuestions = questions.map((q, index) => {
      if (!q.question || !q.options || !q.correctAnswer) {
        throw new Error(`Invalid question format at index ${index}`);
      }

      // Ensure options is an object with A, B, C, D keys
      const options = q.options;
      if (!options.A || !options.B || !options.C || !options.D) {
        throw new Error(`Invalid options format at index ${index}`);
      }

      // Validate correct answer is one of A, B, C, D
      const correctAnswer = q.correctAnswer.toUpperCase();
      if (!['A', 'B', 'C', 'D'].includes(correctAnswer)) {
        throw new Error(`Invalid correct answer at index ${index}: ${correctAnswer}`);
      }

      return {
        question: q.question,
        options: {
          A: options.A,
          B: options.B,
          C: options.C,
          D: options.D,
        },
        correctAnswer: correctAnswer,
        explanation: q.explanation || 'No explanation provided',
        difficulty: q.difficulty || difficultyLevel,
        subject: subject,
        topic: q.topic || customTopic || 'General',
        generatedBy: 'ai',
        generatedAt: new Date().toISOString(),
        requestedBy: auth.uid,
        questionNumber: index + 1,
      };
    });

    console.log(`Successfully generated ${validatedQuestions.length} questions`);

    return {
      success: true,
      questions: validatedQuestions,
      metadata: {
        subject,
        examType,
        numQuestions: validatedQuestions.length,
        customTopic: customTopic || null,
        generatedBy: 'openai',
        generatedAt: new Date().toISOString(),
        model: 'gpt-4o',
      },
    };
  } catch (error) {
    console.error('Error generating AI quiz:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    throw new functions.https.HttpsError(
      'internal',
      `Failed to generate quiz: ${errorMessage}`
    );
  }
});
