import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Calculate cosine similarity between two text strings using TF-IDF
 * This is a lightweight semantic similarity approach
 */
function calculateSimilarity(text1: string, text2: string): number {
  const words1 = tokenize(text1);
  const words2 = tokenize(text2);
  
  // Quick exact match check (case-insensitive)
  if (text1.toLowerCase().trim() === text2.toLowerCase().trim()) {
    return 1.0;
  }
  
  // Build vocabulary
  const vocab = new Set([...words1, ...words2]);
  
  // Create frequency vectors
  const vec1 = Array.from(vocab).map(word => words1.filter(w => w === word).length);
  const vec2 = Array.from(vocab).map(word => words2.filter(w => w === word).length);
  
  // Calculate cosine similarity
  const dotProduct = vec1.reduce((sum, val, i) => sum + val * vec2[i], 0);
  const mag1 = Math.sqrt(vec1.reduce((sum, val) => sum + val * val, 0));
  const mag2 = Math.sqrt(vec2.reduce((sum, val) => sum + val * val, 0));
  
  if (mag1 === 0 || mag2 === 0) return 0;
  
  return dotProduct / (mag1 * mag2);
}

/**
 * Tokenize text into words, removing stop words and normalizing
 */
function tokenize(text: string): string[] {
  const stopWords = new Set([
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'should',
    'could', 'can', 'may', 'might', 'must', 'shall', 'i', 'you', 'he', 'she',
    'it', 'we', 'they', 'what', 'which', 'who', 'when', 'where', 'why', 'how',
    'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'about', 'as'
  ]);
  
  return text
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ') // Remove punctuation
    .split(/\s+/)
    .filter(word => word.length > 2 && !stopWords.has(word));
}

/**
 * Calculate Levenshtein distance for fuzzy string matching
 */
function levenshteinDistance(str1: string, str2: string): number {
  const len1 = str1.length;
  const len2 = str2.length;
  const matrix: number[][] = [];

  for (let i = 0; i <= len1; i++) {
    matrix[i] = [i];
  }

  for (let j = 0; j <= len2; j++) {
    matrix[0][j] = j;
  }

  for (let i = 1; i <= len1; i++) {
    for (let j = 1; j <= len2; j++) {
      if (str1[i - 1] === str2[j - 1]) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1, // substitution
          matrix[i][j - 1] + 1,     // insertion
          matrix[i - 1][j] + 1      // deletion
        );
      }
    }
  }

  return matrix[len1][len2];
}

/**
 * Combined similarity score using multiple algorithms
 */
function calculateCombinedSimilarity(question1: string, question2: string): number {
  // Cosine similarity (semantic)
  const cosineSim = calculateSimilarity(question1, question2);
  
  // Normalized Levenshtein (character-level)
  const maxLen = Math.max(question1.length, question2.length);
  const levDist = levenshteinDistance(
    question1.toLowerCase().trim(),
    question2.toLowerCase().trim()
  );
  const levSim = maxLen > 0 ? 1 - (levDist / maxLen) : 0;
  
  // Weighted combination (70% semantic, 30% character-level)
  return (cosineSim * 0.7) + (levSim * 0.3);
}

export const findSimilarQuestion = functions.https.onCall(async (data, context) => {
  try {
    const { question, subject, threshold = 0.85 } = data;

    if (!question || typeof question !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Question must be a non-empty string'
      );
    }

    console.log(`🔍 Searching for similar questions to: "${question.substring(0, 100)}..."`);
    console.log(`Subject filter: ${subject || 'all'}, Threshold: ${threshold}`);

    // Query cache collection
    let query = db.collection('questionCache').orderBy('createdAt', 'desc').limit(500);
    
    if (subject) {
      query = query.where('subject', '==', subject);
    }

    const snapshot = await query.get();
    
    if (snapshot.empty) {
      console.log('❌ No cached questions found');
      return { found: false };
    }

    console.log(`📊 Comparing against ${snapshot.docs.length} cached questions`);

    // Find most similar question
    let bestMatch: any = null;
    let bestSimilarity = 0;

    for (const doc of snapshot.docs) {
      const cachedQuestion = doc.data().question;
      const similarity = calculateCombinedSimilarity(question, cachedQuestion);
      
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = {
          questionId: doc.id,
          question: cachedQuestion,
          answer: doc.data().answer,
          subject: doc.data().subject,
          usageCount: doc.data().usageCount || 0,
        };
      }
    }

    if (bestMatch && bestSimilarity >= threshold) {
      console.log(`✅ Match found! Similarity: ${bestSimilarity.toFixed(3)}`);
      console.log(`Cached question: "${bestMatch.question.substring(0, 100)}..."`);
      
      return {
        found: true,
        ...bestMatch,
        similarity: bestSimilarity,
      };
    }

    console.log(`❌ No match above threshold. Best similarity: ${bestSimilarity.toFixed(3)}`);
    return { 
      found: false,
      bestSimilarity,
    };

  } catch (error: any) {
    console.error('Error finding similar question:', error);
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'Failed to search cache'
    );
  }
});
