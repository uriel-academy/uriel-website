import * as functions from 'firebase-functions';
import OpenAI from 'openai';

export const generateLessonPlan = functions
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
    strand,
    subStrand,
    indicator,
    title,
    objectives,
    competencies,
    values,
    level,
    duration,
  } = data;

  if (!subject || !level) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: subject and level');
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

    // Construct the prompt for GES/NaCCA aligned lesson plan
    const prompt = `You are an expert Ghanaian educator with deep knowledge of the Ghana Education Service (GES) and National Council for Curriculum and Assessment (NaCCA) curriculum standards.

Create a comprehensive, GES-approved lesson plan with the following details:

LESSON INFORMATION:
- Subject: ${subject}
- Level: ${level}
- Duration: ${duration} minutes
${strand ? `- Strand: ${strand}` : ''}
${subStrand ? `- Sub-strand: ${subStrand}` : ''}
${indicator ? `- Learning Indicator: ${indicator}` : ''}
${title ? `- Lesson Title: ${title}` : ''}
${objectives ? `- Learning Objectives: ${objectives}` : ''}

CORE COMPETENCIES TO INTEGRATE:
${competencies && competencies.length > 0 ? competencies.join(', ') : 'All NaCCA core competencies as applicable'}

VALUES TO INTEGRATE:
${values && values.length > 0 ? values.join(', ') : 'Respect, Integrity, Excellence'}

REQUIREMENTS:
1. Follow the standard GES lesson plan format
2. Align with NaCCA curriculum standards and learning indicators
3. Use the 3-part lesson structure:
   - Introduction/Starter (10-15 min)
   - Main Activity/Development (30-40 min)
   - Plenary/Closure (10-15 min)
4. Include differentiation strategies for mixed-ability classes
5. Integrate appropriate Teaching Learning Materials (TLMs)
6. Include formative assessment opportunities
7. Map to specified core competencies
8. Integrate Ghanaian cultural values
9. Provide subject-specific practices (inquiry, problem-solving, etc.)
10. Include cross-curricular links where relevant
11. Use Ghanaian educational context and examples
12. Consider inclusive education principles

LESSON PLAN FORMAT:
Return a detailed lesson plan with:
- Clear learning outcomes (what students will know, understand, and be able to do)
- Step-by-step teaching procedures
- Student activities
- Assessment methods (formative and summative)
- Required resources and materials
- Differentiation strategies
- Homework/extension activities

Return a valid JSON object with this structure:
{
  "metadata": {
    "subject": "${subject}",
    "level": "${level}",
    "strand": "${strand || 'To be specified'}",
    "subStrand": "${subStrand || 'To be specified'}",
    "indicator": "${indicator || 'To be specified'}",
    "duration": ${duration},
    "date": "To be filled by teacher"
  },
  "lessonTitle": "${title || 'To be specified'}",
  "learningOutcomes": [
    "By the end of the lesson, students will be able to...",
    "Students will understand...",
    "Students will demonstrate..."
  ],
  "coreCompetencies": ${JSON.stringify(competencies || [])},
  "values": ${JSON.stringify(values || [])},
  "prerequisites": [
    "Knowledge/skills students need before this lesson"
  ],
  "teachingLearningMaterials": [
    "Charts, markers, textbooks, etc."
  ],
  "lessonStructure": {
    "introduction": {
      "duration": "10-15 minutes",
      "teacherActivity": [
        "Step-by-step what teacher does"
      ],
      "studentActivity": [
        "What students do"
      ],
      "assessment": "How to check understanding"
    },
    "mainActivity": {
      "duration": "30-40 minutes",
      "teacherActivity": [
        "Detailed teaching steps"
      ],
      "studentActivity": [
        "Student engagement activities"
      ],
      "differentiation": {
        "support": "For students who need extra help",
        "stretch": "For advanced students"
      },
      "assessment": "Formative assessment strategies"
    },
    "plenary": {
      "duration": "10-15 minutes",
      "teacherActivity": [
        "Summary and consolidation"
      ],
      "studentActivity": [
        "Reflection and assessment"
      ],
      "assessment": "Exit ticket or quick check"
    }
  },
  "assessment": {
    "formative": [
      "Questioning, observation, etc."
    ],
    "summative": [
      "Quiz, test, project"
    ],
    "successCriteria": [
      "How to know students have met the learning outcomes"
    ]
  },
  "homework": [
    "Extension activities and practice"
  ],
  "reflection": {
    "whatWorked": "To be completed after lesson",
    "challenges": "To be completed after lesson",
    "improvements": "To be completed after lesson"
  },
  "crossCurricularLinks": [
    "Connections to other subjects"
  ],
  "inclusiveEducation": [
    "Considerations for SEN students and diverse learners"
  ]
}

Make the lesson plan PRACTICAL, DETAILED, and fully aligned with GES/NaCCA standards for Ghanaian ${level} education.`;

    console.log('Calling OpenAI API for lesson plan generation...');

    const completion = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: [
        {
          role: 'system',
          content: 'You are an expert Ghanaian educator creating GES/NaCCA aligned lesson plans. Return only valid JSON without any markdown formatting or code blocks.',
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

    const lessonPlan = JSON.parse(cleanedResponse);

    return {
      success: true,
      lessonPlan: lessonPlan,
      metadata: {
        subject,
        level,
        duration,
        generatedAt: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('Error generating lesson plan:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Failed to generate lesson plan: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
});
