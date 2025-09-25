import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { z } from 'zod';
import { scoreExam } from './lib/scoring';
import { hasEntitlement, EntitlementType } from './util/entitlement';

admin.initializeApp();
const db = admin.firestore();

// Types and interfaces
interface Question {
  id: string;
  subject?: string;
  difficulty?: 'easy' | 'medium' | 'hard';
  year?: number;
  correctAnswer: string;
  explanation?: string;
  topic?: string;
  active?: boolean;
  subjectId?: string;
  // Add other question properties as needed
}

// Utility: set timestamps on write
function timestamps(obj: any) {
  return {
    ...obj,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// Auth Lifecycle Functions
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const userRef = db.collection('users').doc(user.uid);
  const defaultDoc = {
    role: 'student',
    profile: {
      firstName: user.displayName || '',
      email: user.email || '',
      phone: user.phoneNumber || '',
    },
    settings: { 
      language: ['en'], 
      calmMode: false,
      notifications: { email: true, push: true, sms: false }
    },
    badges: { level: 0, points: 0, streak: 0, earned: [] },
    entitlements: [], // Empty by default - requires purchase
    tenant: { schoolId: null }, // Set via school invitation link
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  
  await userRef.set(defaultDoc);
  
  // Create user aggregate document
  await db.collection('aggregates').doc('user').collection(user.uid).doc('stats').set({
    totalAttempts: 0,
    averageScore: 0,
    bestScore: 0,
    streakCurrent: 0,
    streakBest: 0,
    subjectStats: {},
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    ...timestamps({})
  });
});

// Admin function to grant roles and set custom claims
export const grantRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  
  // Only allow super_admins to grant roles
  const caller = await admin.auth().getUser(context.auth.uid);
  const callerClaims = caller.customClaims || {};
  if (callerClaims.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only super_admin can grant roles');
  }

  const schema = z.object({ 
    uid: z.string(), 
    role: z.enum(['student', 'parent', 'school_admin', 'teacher', 'staff', 'super_admin']), 
    schoolId: z.string().optional(),
    linkedStudentIds: z.array(z.string()).optional() // For parents
  });
  
  const parsed = schema.safeParse(data);
  if (!parsed.success) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');
  }
  
  const { uid, role, schoolId, linkedStudentIds } = parsed.data;

  const claims: any = { role };
  if (schoolId) claims.schoolId = schoolId;
  if (linkedStudentIds) claims.linkedStudentIds = linkedStudentIds;
  
  await admin.auth().setCustomUserClaims(uid, claims);
  
  // Update user document
  await db.collection('users').doc(uid).update({
    role,
    ...(schoolId && { 'tenant.schoolId': schoolId }),
    ...(linkedStudentIds && { linkedStudentIds }),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Log admin action
  await db.collection('audits').add(timestamps({
    action: 'grant_role',
    performedBy: context.auth.uid,
    targetUserId: uid,
    details: { role, schoolId, linkedStudentIds },
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  }));

  return { success: true };
});

// Generate Mock Exam
export const generateMockExam = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    subjectId: z.string(),
    difficultyMix: z.object({
      easy: z.number().min(0).max(1),
      medium: z.number().min(0).max(1),
      hard: z.number().min(0).max(1)
    }).optional(),
    questionCount: z.number().min(10).max(100).default(30)
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { subjectId, difficultyMix = { easy: 0.4, medium: 0.4, hard: 0.2 }, questionCount } = parsed.data;

  // Fetch questions by difficulty
  const questionsQuery = await db.collection('pastQuestions')
    .where('subjectId', '==', subjectId)
    .where('active', '==', true)
    .get();

  const questions: Question[] = questionsQuery.docs.map(doc => ({ 
    id: doc.id, 
    ...doc.data() 
  } as Question));
  
  if (questions.length < questionCount) {
    throw new functions.https.HttpsError('failed-precondition', 'Not enough questions available');
  }

  // Shuffle and select questions based on difficulty mix
  const easyQuestions = questions.filter(q => q.difficulty === 'easy');
  const mediumQuestions = questions.filter(q => q.difficulty === 'medium');
  const hardQuestions = questions.filter(q => q.difficulty === 'hard');

  const selectedQuestions = [
    ...easyQuestions.slice(0, Math.floor(questionCount * difficultyMix.easy)),
    ...mediumQuestions.slice(0, Math.floor(questionCount * difficultyMix.medium)),
    ...hardQuestions.slice(0, Math.floor(questionCount * difficultyMix.hard))
  ];

  // Fill remaining slots with any available questions
  const remainingCount = questionCount - selectedQuestions.length;
  const remainingQuestions = questions.filter(q => !selectedQuestions.find(sq => sq.id === q.id));
  selectedQuestions.push(...remainingQuestions.slice(0, remainingCount));

  // Shuffle final selection
  const shuffledQuestions = selectedQuestions.sort(() => Math.random() - 0.5);

  // Create exam document
  const examRef = db.collection('mockExams').doc();
  const examData = {
    subjectId,
    questionIds: shuffledQuestions.map(q => q.id),
    questionCount: shuffledQuestions.length,
    difficultyMix,
    createdBy: context.auth.uid,
    ...timestamps({})
  };

  await examRef.set(examData);

  return {
    examId: examRef.id,
    questionCount: shuffledQuestions.length,
    subject: subjectId
  };
});

// Submit Attempt with server-side scoring
export const submitAttempt = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({ 
    examId: z.string(), 
    answers: z.array(z.object({ 
      qId: z.string(), 
      answer: z.string().nullable() 
    })) 
  });
  
  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { examId, answers } = parsed.data;
  const uid = context.auth.uid;

  // Load mock exam and questions
  const examSnap = await db.collection('mockExams').doc(examId).get();
  if (!examSnap.exists) throw new functions.https.HttpsError('not-found', 'Exam not found');
  
  const exam = examSnap.data()!;
  const questionIds: string[] = exam.questionIds || [];

  // Fetch questions in batch
  const qSnaps = await Promise.all(
    questionIds.map((id: string) => db.collection('pastQuestions').doc(id).get())
  );
  const questions = qSnaps.map(s => s.exists ? (s.data() as any) : null) as Array<any | null>;

  // Server-side scoring using utility
  const result = scoreExam(questions, answers as any);
  const { score, correct, items } = result;

  // Write attempt
  const attemptRef = db.collection('attempts').doc();
  await attemptRef.set(timestamps({ 
    userId: uid, 
    examId, 
    items, 
    score, 
    correct,
    total: answers.length,
    startedAt: admin.firestore.FieldValue.serverTimestamp(), 
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    tenant: { schoolId: context.auth.token.schoolId || null }
  }));

  // Update user aggregates and badges
  const userAggRef = db.collection('aggregates').doc('user').collection(uid).doc('stats');
  const userAgg = await userAggRef.get();
  const currentStats = userAgg.data() || {};
  
  const newStats = {
    totalAttempts: (currentStats.totalAttempts || 0) + 1,
    averageScore: Math.round(((currentStats.averageScore || 0) * (currentStats.totalAttempts || 0) + score) / ((currentStats.totalAttempts || 0) + 1)),
    bestScore: Math.max(currentStats.bestScore || 0, score),
    lastActivity: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await userAggRef.set(newStats, { merge: true });

  // Update badges and streaks
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  const userData = userDoc.data() || {};
  const badges = userData.badges || { level: 0, points: 0, streak: 0, earned: [] };
  
  badges.points += Math.floor(score / 10); // 10 points per 100% score
  if (score >= 80) {
    badges.streak += 1;
  } else {
    badges.streak = 0;
  }
  
  // Level up logic
  if (badges.points >= (badges.level + 1) * 100) {
    badges.level += 1;
    badges.earned.push(`level_${badges.level}`);
  }

  await userRef.update({
    badges,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  return { score, correct, total: answers.length, pointsEarned: Math.floor(score / 10) };
});

// Issue Signed URL for textbooks
export const issueSignedUrl = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  
  const schema = z.object({ bookId: z.string() });
  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');
  
  const { bookId } = parsed.data;
  const uid = context.auth.uid;

  // Check entitlement
  const userDoc = await db.collection('users').doc(uid).get();
  const entitlements = (userDoc.data() || {})['entitlements'] || [];
  
  if (!entitlements.includes('textbooks') && 
      !entitlements.includes('both') && 
      !entitlements.includes('premium') &&
      context.auth.token.role !== 'super_admin' &&
      context.auth.token.role !== 'school_admin') {
    throw new functions.https.HttpsError('permission-denied', 'No entitlement for textbooks');
  }

  // Generate signed URL via storage
  const storage = admin.storage();
  const bucket = storage.bucket();
  const file = bucket.file(`textbooks/${bookId}.pdf`);
  
  try {
    const [url] = await file.getSignedUrl({ 
      action: 'read', 
      expires: Date.now() + 1000 * 60 * 5 // 5 minutes
    });
    
    // Log access for analytics
    await db.collection('auditLogs').add(timestamps({
      action: 'textbook_access',
      userId: uid,
      bookId,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    }));
    
    return { url };
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to generate signed URL');
  }
});

// AI Solve Question
export const aiSolveQuestion = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    questionId: z.string(),
    userAnswer: z.string().optional(),
    language: z.enum(['en', 'tw', 'ee', 'ga', 'ha']).default('en')
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { questionId, userAnswer, language } = parsed.data;

  // Rate limiting check (simple implementation)
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const userData = userDoc.data();
  
  if (!userData?.entitlements?.includes('premium') && 
      context.auth.token.role !== 'super_admin') {
    // Check daily AI usage limit for non-premium users
    const today = new Date().toISOString().split('T')[0];
    const usageRef = db.collection('aiUsage').doc(`${context.auth.uid}_${today}`);
    const usage = await usageRef.get();
    
    if (usage.exists && (usage.data()?.count || 0) >= 5) {
      throw new functions.https.HttpsError('resource-exhausted', 'Daily AI limit reached');
    }
  }

  // Fetch question
  const questionDoc = await db.collection('pastQuestions').doc(questionId).get();
  if (!questionDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Question not found');
  }

  const questionData = questionDoc.data()!;
  
  // Simple AI response (replace with actual AI service integration)
  const response = {
    explanation: `This is a ${questionData.subject} question about ${questionData.topic}. The correct answer is ${questionData.correctAnswer}.`,
    hints: ['Break down the problem step by step', 'Consider the key concepts involved'],
    correctAnswer: questionData.correctAnswer,
    language
  };

  // Log AI chat
  await db.collection('aiChats').add(timestamps({
    userId: context.auth.uid,
    questionId,
    userAnswer,
    response,
    language,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  }));

  // Update usage tracking
  const today = new Date().toISOString().split('T')[0];
  const usageRef = db.collection('aiUsage').doc(`${context.auth.uid}_${today}`);
  await usageRef.set({
    count: admin.firestore.FieldValue.increment(1),
    lastUsed: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  return response;
});

// Verify Entitlement
export const verifyEntitlement = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    requiredEntitlement: z.enum(['past', 'textbooks', 'both', 'premium'])
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { requiredEntitlement } = parsed.data;

  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  const entitlements: EntitlementType[] = (userDoc.data() || {})['entitlements'] || [];

  const hasAccess = hasEntitlement(entitlements, requiredEntitlement) ||
                    context.auth.token.role === 'super_admin' ||
                    context.auth.token.role === 'school_admin';

  return { hasEntitlement: hasAccess, entitlements };
});

// Flag User for moderation
export const flagUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const schema = z.object({
    flaggedUserId: z.string(),
    reason: z.enum(['inappropriate_content', 'harassment', 'spam', 'cheating', 'other']),
    description: z.string().optional()
  });

  const parsed = schema.safeParse(data);
  if (!parsed.success) throw new functions.https.HttpsError('invalid-argument', 'Invalid payload');

  const { flaggedUserId, reason, description } = parsed.data;

  await db.collection('adminFlags').add(timestamps({
    flaggedUserId,
    reportedBy: context.auth.uid,
    reason,
    description: description || '',
    status: 'pending',
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  }));

  return { success: true };
});

// Scheduled function for weekly reports
export const weeklyReportScheduler = functions.pubsub
  .schedule('0 7 * * 1') // Every Monday at 7 AM
  .timeZone('Africa/Accra')
  .onRun(async (context) => {
    // Get all students and parents
    const usersQuery = await db.collection('users')
      .where('role', 'in', ['student', 'parent'])
      .get();

    const batch = db.batch();
    
    for (const userDoc of usersQuery.docs) {
      const userData = userDoc.data();
      
      if (userData.role === 'student') {
        // Generate student report
        const reportRef = db.collection('reports').doc();
        batch.set(reportRef, timestamps({
          userId: userDoc.id,
          type: 'weekly',
          period: {
            start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
            end: new Date()
          },
          generated: admin.firestore.FieldValue.serverTimestamp()
        }));
      }
    }

    await batch.commit();
    console.log('Weekly reports scheduled for generation');
  });

export default { 
  onUserCreate, 
  grantRole, 
  generateMockExam,
  submitAttempt, 
  issueSignedUrl, 
  aiSolveQuestion,
  verifyEntitlement,
  flagUser,
  weeklyReportScheduler
};