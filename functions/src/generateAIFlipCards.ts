import * as functions from 'firebase-functions';
import OpenAI from 'openai';

export const generateAIFlipCards = functions
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
    numCards,
    customTopic,
    difficultyLevel,
    classLevel,
  } = data;

  if (!subject || !examType || !numCards) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  // Validate number of cards
  const cardCount = Math.min(Math.max(numCards, 1), 40);

  try {
    // Get the OpenAI API key from environment variable
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

    // Construct detailed prompt for flip card generation
    const prompt = `You are an expert Ghanaian educator creating study flip cards for ${targetClassLevel} students.

Subject: ${subject}
Exam Level: ${examType}
Class Level: ${targetClassLevel}
Difficulty: ${difficulty}
${customTopic ? `Specific Topic: ${customTopic}` : 'General curriculum topics'}

Create ${cardCount} QUESTION-BASED flip cards following Ghana NaCCA curriculum standards.

IMPORTANT: Focus on ACTUAL QUESTIONS with direct answers (NOT definitions or "Define:" cards).

CARD FORMAT EXAMPLES:
1. **Factual Questions**: Direct questions requiring specific answers
   - Q: "How many days are in a week?"
   - A: "7"
   
   - Q: "Who is the current president of Ghana?"
   - A: "John Dramani Mahama"
   
   - Q: "What day did God create man according to the Bible?"
   - A: "The 6th day"

2. **Knowledge Questions**: Testing understanding
   - Q: "What is a mouse used for in computing?"
   - A: "To point, click, and interact with items on a computer screen"
   
   - Q: "How many regions are in Ghana?"
   - A: "16 regions"
   
   - Q: "What is the capital of Ghana?"
   - A: "Accra"

3. **Calculation Questions** (for Math):
   - Q: "What is 12 × 8?"
   - A: "96"
   
   - Q: "What is the area of a rectangle with length 5cm and width 3cm?"
   - A: "15 square centimeters"

4. **Concept Questions** (use sparingly):
   - Q: "What happens during photosynthesis?"
   - A: "Plants use sunlight to convert carbon dioxide and water into glucose and oxygen"

REQUIREMENTS:
- 90% should be DIRECT QUESTIONS (like quiz questions but no multiple choice)
- Questions should start with: "What", "Who", "When", "Where", "How many", "Why", etc.
- Avoid "Define:" format - ask actual questions instead
- Answers should be concise and direct (1-3 sentences max)
- Cards MUST be appropriate for ${targetClassLevel} level
- Follow Ghana NaCCA curriculum for ${subject}
- Use Ghanaian context and examples where relevant
- Difficulty level: ${difficulty}
- Questions should test knowledge, not just memorization of definitions

Return ONLY valid JSON with this exact structure:
{
  "cards": [
    {
      "front": "Direct question here?",
      "back": "Concise answer here",
      "explanation": "Brief explanation if needed (optional)",
      "cardType": "factual" | "knowledge" | "calculation" | "concept",
      "difficulty": "${difficulty}",
      "subject": "${subject}",
      "topic": "${customTopic || 'General'}"
    }
  ]
}`;

    console.log('Calling OpenAI API for flip card generation...');

    // Call OpenAI API
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are an expert Ghanaian educator with comprehensive knowledge of the Ghana NaCCA curriculum. Create educational flip cards that help students learn effectively. Generate valid JSON format only, without any markdown or additional text.',
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

    let parsedResponse;
    try {
      parsedResponse = JSON.parse(responseText);
    } catch (parseError) {
      console.error('JSON parse error:', parseError);
      console.error('Response text:', responseText.substring(0, 500));
      throw new Error('Failed to parse AI response as JSON');
    }

    // Extract cards
    const cards = Array.isArray(parsedResponse) ? 
      parsedResponse : 
      (parsedResponse.cards || parsedResponse.data || []);

    if (!Array.isArray(cards) || cards.length === 0) {
      throw new Error('Invalid response format from AI - expected non-empty array');
    }

    // Validate and sanitize each card
    const validatedCards = cards.map((card, index) => {
      if (!card.front || !card.back) {
        throw new Error(`Invalid card format at index ${index}`);
      }

      return {
        front: card.front,
        back: card.back,
        explanation: card.explanation || '',
        cardType: card.cardType || 'question-answer',
        difficulty: card.difficulty || difficulty,
        subject: subject,
        topic: card.topic || customTopic || 'General',
        generatedBy: 'ai',
        generatedAt: new Date().toISOString(),
        requestedBy: auth.uid,
        cardNumber: index + 1,
      };
    });

    console.log(`Successfully generated ${validatedCards.length} flip cards`);

    return {
      success: true,
      cards: validatedCards,
      metadata: {
        subject,
        examType,
        numCards: validatedCards.length,
        customTopic: customTopic || null,
        generatedBy: 'openai',
        generatedAt: new Date().toISOString(),
        model: 'gpt-4o',
      },
    };
  } catch (error) {
    console.error('Error generating AI flip cards:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    throw new functions.https.HttpsError(
      'internal',
      `Failed to generate flip cards: ${errorMessage}`
    );
  }
});
