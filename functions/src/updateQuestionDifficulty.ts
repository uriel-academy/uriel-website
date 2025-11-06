import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Cloud Function to update question difficulty scores
 * Runs weekly on Sunday at 2 AM UTC
 * Calculates crowd-sourced difficulty based on student success rates
 */
export const updateQuestionDifficulties = functions
  .runWith({
    timeoutSeconds: 540, // 9 minutes
    memory: '1GB',
  })
  .pubsub.schedule('0 2 * * 0') // Every Sunday at 2 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🚀 Starting weekly question difficulty update...');

    try {
      const subjects = [
        'Religious and Moral Education',
        'Mathematics',
        'English Language',
        'Integrated Science',
        'Social Studies',
      ];

      for (const subject of subjects) {
        await updateSubjectDifficulties(subject);
      }

      console.log('✅ Question difficulty update completed successfully!');
      return null;
    } catch (error) {
      console.error('❌ Error updating question difficulties:', error);
      throw error;
    }
  });

/**
 * Update difficulties for all questions in a subject
 */
async function updateSubjectDifficulties(subject: string): Promise<void> {
  console.log(`📚 Processing subject: ${subject}`);

  // Get all unique question IDs for this subject
  const attemptsSnapshot = await db
    .collectionGroup('questionAttempts')
    .where('subject', '==', subject)
    .get();

  if (attemptsSnapshot.empty) {
    console.log(`⚠️ No attempts found for ${subject}`);
    return;
  }

  // Group attempts by question ID
  const attemptsByQuestion = new Map<string, any[]>();
  
  for (const doc of attemptsSnapshot.docs) {
    const data = doc.data();
    const questionId = data.questionId;
    
    if (!attemptsByQuestion.has(questionId)) {
      attemptsByQuestion.set(questionId, []);
    }
    attemptsByQuestion.get(questionId)!.push(data);
  }

  console.log(`📊 Found ${attemptsByQuestion.size} unique questions`);

  // Update difficulty for each question
  const batch = db.batch();
  let batchCount = 0;
  let updatedCount = 0;

  for (const [questionId, attempts] of attemptsByQuestion.entries()) {
    // Require at least 20 attempts for reliable difficulty calculation
    if (attempts.length < 20) {
      continue;
    }

    // Calculate success rate
    const correctCount = attempts.filter((a) => a.isCorrect === true).length;
    const successRate = correctCount / attempts.length;

    // Convert to difficulty score (0-1, where 1 is hardest)
    const difficulty = 1.0 - successRate;

    // Convert difficulty to weight (0.7-1.3 range)
    const weight = 0.7 + difficulty * 0.6;

    // Determine difficulty label
    let label = 'Medium';
    if (difficulty < 0.3) {
      label = 'Easy';
    } else if (difficulty >= 0.6) {
      label = 'Hard';
    }

    // Store in questionDifficulty collection
    const docRef = db.collection('questionDifficulty').doc(questionId);
    
    batch.set(docRef, {
      questionId,
      difficulty: parseFloat(difficulty.toFixed(4)),
      weight: parseFloat(weight.toFixed(4)),
      label,
      subject,
      successRate: parseFloat(successRate.toFixed(4)),
      totalAttempts: attempts.length,
      correctAttempts: correctCount,
      calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    batchCount++;
    updatedCount++;

    // Commit every 500 operations (Firestore batch limit)
    if (batchCount >= 500) {
      await batch.commit();
      console.log(`💾 Committed batch of ${batchCount} updates`);
      batchCount = 0;
    }
  }

  // Commit remaining updates
  if (batchCount > 0) {
    await batch.commit();
    console.log(`💾 Committed final batch of ${batchCount} updates`);
  }

  console.log(`✅ Updated ${updatedCount} questions for ${subject}`);
}

/**
 * HTTP function to manually trigger difficulty update
 * Can be called via: curl -X POST https://your-region-your-project.cloudfunctions.net/manualUpdateDifficulties
 */
export const manualUpdateDifficulties = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '1GB',
  })
  .https.onRequest(async (req, res) => {
    // Verify admin token
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).send('Unauthorized');
      return;
    }

    try {
      const token = authHeader.split('Bearer ')[1];
      const decodedToken = await admin.auth().verifyIdToken(token);
      
      // Check if user is admin
      const userDoc = await db.collection('users').doc(decodedToken.uid).get();
      const userData = userDoc.data();
      
      if (userData?.role !== 'super_admin' && userData?.role !== 'admin') {
        res.status(403).send('Forbidden: Admin access required');
        return;
      }

      // Trigger update
      console.log('🔧 Manual update triggered by:', decodedToken.email);
      
      const subjects = [
        'Religious and Moral Education',
        'Mathematics',
        'English Language',
        'Integrated Science',
        'Social Studies',
      ];

      for (const subject of subjects) {
        await updateSubjectDifficulties(subject);
      }

      res.status(200).json({
        success: true,
        message: 'Question difficulties updated successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      console.error('Error in manual update:', error);
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      });
    }
  });

/**
 * Get difficulty statistics for a subject
 * Useful for analytics and monitoring
 */
export const getSubjectDifficultyStats = functions.https.onCall(
  async (data, context) => {
    const { subject } = data;

    if (!subject) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Subject is required'
      );
    }

    try {
      const snapshot = await db
        .collection('questionDifficulty')
        .where('subject', '==', subject)
        .get();

      if (snapshot.empty) {
        return {
          easy: 0,
          medium: 0,
          hard: 0,
          total: 0,
          avgDifficulty: 0.5,
        };
      }

      let easy = 0;
      let medium = 0;
      let hard = 0;
      let totalDifficulty = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const difficulty = data.difficulty || 0.5;
        totalDifficulty += difficulty;

        if (difficulty < 0.3) {
          easy++;
        } else if (difficulty < 0.6) {
          medium++;
        } else {
          hard++;
        }
      }

      return {
        easy,
        medium,
        hard,
        total: snapshot.size,
        avgDifficulty: parseFloat((totalDifficulty / snapshot.size).toFixed(4)),
        subject,
      };
    } catch (error) {
      console.error('Error getting subject stats:', error);
      throw new functions.https.HttpsError('internal', 'Failed to get stats');
    }
  }
);
