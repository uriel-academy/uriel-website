import {onCall, HttpsError} from 'firebase-functions/v2/https';
import OpenAI from 'openai';

export const generateAIQuiz = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'User must be authenticated');
  }

  const {
    subject,
    examType,
    numQuestions,
    customTopic,
  } = request.data;

  if (!subject || !examType || !numQuestions) {
    throw new HttpsError('invalid-argument', 'Missing required parameters');
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

    // Map difficulty based on exam type
    const difficultyLevel = examType === 'BECE' ? 'medium' : 'hard';

    // Construct detailed prompt for quiz generation
    const prompt = `You are an expert Ghanaian educator creating a ${examType} level quiz for students in ${subject}.

${customTopic ? `Focus specifically on the topic: ${customTopic}` : `Cover general curriculum topics for this subject appropriate for Ghanaian ${examType} exams.`}

Generate ${questionCount} multiple-choice questions following these requirements:

1. Each question should have exactly 4 options (A, B, C, D)
2. Mark the correct answer clearly (must be one of: A, B, C, or D)
3. Include brief explanations for the correct answer
4. Questions should be appropriate for ${difficultyLevel} difficulty level
5. Questions should align with Ghanaian curriculum standards for ${examType}
6. Use clear, educational language suitable for Ghanaian JHS students
7. For math/science questions, use proper formatting
8. Ensure questions are culturally relevant to Ghana

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
      "difficulty": "${difficultyLevel}",
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
          content: 'You are an expert Ghanaian educator. Generate educational quiz questions in valid JSON format only, without any markdown or additional text.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 0.7,
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
    throw new HttpsError(
      'internal',
      `Failed to generate quiz: ${errorMessage}`
    );
  }
});
