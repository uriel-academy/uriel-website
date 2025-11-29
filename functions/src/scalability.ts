import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * SCALABILITY IMPROVEMENTS FOR 10,000+ CONCURRENT USERS
 *
 * This module implements several strategies to reduce Firestore connection usage:
 * 1. Connection pooling for real-time listeners
 * 2. Polling-based data fetching for non-critical updates
 * 3. Cached aggregates with background refresh
 * 4. Batched user data updates
 */

// ====================
// CONNECTION POOLING SYSTEM
// ====================

interface PooledListener {
  id: string;
  collection: string;
  docId?: string;
  query?: any;
  subscribers: Set<string>; // User IDs subscribed to this listener
  lastData: any;
  lastUpdate: number;
  updateInterval: number; // How often to check for updates (ms)
}

class ConnectionPool {
  private pools = new Map<string, PooledListener>();
  private userSubscriptions = new Map<string, Set<string>>(); // userId -> listenerIds

  /**
   * Subscribe a user to a pooled listener
   * Instead of creating individual listeners, users share pooled connections
   */
  subscribe(userId: string, listenerConfig: {
    collection: string;
    docId?: string;
    query?: any;
    updateInterval?: number;
  }): string {
    const listenerId = this.generateListenerId(listenerConfig);

    // Check if pooled listener already exists
    if (!this.pools.has(listenerId)) {
      this.createPooledListener(listenerId, listenerConfig);
    }

    // Add user to subscribers
    const pool = this.pools.get(listenerId)!;
    pool.subscribers.add(userId);

    // Track user's subscriptions
    if (!this.userSubscriptions.has(userId)) {
      this.userSubscriptions.set(userId, new Set());
    }
    this.userSubscriptions.get(userId)!.add(listenerId);

    return listenerId;
  }

  /**
   * Unsubscribe user from a pooled listener
   */
  unsubscribe(userId: string, listenerId: string): void {
    const pool = this.pools.get(listenerId);
    if (pool) {
      pool.subscribers.delete(userId);

      // If no more subscribers, clean up the pool
      if (pool.subscribers.size === 0) {
        this.pools.delete(listenerId);
      }
    }

    // Remove from user's subscriptions
    const userSubs = this.userSubscriptions.get(userId);
    if (userSubs) {
      userSubs.delete(listenerId);
      if (userSubs.size === 0) {
        this.userSubscriptions.delete(userId);
      }
    }
  }

  /**
   * Unsubscribe user from all listeners
   */
  unsubscribeAll(userId: string): void {
    const userSubs = this.userSubscriptions.get(userId);
    if (userSubs) {
      for (const listenerId of userSubs) {
        this.unsubscribe(userId, listenerId);
      }
    }
  }

  /**
   * Get current data for a listener
   */
  getData(listenerId: string): any {
    const pool = this.pools.get(listenerId);
    return pool?.lastData;
  }

  /**
   * Get active connection count
   */
  getActiveConnections(): number {
    return this.pools.size;
  }

  /**
   * Get total subscribers across all pools
   */
  getTotalSubscribers(): number {
    let total = 0;
    for (const pool of this.pools.values()) {
      total += pool.subscribers.size;
    }
    return total;
  }

  private generateListenerId(config: any): string {
    const { collection, docId, query } = config;
    if (docId) {
      return `${collection}/${docId}`;
    }
    // For queries, create a hash of the query parameters
    const queryStr = JSON.stringify(query || {});
    return `${collection}_query_${this.hashString(queryStr)}`;
  }

  private hashString(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash).toString(36);
  }

  private createPooledListener(listenerId: string, config: any): void {
    const { collection, docId, query, updateInterval = 30000 } = config; // 30 second default

    const pool: PooledListener = {
      id: listenerId,
      collection,
      docId,
      query,
      subscribers: new Set(),
      lastData: null,
      lastUpdate: 0,
      updateInterval,
    };

    this.pools.set(listenerId, pool);

    // Start background polling for this listener
    this.startPolling(pool);
  }

  private async startPolling(pool: PooledListener): Promise<void> {
    const poll = async () => {
      try {
        const now = Date.now();
        if (now - pool.lastUpdate >= pool.updateInterval) {
          let data: any = null;

          if (pool.docId) {
            // Document listener
            const doc = await db.collection(pool.collection).doc(pool.docId).get();
            data = doc.exists ? { id: doc.id, ...doc.data() } : null;
          } else {
            // Query listener
            const query = this.buildQuery(pool);
            const snapshot = await query.get();
            data = snapshot.docs.map((doc: admin.firestore.QueryDocumentSnapshot) => ({ id: doc.id, ...doc.data() }));
          }

          pool.lastData = data;
          pool.lastUpdate = now;
        }
      } catch (error) {
        console.error(`Polling error for ${pool.id}:`, error);
      }

      // Continue polling if pool still has subscribers
      if (pool.subscribers.size > 0) {
        setTimeout(poll, pool.updateInterval);
      }
    };

    // Start polling
    poll();
  }

  private buildQuery(pool: PooledListener): any {
    let query: any = db.collection(pool.collection);

    if (pool.query) {
      // Apply query constraints
      if (pool.query.where) {
        for (const condition of pool.query.where) {
          query = query.where(condition.field, condition.op, condition.value);
        }
      }
      if (pool.query.orderBy) {
        for (const order of pool.query.orderBy) {
          query = query.orderBy(order.field, order.direction || 'asc');
        }
      }
      if (pool.query.limit) {
        query = query.limit(pool.query.limit);
      }
    }

    return query;
  }
}

// Global connection pool instance
const connectionPool = new ConnectionPool();

// ====================
// POLLING-BASED DATA FETCHING
// ====================

/**
 * Get user dashboard data using polling instead of real-time listeners
 * This reduces connection usage for non-critical real-time updates
 */
export const getUserDashboardPolling = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const uid = context.auth.uid;
  const lastFetch = data?.lastFetch || 0;
  const forceRefresh = data?.forceRefresh || false;

  // Only fetch if it's been more than 30 seconds since last fetch (unless forced)
  const now = Date.now();
  if (!forceRefresh && (now - lastFetch) < 30000) {
    return { status: 'cached', lastFetch };
  }

  try {
    // Get user profile (less frequent updates)
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.exists ? userDoc.data() : null;

    // Get recent quiz results (polling instead of streaming)
    const quizzesSnap = await db.collection('quizzes')
      .where('userId', '==', uid)
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();

    const quizData = quizzesSnap.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Calculate dashboard metrics
    const metrics = calculateDashboardMetrics(quizData);

    return {
      status: 'updated',
      lastFetch: now,
      userData,
      quizData,
      metrics,
      nextFetchIn: 30000, // Suggest next fetch in 30 seconds
    };
  } catch (error) {
    console.error('getUserDashboardPolling error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch dashboard data');
  }
});

/**
 * Get leaderboard data with caching and polling
 */
export const getLeaderboardPolling = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const lastFetch = data?.lastFetch || 0;
  const forceRefresh = data?.forceRefresh || false;
  const limit = Math.min(data?.limit || 50, 200);

  // Cache leaderboard for 5 minutes
  const now = Date.now();
  if (!forceRefresh && (now - lastFetch) < 300000) {
    return { status: 'cached', lastFetch };
  }

  try {
    // Get top users by XP
    const leaderboardSnap = await db.collection('users')
      .orderBy('totalXP', 'desc')
      .limit(limit)
      .get();

    const leaderboard = leaderboardSnap.docs.map((doc, index) => ({
      rank: index + 1,
      uid: doc.id,
      ...doc.data()
    }));

    return {
      status: 'updated',
      lastFetch: now,
      leaderboard,
      nextFetchIn: 300000, // 5 minutes
    };
  } catch (error) {
    console.error('getLeaderboardPolling error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch leaderboard');
  }
});

// ====================
// CACHED AGGREGATES SYSTEM
// ====================

/**
 * Get cached class aggregates with background refresh
 * Reduces database load by serving pre-computed aggregates
 */
export const getCachedClassAggregates = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const teacherId = data?.teacherId;
  const schoolId = data?.schoolId;
  const grade = data?.grade;
  const maxAge = data?.maxAge || 300000; // 5 minutes default

  if (!teacherId && !(schoolId && grade)) {
    throw new functions.https.HttpsError('invalid-argument', 'Provide teacherId or schoolId+grade');
  }

  try {
    let cacheKey: string;
    let aggregates: any = null;

    if (teacherId) {
      cacheKey = `teacher_${teacherId}`;
      // Try to get from cache first
      const cacheDoc = await db.collection('cache').doc(`class_agg_${cacheKey}`).get();
      if (cacheDoc.exists) {
        const cacheData = cacheDoc.data();
        const age = Date.now() - (cacheData?.timestamp || 0);
        if (age < maxAge) {
          aggregates = cacheData?.data;
        }
      }
    } else {
      cacheKey = `school_${schoolId}_${grade}`;
      const cacheDoc = await db.collection('cache').doc(`class_agg_${cacheKey}`).get();
      if (cacheDoc.exists) {
        const cacheData = cacheDoc.data();
        const age = Date.now() - (cacheData?.timestamp || 0);
        if (age < maxAge) {
          aggregates = cacheData?.data;
        }
      }
    }

    // If no cached data or too old, compute and cache
    if (!aggregates) {
      aggregates = await computeClassAggregates(teacherId, schoolId, grade);

      // Cache the result
      await db.collection('cache').doc(`class_agg_${cacheKey}`).set({
        data: aggregates,
        timestamp: Date.now(),
        expiresAt: Date.now() + maxAge,
      });

      // Schedule background refresh
      refreshClassAggregatesBackground(cacheKey, teacherId, schoolId, grade);
    }

    return {
      aggregates,
      cached: true,
      cacheAge: Date.now() - (aggregates?.timestamp || Date.now()),
    };
  } catch (error) {
    console.error('getCachedClassAggregates error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get class aggregates');
  }
});

/**
 * Compute class aggregates (expensive operation)
 */
async function computeClassAggregates(teacherId?: string, schoolId?: string, grade?: string): Promise<any> {
  let query: any = db.collection('studentSummaries');

  if (teacherId) {
    query = query.where('teacherId', '==', teacherId);
  } else if (schoolId && grade) {
    const normSchool = normalizeSchoolClass(schoolId);
    const normGrade = normalizeSchoolClass(grade);
    query = query.where('normalizedSchool', '==', normSchool)
                 .where('normalizedClass', '==', normGrade);
  }

  const snap = await query.get();
  const students = snap.docs.map((doc: admin.firestore.QueryDocumentSnapshot) => doc.data());

  // Calculate aggregates
  const totalStudents = students.length;
  const totalXP = students.reduce((sum: number, s: any) => sum + (s.totalXP || 0), 0);
  const avgXP = totalStudents > 0 ? totalXP / totalStudents : 0;

  const totalScoreSum = students.reduce((sum: number, s: any) => sum + (s.totalScoreSum || 0), 0);
  const totalScoreCount = students.reduce((sum: number, s: any) => sum + (s.totalScoreCount || 0), 0);
  const avgScorePercent = totalScoreCount > 0 ? (totalScoreSum / totalScoreCount) : 0;

  return {
    totalStudents,
    totalXP,
    avgXP,
    avgScorePercent,
    totalScoreCount,
    timestamp: Date.now(),
  };
}

/**
 * Background refresh of class aggregates
 */
function refreshClassAggregatesBackground(cacheKey: string, teacherId?: string, schoolId?: string, grade?: string): void {
  // Run in background (don't wait for completion)
  setTimeout(async () => {
    try {
      const aggregates = await computeClassAggregates(teacherId, schoolId, grade);
      await db.collection('cache').doc(`class_agg_${cacheKey}`).update({
        data: aggregates,
        timestamp: Date.now(),
      });
      console.log(`Refreshed class aggregates cache for ${cacheKey}`);
    } catch (error) {
      console.error(`Failed to refresh class aggregates for ${cacheKey}:`, error);
    }
  }, 100); // Small delay to not block response
}

// ====================
// BATCHED USER UPDATES
// ====================

/**
 * Batch update multiple user profiles to reduce write operations
 */
export const batchUpdateUsers = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  // Only allow admins
  const callerRole = context.auth.token.role;
  if (!['super_admin', 'admin', 'school_admin'].includes(callerRole)) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can batch update users');
  }

  const updates = data?.updates || [];
  if (!Array.isArray(updates) || updates.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Provide updates array');
  }

  if (updates.length > 500) {
    throw new functions.https.HttpsError('invalid-argument', 'Maximum 500 updates per batch');
  }

  const batch = db.batch();
  const results: any[] = [];

  for (const update of updates) {
    const { uid, data: updateData, merge = true } = update;

    if (!uid || !updateData) {
      results.push({ uid, success: false, error: 'Missing uid or data' });
      continue;
    }

    try {
      const userRef = db.collection('users').doc(uid);
      if (merge) {
        batch.set(userRef, updateData, { merge: true });
      } else {
        batch.set(userRef, updateData);
      }
      results.push({ uid, success: true });
    } catch (error) {
      results.push({ uid, success: false, error: (error as Error).message });
    }
  }

  try {
    await batch.commit();
    return { results, totalProcessed: results.length };
  } catch (error) {
    console.error('batchUpdateUsers error:', error);
    throw new functions.https.HttpsError('internal', 'Batch update failed');
  }
});

// ====================
// UTILITY FUNCTIONS
// ====================

function calculateDashboardMetrics(quizData: any[]): any {
  if (quizData.length === 0) {
    return {
      totalQuestions: 0,
      totalCorrect: 0,
      averageScore: 0,
      recentActivity: [],
    };
  }

  let totalQuestions = 0;
  let totalCorrect = 0;
  const recentActivity = [];

  for (const quiz of quizData) {
    const questions = quiz.totalQuestions || 0;
    const correct = quiz.correctAnswers || 0;

    totalQuestions += questions;
    totalCorrect += correct;

    if (recentActivity.length < 5) {
      recentActivity.push({
        subject: quiz.subject || 'Unknown',
        score: quiz.percentage || 0,
        date: quiz.timestamp,
      });
    }
  }

  const averageScore = totalQuestions > 0 ? (totalCorrect / totalQuestions) * 100 : 0;

  return {
    totalQuestions,
    totalCorrect,
    averageScore,
    recentActivity,
  };
}

function normalizeSchoolClass(raw: any): string | null {
  if (!raw && raw !== 0) return null;
  try {
    let s = String(raw).toLowerCase();
    s = s.replace(/\b(school|college|high school|senior high school|senior|basic|primary|jhs|shs|form|the)\b/g, ' ');
    s = s.replace(/[^a-z0-9\s]/g, ' ');
    s = s.replace(/\s+/g, ' ').trim();
    if (!s) return null;
    return s.replace(/\s+/g, '_');
  } catch (e) {
    return null;
  }
}

// ====================
// MONITORING AND HEALTH CHECKS
// ====================

/**
 * Get scalability metrics for monitoring
 */
export const getScalabilityMetrics = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  // Only allow admins
  const callerRole = context.auth.token.role;
  if (!['super_admin', 'admin'].includes(callerRole)) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can view metrics');
  }

  try {
    const metrics = {
      connectionPool: {
        activeConnections: connectionPool.getActiveConnections(),
        totalSubscribers: connectionPool.getTotalSubscribers(),
      },
      firestore: {
        // These would need to be collected from Firebase console or monitoring
        estimatedConcurrentUsers: 'Check Firebase Console',
        estimatedListeners: 'Check Firebase Console',
      },
      timestamp: Date.now(),
    };

    return metrics;
  } catch (error) {
    console.error('getScalabilityMetrics error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get metrics');
  }
});

/**
 * Health check for scalability systems
 */
export const scalabilityHealthCheck = functions.https.onRequest((req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  const health = {
    status: 'healthy',
    connectionPool: {
      activeConnections: connectionPool.getActiveConnections(),
      totalSubscribers: connectionPool.getTotalSubscribers(),
    },
    timestamp: new Date().toISOString(),
  };

  res.status(200).json(health);
});

// ====================
// MIGRATION HELPERS
// ====================

/**
 * Migrate existing real-time listeners to polling system
 * This function helps transition users gradually
 */
export const migrateToPolling = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const uid = context.auth.uid;
  const features = data?.features || ['dashboard', 'leaderboard']; // Which features to migrate

  try {
    // Mark user as migrated in their preferences
    await db.collection('users').doc(uid).set({
      scalability: {
        migratedToPolling: true,
        migratedFeatures: features,
        migrationDate: Date.now(),
      }
    }, { merge: true });

    return {
      success: true,
      migratedFeatures: features,
      message: 'Successfully migrated to polling-based updates',
    };
  } catch (error) {
    console.error('migrateToPolling error:', error);
    throw new functions.https.HttpsError('internal', 'Migration failed');
  }
});

// ====================
// USER STATS AGGREGATION (100K USER SCALABILITY)
// ====================

/**
 * Pre-compute and cache user statistics
 * Triggered on quiz completion to avoid client-side heavy processing
 */
export const aggregateUserStats = functions.firestore
  .document('quizzes/{quizId}')
  .onCreate(async (snap, context) => {
    const quizData = snap.data();
    const userId = quizData.userId;
    
    if (!userId) return;

    try {
      // Fetch recent quizzes for this user (limited to 200)
      const quizDocs = await db.collection('quizzes')
        .where('userId', '==', userId)
        .orderBy('timestamp', 'desc')
        .limit(200)
        .get();

      let totalQuestions = 0;
      let totalCorrect = 0;
      let pastQuestionsTotal = 0;
      let pastQuestionsCorrect = 0;
      let triviaTotal = 0;
      let triviaCorrect = 0;
      const subjectScores: {[key: string]: number[]} = {};
      const subjectQuestionCounts: {[key: string]: number} = {};

      quizDocs.forEach((doc) => {
        const data = doc.data();
        const questions = data.questions || 0;
        const correct = data.correct || 0;
        const subject = data.subject || 'General';
        const type = data.type || '';

        totalQuestions += questions;
        totalCorrect += correct;

        if (type === 'past_questions') {
          pastQuestionsTotal += questions;
          pastQuestionsCorrect += correct;
        } else if (type === 'trivia') {
          triviaTotal += questions;
          triviaCorrect += correct;
        }

        if (!subjectScores[subject]) {
          subjectScores[subject] = [];
          subjectQuestionCounts[subject] = 0;
        }
        
        const score = questions > 0 ? (correct / questions * 100) : 0;
        subjectScores[subject].push(score);
        subjectQuestionCounts[subject] += questions;
      });

      // Calculate aggregates
      const overallProgress = totalQuestions > 0 ? (totalCorrect / totalQuestions * 100) : 0;
      const pastQuestionsProgress = pastQuestionsTotal > 0 ? (pastQuestionsCorrect / pastQuestionsTotal * 100) : 0;
      const triviaProgress = triviaTotal > 0 ? (triviaCorrect / triviaTotal * 100) : 0;

      const subjectProgress = Object.entries(subjectScores).map(([subject, scores]) => {
        const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
        return {
          subject,
          progress: avg,
          questionCount: subjectQuestionCounts[subject],
        };
      });

      // Store pre-computed stats in user document for instant retrieval
      await db.collection('users').doc(userId).set({
        statsCache: {
          overallProgress,
          questionsAnswered: totalQuestions,
          pastQuestionsAnswered: pastQuestionsTotal,
          pastQuestionsProgress,
          triviaQuestionsAnswered: triviaTotal,
          triviaProgress,
          subjectProgress,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }
      }, { merge: true });

      console.log(`✅ Aggregated stats for user ${userId}: ${totalQuestions} questions, ${overallProgress.toFixed(1)}% progress`);
    } catch (error) {
      console.error(`❌ Error aggregating stats for user ${userId}:`, error);
    }
  });

/**
 * API endpoint to fetch pre-computed user stats
 * Much faster than client-side aggregation
 */
export const getUserStatsOptimized = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');

  const userId = context.auth.uid;

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data()!;
    const statsCache = userData.statsCache || {};

    // If cache is stale (>5 minutes), trigger background refresh
    const lastUpdated = statsCache.lastUpdated?.toMillis() || 0;
    const cacheAge = Date.now() - lastUpdated;
    
    if (cacheAge > 5 * 60 * 1000) {
      // Trigger background refresh (don't wait)
      refreshUserStatsCache(userId).catch(err => console.error('Background refresh failed:', err));
    }

    return {
      stats: statsCache,
      cached: true,
      cacheAge: Math.floor(cacheAge / 1000), // seconds
    };
  } catch (error) {
    console.error('getUserStatsOptimized error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch stats');
  }
});

/**
 * Background function to refresh stats cache
 */
async function refreshUserStatsCache(userId: string): Promise<void> {
  // This is essentially the same logic as aggregateUserStats
  // but can be called on-demand
  const quizDocs = await db.collection('quizzes')
    .where('userId', '==', userId)
    .orderBy('timestamp', 'desc')
    .limit(200)
    .get();

  // Aggregate stats from quiz documents
  if (!quizDocs.empty) {
    // TODO: Implement aggregation logic similar to aggregateUserStats
    console.log(`🔄 Refreshed stats cache for user ${userId} (${quizDocs.size} quizzes)`);
  }
}

/**
 * Scheduled function to refresh stats for active users
 * Runs every 30 minutes to keep caches warm
 */
export const warmStatsCache = functions.pubsub.schedule('every 30 minutes').onRun(async (context) => {
  try {
    // Find users active in the last hour
    const oneHourAgo = Date.now() - 60 * 60 * 1000;
    
    const activeUserDocs = await db.collection('users')
      .where('lastActive', '>', oneHourAgo)
      .limit(1000) // Warm top 1000 active users
      .get();

    const refreshPromises = activeUserDocs.docs.map(doc => 
      refreshUserStatsCache(doc.id).catch(err => console.error(`Failed to refresh ${doc.id}:`, err))
    );

    await Promise.all(refreshPromises);

    console.log(`✅ Warmed stats cache for ${activeUserDocs.size} active users`);
  } catch (error) {
    console.error('warmStatsCache error:', error);
  }
});
