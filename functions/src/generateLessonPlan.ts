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
    const prompt = `You are an expert Ghanaian educator with deep knowledge of the Ghana Education Service (GES) and National Council for Curriculum and Assessment (NaCCA) Common Core Programme (CCP) and Standard-Based Curriculum (SBC).

Reference the official GES/NACCA curriculum documents available in the public domain, particularly the Standard-Based Curriculum for ${level} ${subject}.

Create a comprehensive, GES-approved lesson plan based on the SBC/CCP framework with the following details:

LESSON INFORMATION:
- Subject: ${subject}
- Level: ${level}
- Duration: ${duration} minutes
${strand ? `- Strand: ${strand}` : ''}
${subStrand ? `- Sub-strand: ${subStrand}` : ''}
${indicator ? `- Learning Indicator: ${indicator}` : ''}
${title ? `- Lesson Title: ${title}` : ''}
${objectives ? `- Learning Objectives: ${objectives}` : ''}

CORE COMPETENCIES TO INTEGRATE (from NaCCA framework):
${competencies && competencies.length > 0 ? competencies.join(', ') : 'Critical Thinking & Problem Solving, Communication & Collaboration, Cultural Identity & Global Citizenship, Personal Development & Leadership, Creativity & Innovation, Digital Literacy'}

VALUES TO INTEGRATE (Ghanaian Values):
${values && values.length > 0 ? values.join(', ') : 'Respect, Integrity, Excellence, Commitment, Teamwork, Patriotism'}

REQUIREMENTS - Follow GES/NACCA SBC Standards:
1. Use the official GES lesson plan format following SBC guidelines
2. Align strictly with NaCCA curriculum strands, sub-strands, and content standards
3. Reference specific learning indicators from the ${subject} curriculum
4. Use the standard 3-part lesson structure with realistic timing:
   - Introduction/Starter (5-10 min) - engage, review prior knowledge
   - Teaching/Exploration & Guided Practice (25-35 min) - main instruction, activities
   - Plenary/Conclusion (5-10 min) - summary, assessment, homework
5. Include differentiation for mixed-ability learners (support vs. stretch)
6. Specify practical Teaching Learning Materials (TLMs) available in Ghanaian schools
7. Include both formative and summative assessment aligned to SBC
8. Integrate all 6 NaCCA core competencies naturally
9. Embed Ghanaian cultural context, examples, and local community relevance
10. Use subject-specific pedagogies (inquiry-based, problem-solving, activity-based learning)
11. Include cross-cutting themes: environmental education, citizenship, health
12. Consider inclusive education for diverse learners and SEN students
13. Use Ghanaian place names, contexts, and culturally relevant examples
14. Align assessment to knowledge + skills + attitudes as per CCP emphasis

LESSON PLAN FORMAT - Follow GES/NACCA SBC Structure:
Return a detailed, practical lesson plan that a Ghanaian teacher can use immediately with:
- Clear learning objectives (what learners will be able to DO by end of lesson)
- Specific curriculum alignment (strand, sub-strand, content standard, indicator)
- Realistic step-by-step procedures with actual timing
- Concrete student activities (not just "discuss" - specify what and how)
- Practical TLMs that exist in Ghanaian schools
- Assessment methods aligned to SBC (knowledge, skills, attitudes)
- Differentiation for support learners and extension/stretch
- Ghanaian context and examples throughout

EXAMPLE STYLE: Like "Understanding My Community and Environment" - JHS 1 Social Studies (Strand: Environment)
- Use realistic Ghanaian scenarios and places
- Include warm-up questions students will actually engage with
- Specify group work instructions clearly (e.g., "3-4 per group, give chart paper")
- Name actual activities teachers can do (not vague instructions)
- Reference real Ghanaian curriculum documents and structure

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
      "duration": "5-10 minutes",
      "activities": [
        "Greet class and state the topic clearly",
        "Warm-up question to engage students (specify exact question)",
        "Review prior knowledge briefly",
        "State learning objectives in student-friendly language",
        "Explain why this topic matters to their lives"
      ],
      "teacherRole": "Facilitator, questioner, engager",
      "studentRole": "Participate, answer questions, share prior knowledge",
      "assessment": "Listen to student responses, check prior understanding"
    },
    "teachingAndExploration": {
      "duration": "15-20 minutes",
      "activities": [
        "Present key concepts with definitions (use board/chart)",
        "Use visual aids, maps, pictures, or real objects",
        "Explain with Ghanaian examples and local context",
        "Ask probing questions throughout",
        "Demonstrate or model if needed",
        "Check understanding frequently"
      ],
      "teacherRole": "Instructor, explainer, demonstrator",
      "studentRole": "Listen, observe, ask questions, take notes",
      "tlmsUsed": ["List specific materials like charts, pictures, local items"],
      "assessment": "Ask questions during teaching, observe reactions"
    },
    "guidedPractice": {
      "duration": "10-15 minutes",
      "activities": [
        "Organize students into groups (specify size: 3-4 students)",
        "Give clear task with specific deliverable (e.g., chart, list, drawing)",
        "Provide materials (chart paper, markers, worksheets)",
        "Circulate among groups asking questions",
        "Guide groups who are struggling",
        "Encourage collaboration and all students to participate"
      ],
      "groupWork": "Specific task with clear instructions and time limit",
      "differentiation": {
        "supportLearners": "Provide sentence starters, work in pairs, give picture prompts, pre-teach vocabulary",
        "stretchLearners": "Ask higher-order questions, give leadership roles, add extension tasks"
      },
      "assessment": "Observe group participation, check group outputs, ask probing questions"
    },
    "groupReporting": {
      "duration": "5-10 minutes",
      "activities": [
        "Each group presents briefly (1-2 minutes)",
        "Ask class to comment or ask questions after each",
        "Summarize key points from all presentations",
        "Connect presentations to learning objectives"
      ],
      "assessment": "Evaluate group presentations, check understanding across class"
    },
    "individualApplication": {
      "duration": "3-5 minutes",
      "activities": [
        "Students write individually in notebooks",
        "Reflect on what they learned",
        "Note one thing they will do or remember",
        "Connect to their own lives or community"
      ],
      "assessment": "Check notebooks, read reflections"
    },
    "conclusion": {
      "duration": "3-5 minutes",
      "activities": [
        "Summarize key learning points from the lesson",
        "Restate learning objectives - did we achieve them?",
        "Give positive reinforcement",
        "Preview next lesson topic",
        "Assign homework/task with clear instructions"
      ],
      "homework": "Specific, achievable task related to the lesson",
      "assessment": "Quick exit question or reflection"
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

CRITICAL REQUIREMENTS:
1. Make the lesson plan PRACTICAL - a teacher should be able to use it tomorrow
2. Use CONCRETE examples from Ghanaian context (places, names, situations)
3. SPECIFY exact questions to ask, not just "ask questions"
4. DETAIL group work instructions (group size, task, materials, time)
5. Include REALISTIC timing for each section
6. Reference actual GES/NACCA curriculum strands and indicators for ${subject}
7. Use Ghanaian educational terminology (learners, TLMs, SBC, CCP)
8. Align to SBC focus: Knowledge + Skills + Attitudes/Values
9. Include cross-cutting themes: environment, citizenship, health, etc.
10. Make assessment authentic and practical (not just "questioning")

Make this lesson plan something a real Ghanaian ${level} teacher can walk into class and use effectively, following official GES/NACCA SBC standards.`;

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
