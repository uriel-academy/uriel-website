/**
 * Scoring utility for exam attempts
 * Handles server-side scoring logic with detailed feedback
 */

export interface Answer {
  qId: string;
  answer: string | null;
}

export interface Question {
  id: string;
  question: string;
  options: string[];
  correctAnswer: string;
  explanation?: string;
  difficulty?: 'easy' | 'medium' | 'hard';
  topic?: string;
  points?: number;
}

export interface ScoringResult {
  score: number; // Percentage score
  correct: number;
  total: number;
  items: ScoredItem[];
}

export interface ScoredItem {
  questionId: string;
  userAnswer: string | null;
  correctAnswer: string;
  isCorrect: boolean;
  explanation?: string;
  points: number;
  difficulty?: string;
  topic?: string;
}

/**
 * Score an exam attempt with detailed feedback
 * @param questions Array of question objects
 * @param answers Array of user answers
 * @returns Detailed scoring result
 */
export function scoreExam(questions: (Question | null)[], answers: Answer[]): ScoringResult {
  const items: ScoredItem[] = [];
  let correctCount = 0;
  let totalPoints = 0;
  let maxPoints = 0;

  // Create answer lookup map
  const answerMap = new Map<string, string | null>();
  answers.forEach(answer => {
    answerMap.set(answer.qId, answer.answer);
  });

  // Score each question
  questions.forEach((question, index) => {
    if (!question) return;

    const userAnswer = answerMap.get(question.id) || null;
    const correctAnswer = question.correctAnswer;
    const isCorrect = userAnswer === correctAnswer;
    const points = question.points || 1;

    if (isCorrect) {
      correctCount++;
      totalPoints += points;
    }
    maxPoints += points;

    items.push({
      questionId: question.id,
      userAnswer,
      correctAnswer,
      isCorrect,
      explanation: question.explanation,
      points: isCorrect ? points : 0,
      difficulty: question.difficulty,
      topic: question.topic
    });
  });

  // Calculate percentage score
  const score = maxPoints > 0 ? Math.round((totalPoints / maxPoints) * 100) : 0;

  return {
    score,
    correct: correctCount,
    total: questions.filter(q => q !== null).length,
    items
  };
}

/**
 * Calculate mastery level based on performance across multiple attempts
 * @param attempts Array of attempt scores for a specific topic/subject
 * @returns Mastery level (0-100)
 */
export function calculateMastery(attempts: { score: number; date: Date }[]): number {
  if (attempts.length === 0) return 0;

  // Sort by date, most recent first
  const sortedAttempts = attempts.sort((a, b) => b.date.getTime() - a.date.getTime());
  
  // Weight recent attempts more heavily
  let weightedScore = 0;
  let totalWeight = 0;
  
  sortedAttempts.forEach((attempt, index) => {
    const weight = Math.pow(0.8, index); // Exponential decay
    weightedScore += attempt.score * weight;
    totalWeight += weight;
  });

  return Math.round(totalWeight > 0 ? weightedScore / totalWeight : 0);
}

/**
 * Determine performance level based on score
 * @param score Percentage score
 * @returns Performance level string
 */
export function getPerformanceLevel(score: number): string {
  if (score >= 90) return 'excellent';
  if (score >= 80) return 'very_good';
  if (score >= 70) return 'good';
  if (score >= 60) return 'fair';
  if (score >= 50) return 'weak';
  return 'very_weak';
}

/**
 * Calculate streak information
 * @param recentAttempts Array of recent attempts (chronological order)
 * @param passingScore Minimum score to continue streak
 * @returns Current streak count
 */
export function calculateStreak(recentAttempts: { score: number }[], passingScore: number = 70): number {
  if (recentAttempts.length === 0) return 0;

  let streak = 0;
  // Count from most recent backwards
  for (let i = recentAttempts.length - 1; i >= 0; i--) {
    if (recentAttempts[i].score >= passingScore) {
      streak++;
    } else {
      break;
    }
  }

  return streak;
}