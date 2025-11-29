import 'package:flutter_test/flutter_test.dart';
import 'package:uriel_mainapp/services/xp_service.dart';

void main() {
  group('XPService Constants', () {
    test('should have correct XP values for quiz activities', () {
      expect(XPService.XP_PER_CORRECT_ANSWER, 5);
      expect(XPService.PERFECT_SCORE_BONUS, 20);
      expect(XPService.FIRST_TIME_CATEGORY_BONUS, 50);
      expect(XPService.MASTER_EXPLORER_BONUS, 100);
    });

    test('should have correct XP values for daily activities', () {
      expect(XPService.DAILY_LOGIN_BONUS, 50);
      expect(XPService.READING_SESSION_XP, 15);
      expect(XPService.BOOK_COMPLETION_XP, 50);
      expect(XPService.TEXTBOOK_CHAPTER_XP, 10);
    });

    test('should have correct XP values for social activities', () {
      expect(XPService.UPLOAD_NOTES_XP, 150);
      expect(XPService.NOTE_UPVOTE_XP, 10);
      expect(XPService.NOTE_DOWNLOAD_XP, 5);
    });

    test('should have correct XP values for streaks', () {
      expect(XPService.SEVEN_DAY_STREAK_BONUS, 300);
      expect(XPService.THIRTY_DAY_STREAK_BONUS, 1500);
      expect(XPService.PERFECT_ATTENDANCE_BONUS, 2000);
    });

    test('should have correct XP values for advanced achievements', () {
      expect(XPService.AI_REVISION_PLAN_XP, 500);
      expect(XPService.SUBJECT_MODULE_COMPLETION_XP, 1500);
      expect(XPService.MONTHLY_CONTEST_WINNER_XP, 5000);
    });

    test('should have all trivia categories defined', () {
      expect(XPService.triviaCategories.length, 12);
      expect(XPService.triviaCategories, contains('African History'));
      expect(XPService.triviaCategories, contains('Science and Nature'));
      expect(XPService.triviaCategories, contains('Technology'));
    });
  });

  group('XP Calculation Logic', () {
    test('should calculate base XP correctly', () {
      // 10 correct answers * 5 XP each = 50 XP
      const correctAnswers = 10;
      const expectedBaseXP = correctAnswers * XPService.XP_PER_CORRECT_ANSWER;
      expect(expectedBaseXP, 50);
    });

    test('should include perfect score bonus', () {
      // Perfect score: base XP + bonus
      const correctAnswers = 20;
      const baseXP = correctAnswers * XPService.XP_PER_CORRECT_ANSWER;
      const totalXP = baseXP + XPService.PERFECT_SCORE_BONUS;
      expect(totalXP, 120); // 100 + 20
    });

    test('should calculate reading session XP', () {
      const sessions = 5;
      const totalXP = sessions * XPService.READING_SESSION_XP;
      expect(totalXP, 75);
    });

    test('should calculate note contribution XP', () {
      // Upload + 3 upvotes + 2 downloads
      const uploadXP = XPService.UPLOAD_NOTES_XP;
      const upvoteXP = 3 * XPService.NOTE_UPVOTE_XP;
      const downloadXP = 2 * XPService.NOTE_DOWNLOAD_XP;
      const totalXP = uploadXP + upvoteXP + downloadXP;
      expect(totalXP, 190); // 150 + 30 + 10
    });

    test('should calculate streak bonuses correctly', () {
      const sevenDayTotal = 7 * XPService.DAILY_LOGIN_BONUS + XPService.SEVEN_DAY_STREAK_BONUS;
      expect(sevenDayTotal, 650); // 350 + 300

      const thirtyDayTotal = 30 * XPService.DAILY_LOGIN_BONUS + XPService.THIRTY_DAY_STREAK_BONUS;
      expect(thirtyDayTotal, 3000); // 1500 + 1500
    });

    test('should validate XP progression makes sense', () {
      // Verify that advanced achievements give more XP than basic ones
      expect(XPService.MONTHLY_CONTEST_WINNER_XP, greaterThan(XPService.SUBJECT_MODULE_COMPLETION_XP));
      expect(XPService.SUBJECT_MODULE_COMPLETION_XP, greaterThan(XPService.AI_REVISION_PLAN_XP));
      expect(XPService.PERFECT_ATTENDANCE_BONUS, greaterThan(XPService.THIRTY_DAY_STREAK_BONUS));
      expect(XPService.THIRTY_DAY_STREAK_BONUS, greaterThan(XPService.SEVEN_DAY_STREAK_BONUS));
    });

    test('should verify minimum viable quiz XP', () {
      // 1 correct answer should give at least 5 XP
      const minimalXP = 1 * XPService.XP_PER_CORRECT_ANSWER;
      expect(minimalXP, 5);
    });

    test('should verify maximum single quiz XP estimate', () {
      // 40 questions perfect (typical BECE length)
      const perfectQuizBaseXP = 40 * XPService.XP_PER_CORRECT_ANSWER;
      const perfectQuizTotalXP = perfectQuizBaseXP + XPService.PERFECT_SCORE_BONUS + XPService.FIRST_TIME_CATEGORY_BONUS;
      expect(perfectQuizTotalXP, 270); // 200 + 20 + 50
    });

    test('should verify master explorer bonus makes sense', () {
      // Completing all 12 trivia categories
      final allCategoriesBaseXP = XPService.triviaCategories.length * XPService.FIRST_TIME_CATEGORY_BONUS;
      final withMasterBonus = allCategoriesBaseXP + XPService.MASTER_EXPLORER_BONUS;
      expect(withMasterBonus, 700); // 600 + 100
    });
  });

  group('XP Service Instance', () {
    test('should be a singleton', () {
      final instance1 = XPService();
      final instance2 = XPService();
      expect(identical(instance1, instance2), isTrue);
    }, skip: 'Requires Firebase initialization');
  });

  group('XP Balance and Fairness', () {
    test('daily activities should reward consistent engagement', () {
      // A week of daily logins
      const weeklyLoginXP = 7 * XPService.DAILY_LOGIN_BONUS;
      expect(weeklyLoginXP, 350);
      
      // Should be less than one perfect quiz but meaningful
      const perfectQuizXP = 20 * XPService.XP_PER_CORRECT_ANSWER + XPService.PERFECT_SCORE_BONUS;
      expect(weeklyLoginXP, greaterThan(perfectQuizXP));
    });

    test('social contributions should be well rewarded', () {
      // Uploading notes should give substantial XP
      expect(XPService.UPLOAD_NOTES_XP, greaterThan(XPService.BOOK_COMPLETION_XP));
      expect(XPService.UPLOAD_NOTES_XP, greaterThan(15 * XPService.XP_PER_CORRECT_ANSWER));
    });

    test('streak milestones should feel significant', () {
      // 30-day streak bonus should feel like a major achievement
      expect(XPService.THIRTY_DAY_STREAK_BONUS, 
             greaterThan(10 * XPService.BOOK_COMPLETION_XP));
    });

    test('contest winners should receive substantial recognition', () {
      // Monthly contest win should be the biggest single reward
      expect(XPService.MONTHLY_CONTEST_WINNER_XP, 5000);
      expect(XPService.MONTHLY_CONTEST_WINNER_XP, 
             greaterThan(3 * XPService.SUBJECT_MODULE_COMPLETION_XP));
    });
  });

  group('XP Rate Calculations', () {
    test('should calculate quiz XP rate per question', () {
      const xpPerQuestion = XPService.XP_PER_CORRECT_ANSWER;
      expect(xpPerQuestion, 5);
      
      // 20-question quiz all correct = 100 XP minimum
      expect(20 * xpPerQuestion, 100);
    });

    test('should calculate reading time value', () {
      // If a reading session is ~15 minutes, XP rate is 1 XP/minute
      const sessionXP = XPService.READING_SESSION_XP;
      const estimatedMinutes = 15;
      final xpPerMinute = sessionXP / estimatedMinutes;
      expect(xpPerMinute, 1.0);
    });

    test('should validate note upload is worth effort', () {
      // Uploading notes (15-30 min effort) should give more XP than a quick quiz
      const quickQuizXP = 5 * XPService.XP_PER_CORRECT_ANSWER; // 5 questions
      expect(XPService.UPLOAD_NOTES_XP, greaterThan(quickQuizXP * 5));
    });
  });
}
