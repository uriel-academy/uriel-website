import * as functions from 'firebase-functions';
import OpenAI from 'openai';

export const generateStudyPlan = functions
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
    goal,
    examDate,
    weeklyHours,
    preferredTime,
    availability,
    subjects,
    sessionLength,
    breakLength,
  } = data;

  if (!goal || !weeklyHours || !subjects || subjects.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    const apiKey = process.env.OPENAI_KEY;

    if (!apiKey) {
      console.error('OPENAI_KEY environment variable not set');
      throw new Error('OPENAI_KEY not configured');
    }

    const openai = new OpenAI({
      apiKey: apiKey,
    });

    // Calculate days until exam if provided
    let daysUntilExam = null;
    if (examDate) {
      const exam = new Date(examDate);
      const today = new Date();
      daysUntilExam = Math.ceil((exam.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
    }

    // Construct the prompt
    const prompt = `You are an expert educational consultant specializing in creating personalized study plans for Ghanaian students following the NaCCA curriculum.

Create a comprehensive, personalized study plan with the following parameters:

STUDENT GOALS:
- Study Goal: ${goal}
${daysUntilExam ? `- Days until exam: ${daysUntilExam} days (Exam date: ${examDate})` : ''}
- Weekly available hours: ${weeklyHours} hours
- Preferred study time: ${preferredTime}
- Session length: ${sessionLength} minutes
- Break length: ${breakLength} minutes

SUBJECTS TO COVER (${subjects.length}):
${subjects.map((s: any, i: number) => `${i + 1}. ${s.name} (Priority: ${s.priority || 'Medium'})`).join('\n')}

STUDY AVAILABILITY:
${availability ? JSON.stringify(availability, null, 2) : 'Flexible schedule'}

REQUIREMENTS:
1. Create a realistic weekly study schedule that fits within ${weeklyHours} hours
2. Distribute subjects based on priority levels
3. Include ${sessionLength}-minute study sessions with ${breakLength}-minute breaks
4. Follow proven study techniques (spaced repetition, active recall, Pomodoro)
5. Account for the ${preferredTime} preference
6. Include variety to prevent burnout
7. Add buffer time for review and catch-up
8. ${daysUntilExam ? `Structure the plan to cover all topics before the exam in ${daysUntilExam} days` : 'Create a sustainable long-term schedule'}
9. Align with GES/NaCCA curriculum standards
10. Include specific daily and weekly goals

STUDY PLAN STRUCTURE:
- Weekly schedule with daily breakdown
- Specific topics to cover each day
- Study techniques recommended for each session
- Progress milestones
- Review and assessment points
- Motivation tips and stress management advice

Return a valid JSON object with this structure:
{
  "weeklySchedule": {
    "Monday": [
      {
        "time": "17:00-17:45",
        "subject": "Mathematics",
        "topic": "Algebra fundamentals",
        "activity": "Practice problems",
        "duration": 45
      }
    ],
    // ... other days
  },
  "studyTechniques": [
    "Use active recall for memorization",
    "Create mind maps for complex topics"
  ],
  "milestones": [
    {
      "week": 1,
      "goals": ["Complete Chapter 1 of Mathematics", "Review Science notes"],
      "assessment": "Take practice quiz"
    }
  ],
  "dailyRoutine": {
    "preparation": "Review previous notes for 5 minutes",
    "coreStudy": "Focus on planned subject for ${sessionLength} minutes",
    "break": "Take ${breakLength}-minute break",
    "review": "Summarize what you learned in 5 minutes"
  },
  "tips": [
    "Start with most challenging subject when energy is high",
    "Take short breaks to maintain focus"
  ],
  "trackingMetrics": [
    "Hours studied per week",
    "Topics completed",
    "Quiz scores"
  ]
}

Make the plan SPECIFIC, ACTIONABLE, and REALISTIC for a Ghanaian ${goal === 'Exam preparation' ? 'BECE/WASSCE' : ''} student.`;

    console.log('Calling OpenAI API for study plan generation...');

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are an expert educational consultant creating personalized study plans for Ghanaian students. Return only valid JSON without any markdown formatting or code blocks.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      temperature: 0.7,
      max_tokens: 4000,
    });

    console.log('OpenAI API call successful');

    const responseText = completion.choices[0]?.message?.content || '{}';
    
    // Clean up the response (remove markdown code blocks if present)
    let cleanedResponse = responseText.trim();
    if (cleanedResponse.startsWith('```json')) {
      cleanedResponse = cleanedResponse.replace(/^```json\n/, '').replace(/\n```$/, '');
    } else if (cleanedResponse.startsWith('```')) {
      cleanedResponse = cleanedResponse.replace(/^```\n/, '').replace(/\n```$/, '');
    }

    const studyPlan = JSON.parse(cleanedResponse);

    return {
      success: true,
      studyPlan: studyPlan,
      metadata: {
        goal,
        weeklyHours,
        subjects: subjects.length,
        daysUntilExam,
        generatedAt: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('Error generating study plan:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to generate study plan: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
});
