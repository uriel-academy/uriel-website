import 'dart:math';

class MotivationalService {
  static final MotivationalService _instance = MotivationalService._internal();
  factory MotivationalService() => _instance;
  MotivationalService._internal();

  final Random _random = Random();

  /// Get motivational message based on rank
  String getRankBasedMessage(int rank, int totalXP) {
    if (rank == 1) {
      return '👑 You\'re #1! The champion of Uriel Academy!';
    } else if (rank <= 3) {
      return '🏆 Top 3! You\'re among the elite!';
    } else if (rank <= 10) {
      return '⭐ Top 10! You\'re doing amazing!';
    } else if (rank <= 25) {
      return '🌟 Top 25! Keep pushing forward!';
    } else if (rank <= 50) {
      return '🔥 Top 50! You\'re on fire!';
    } else if (rank <= 100) {
      return '💪 Top 100! You\'re making great progress!';
    } else {
      return '🚀 Keep climbing! Every point counts!';
    }
  }

  /// Get message based on how close to next milestone
  String getMilestoneMessage(int rank, int xpToNextTier) {
    if (rank <= 10) {
      if (rank == 10) {
        return '⚠️ Hold your Top 10 spot! Someone\'s coming for you!';
      }
      final spotsToTop = rank - 1;
      return '⚡ Only $spotsToTop ${spotsToTop == 1 ? 'spot' : 'spots'} to climb higher!';
    } else if (rank <= 15) {
      final spotsToTop10 = rank - 10;
      return '🎯 You\'re $spotsToTop10 ${spotsToTop10 == 1 ? 'spot' : 'spots'} away from Top 10!';
    } else if (xpToNextTier > 0 && xpToNextTier <= 100) {
      return '🔥 Only $xpToNextTier XP until next tier!';
    } else {
      return '💎 Keep earning XP to unlock the next tier!';
    }
  }

  /// Get performance-based encouragement
  String getPerformanceMessage(double accuracy, int questionsAnswered) {
    if (accuracy >= 95 && questionsAnswered >= 50) {
      return '🎯 Exceptional accuracy! You\'re a true master!';
    } else if (accuracy >= 90) {
      return '⭐ Outstanding performance! Keep it up!';
    } else if (accuracy >= 80) {
      return '💪 Great job! You\'re doing excellent!';
    } else if (accuracy >= 70) {
      return '👍 Good work! Room for improvement!';
    } else {
      return '📚 Keep practicing! Every quiz makes you better!';
    }
  }

  /// Get streak message
  String getStreakMessage(int streakDays) {
    if (streakDays >= 30) {
      return '🔥 Incredible $streakDays-day streak! You\'re unstoppable!';
    } else if (streakDays >= 14) {
      return '⚡ $streakDays days strong! You\'re building a great habit!';
    } else if (streakDays >= 7) {
      return '🌟 Week streak! Keep the momentum going!';
    } else if (streakDays >= 3) {
      return '🎯 $streakDays days in a row! You\'re on a roll!';
    } else if (streakDays > 0) {
      return '💪 Start of a great streak! Keep going!';
    } else {
      return '🚀 Start your streak today! Study consistently to build momentum!';
    }
  }

  /// Get challenge message for friends
  String getChallengeMessage(String friendName, int yourXP, int friendXP) {
    final difference = yourXP - friendXP;
    
    if (difference > 100) {
      return '👑 You\'re ahead of $friendName by $difference XP!';
    } else if (difference > 0) {
      return '⚡ You\'re slightly ahead of $friendName. Stay sharp!';
    } else if (difference > -100) {
      final gap = difference.abs();
      return '🎯 $friendName is ahead by $gap XP. Time to catch up!';
    } else {
      final gap = difference.abs();
      return '🔥 $friendName is leading by $gap XP. Can you close the gap?';
    }
  }

  /// Get comeback message for returning users
  String getComebackMessage(int daysSinceActivity, int totalXP) {
    if (daysSinceActivity >= 30) {
      return '🎉 Welcome back! You\'ve been missed! Your $totalXP XP is waiting for you!';
    } else if (daysSinceActivity >= 14) {
      return '👋 It\'s been a while! Ready to jump back in and climb the leaderboard?';
    } else if (daysSinceActivity >= 7) {
      return '💪 Welcome back! Time to reclaim your position!';
    } else if (daysSinceActivity >= 3) {
      return '🚀 Good to see you again! Let\'s get back on track!';
    } else {
      return '✨ Welcome back! Your learning journey continues!';
    }
  }

  /// Get XP progress message
  String getXPProgressMessage(int xpEarned, int totalXP, int xpToNextTier) {
    if (xpToNextTier == 0) {
      return '👑 You\'ve reached the maximum tier! You\'re a legend!';
    } else if (xpToNextTier <= 50) {
      return '🔥 So close! Just $xpToNextTier XP to next tier!';
    } else {
      final percentage = ((totalXP / (totalXP + xpToNextTier)) * 100).toInt();
      return '📈 You\'re $percentage% of the way to the next tier!';
    }
  }

  /// Get random motivational quote
  String getRandomQuote() {
    final quotes = [
      '📚 "Education is the most powerful weapon." - Nelson Mandela',
      '🌟 "Learning never exhausts the mind." - Leonardo da Vinci',
      '💪 "The expert in anything was once a beginner." - Helen Hayes',
      '🎯 "Success is the sum of small efforts repeated day in and day out."',
      '⚡ "The only way to do great work is to love what you do."',
      '🚀 "Believe you can and you\'re halfway there."',
      '🔥 "The future belongs to those who believe in the beauty of their dreams."',
      '✨ "Education is not preparation for life; education is life itself."',
      '👑 "The beautiful thing about learning is nobody can take it away from you."',
      '💎 "An investment in knowledge pays the best interest."',
    ];
    
    return quotes[_random.nextInt(quotes.length)];
  }

  /// Get loss aversion message (to prevent dropping)
  String getLossAversionMessage(int rank) {
    if (rank <= 10) {
      return '⚠️ Don\'t lose your Top 10 spot! Keep studying to maintain your position!';
    } else if (rank <= 25) {
      return '🔔 Others are catching up! Complete a quiz today to stay ahead!';
    } else if (rank <= 50) {
      return '👀 Your rank is at risk! Study now to protect your position!';
    } else {
      return '💪 Don\'t let others pass you! Take a quiz and climb higher!';
    }
  }

  /// Get social proof message
  String getSocialProofMessage(int activeUsers, int totalQuizzes) {
    final messages = [
      '🌍 Join ${activeUsers.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} students competing today!',
      '🎯 $totalQuizzes quizzes completed by Ghanaian students this week!',
      '⚡ You\'re among the top learners in Ghana!',
      '🔥 Students across Ghana are leveling up. Join them!',
      '🌟 Be part of Ghana\'s learning revolution!',
    ];
    
    return messages[_random.nextInt(messages.length)];
  }

  /// Get competition framing message
  String getCompetitionMessage(int rank, String? schoolName) {
    if (schoolName != null && rank <= 50) {
      return '🏫 Representing $schoolName in the Top ${rank <= 10 ? '10' : rank <= 25 ? '25' : '50'}!';
    } else if (schoolName != null) {
      return '🏫 Climb the ranks and make $schoolName proud!';
    } else {
      return '🎯 Compete with students across Ghana!';
    }
  }

  /// Get achievement hunt message
  String getAchievementHuntMessage(int earnedCount, int totalCount) {
    final remaining = totalCount - earnedCount;
    
    if (remaining == 0) {
      return '🏆 Achievement Master! You\'ve unlocked them all!';
    } else if (remaining <= 3) {
      return '🎯 Only $remaining ${remaining == 1 ? 'achievement' : 'achievements'} left to unlock!';
    } else {
      return '⭐ $remaining achievements waiting to be unlocked!';
    }
  }

  /// Get time-based message
  String getTimeBasedMessage() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 12) {
      return '🌅 Good morning! Start your day with a quiz!';
    } else if (hour >= 12 && hour < 17) {
      return '☀️ Good afternoon! Time for a quick study session!';
    } else if (hour >= 17 && hour < 21) {
      return '🌆 Good evening! Perfect time to review and practice!';
    } else {
      return '🌙 Studying late? You\'re dedicated! Don\'t forget to rest.';
    }
  }

  /// Get category-specific message
  String getCategoryMessage(String category, int completed, int total) {
    if (completed == total) {
      return '✅ You\'ve mastered $category! Amazing work!';
    } else {
      final remaining = total - completed;
      return '📚 $remaining more $category ${remaining == 1 ? 'quiz' : 'quizzes'} to master this category!';
    }
  }

  /// Get comparative message (vs average)
  String getComparativeMessage(int yourXP, int averageXP) {
    if (yourXP > averageXP * 2) {
      return '🌟 You\'re performing at 2x the average! Exceptional!';
    } else if (yourXP > averageXP * 1.5) {
      return '⭐ You\'re 50% above average! Outstanding!';
    } else if (yourXP > averageXP) {
      return '👍 You\'re above average! Keep climbing!';
    } else {
      final gap = averageXP - yourXP;
      return '📈 $gap XP to reach average. You can do it!';
    }
  }
}
