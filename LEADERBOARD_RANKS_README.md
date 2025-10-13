# 🏆 Uriel Academy Leaderboard Rank System

## Overview
This system implements the complete 28-rank leaderboard progression for Uriel Academy, from **Learner** (0 XP) to **The Enlightened** (500,000+ XP).

## 📁 Files Created

### Backend/Upload Scripts
- `upload_leaderboard_ranks.js` - Uploads rank images to Firebase Storage and creates Firestore documents

### Flutter Services
- `lib/services/leaderboard_rank_service.dart` - Service for managing rank data
- `lib/widgets/rank_badge_widget.dart` - Reusable rank display widgets
- `lib/screens/all_ranks_page.dart` - Page to view all ranks

## 🚀 Setup Instructions

### Step 1: Upload Ranks to Firebase

1. Ensure your rank images are in `assets/leaderboards_rank/` with naming:
   - `rank_1.png` through `rank_28.png` (or `.jpg`)

2. Run the upload script:
```powershell
node upload_leaderboard_ranks.js
```

This will:
- Upload all rank images to Firebase Storage at `leaderboard_ranks/`
- Create Firestore documents in the `leaderboardRanks` collection
- Create metadata documents for quick reference
- Make all images publicly accessible

### Step 2: Add Dependencies to `pubspec.yaml`

Ensure these dependencies are in your `pubspec.yaml`:
```yaml
dependencies:
  cloud_firestore: ^4.0.0
  cached_network_image: ^3.3.0
  google_fonts: ^6.0.0
```

### Step 3: Import in Your App

```dart
import 'package:uriel_mainapp/services/leaderboard_rank_service.dart';
import 'package:uriel_mainapp/widgets/rank_badge_widget.dart';
import 'package:uriel_mainapp/screens/all_ranks_page.dart';
```

## 📊 Rank Tiers

| Tier | Ranks | XP Range | Theme |
|------|-------|----------|-------|
| **Beginner** | 1-5 | 0 - 19,999 | Discovery & Curiosity |
| **Achiever** | 6-10 | 20,000 - 44,999 | Consistency & Growth |
| **Advanced** | 11-15 | 45,000 - 69,999 | Mastery & Leadership |
| **Expert** | 16-21 | 70,000 - 99,999 | Dedication & Excellence |
| **Prestige** | 22-25 | 100,000 - 199,999 | Legacy & Mastery |
| **Supreme** | 26-28 | 200,000+ | Enlightenment & Legacy |

## 💻 Usage Examples

### 1. Get User's Current Rank

```dart
final rankService = LeaderboardRankService();
final userXP = 15500; // User's current XP

final currentRank = await rankService.getUserRank(userXP);
if (currentRank != null) {
  print('Current Rank: ${currentRank.name}');
  print('XP Range: ${currentRank.minXP} - ${currentRank.maxXP}');
}
```

### 2. Display Rank Badge

```dart
RankBadgeWidget(
  rank: currentRank,
  size: 64,
  showLabel: true,
  showGlow: true,
)
```

### 3. Show Rank Progress Card

```dart
RankProgressCard(
  currentRank: currentRank,
  nextRank: nextRank,
  userXP: userXP,
  onViewAllRanks: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllRanksPage(userXP: userXP),
      ),
    );
  },
)
```

### 4. Show Rank Up Notification

```dart
// After user earns XP
final oldXP = 14500;
final newXP = 15500;
final earnedXP = newXP - oldXP;

final newRank = await rankService.getUserRank(newXP);
if (newRank != null && rankService.shouldShowRankUpNotification(oldXP, newXP, newRank)) {
  RankUpDialog.show(context, newRank, earnedXP);
}
```

### 5. Navigate to All Ranks Page

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AllRanksPage(userXP: userXP),
  ),
);
```

### 6. Cache Ranks on App Start

```dart
// In your main.dart or app initialization
void initState() {
  super.initState();
  LeaderboardRankService().cacheRankRanges();
}
```

## 🎨 Customization

### Modify Rank Colors
Edit the `color` field in `upload_leaderboard_ranks.js` before uploading:
```javascript
{
  rank: 1,
  name: 'Learner',
  color: '#4CAF50', // Change this
  // ...
}
```

### Change Tier Themes
Update the `getTierColor()` method in `leaderboard_rank_service.dart`:
```dart
Color getTierColor() {
  switch (tier.toLowerCase()) {
    case 'beginner':
      return const Color(0xFF4CAF50); // Customize
    // ...
  }
}
```

## 📱 Integration with Home Page

Add rank display to your home page:

```dart
// In your home page widget
FutureBuilder<LeaderboardRank?>(
  future: LeaderboardRankService().getUserRank(userXP),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      return RankProgressCard(
        currentRank: snapshot.data!,
        nextRank: await LeaderboardRankService().getNextRank(userXP),
        userXP: userXP,
        onViewAllRanks: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AllRanksPage(userXP: userXP),
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  },
)
```

## 🔄 XP Award System

Integrate XP awards when users complete activities:

```dart
Future<void> awardXP(String userId, int xpAmount, String activity) async {
  final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
  
  // Get current XP
  final snapshot = await userDoc.get();
  final currentXP = snapshot.data()?['xp'] ?? 0;
  final newXP = currentXP + xpAmount;
  
  // Update XP
  await userDoc.update({'xp': newXP});
  
  // Check for rank up
  final rankService = LeaderboardRankService();
  final newRank = await rankService.getUserRank(newXP);
  
  if (newRank != null && 
      rankService.shouldShowRankUpNotification(currentXP, newXP, newRank)) {
    // Show rank up dialog
    RankUpDialog.show(context, newRank, xpAmount);
    
    // Log achievement
    await FirebaseFirestore.instance.collection('achievements').add({
      'userId': userId,
      'type': 'rank_up',
      'rank': newRank.rank,
      'rankName': newRank.name,
      'xp': newXP,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
```

## 🎯 XP Earning Activities

Suggested XP awards:
- **Quiz Completion**: 50-200 XP (based on performance)
- **Daily Login**: 10 XP
- **Study Streak (7 days)**: 100 XP
- **Perfect Quiz**: 250 XP
- **Reading Chapter**: 30 XP
- **Helping Others**: 50 XP
- **Trivia Win**: 75 XP

## 📊 Firestore Structure

### Collection: `leaderboardRanks`
```
leaderboardRanks/
  rank_1/
    - rank: 1
    - name: "Learner"
    - minXP: 0
    - maxXP: 999
    - tier: "Beginner"
    - description: "..."
    - imageUrl: "https://storage.googleapis.com/..."
    - color: "#4CAF50"
    ...
```

### Collection: `leaderboardMetadata`
```
leaderboardMetadata/
  ranks_info/
    - totalRanks: 28
    - minXP: 0
    - maxXP: 999999999
    - tiers: ["Beginner", "Achiever", ...]
    - lastUpdated: Timestamp
```

## 🐛 Troubleshooting

### Images Not Showing
1. Check Firebase Storage rules allow public read
2. Verify imageUrl in Firestore documents
3. Check `cached_network_image` dependency

### Rank Not Updating
1. Ensure user XP is being saved to Firestore
2. Check Firestore indexes for rank queries
3. Verify rank ranges don't have gaps

### Performance Issues
1. Call `cacheRankRanges()` on app start
2. Use cached rank lookup instead of Firestore queries
3. Implement pagination for All Ranks page if needed

## 🎉 Features

✅ 28 unique ranks with custom images
✅ Automatic rank calculation based on XP
✅ Beautiful rank badges and progress cards
✅ Rank up animations and notifications
✅ Tiered progression system
✅ All ranks viewing page
✅ Rank details modal
✅ Progress tracking within ranks
✅ Locked rank preview
✅ Tier-based color themes

## 📝 Notes

- Rank images should be optimized for web (PNG or JPG, < 100KB each)
- XP ranges are inclusive on both ends
- Rank 28 (The Enlightened) is the ultimate rank (500,000+ XP)
- Consider adding rank-specific rewards or badges
- Update Security Rules to prevent XP manipulation

## 🔐 Security Rules

Add to `firestore.rules`:
```javascript
match /leaderboardRanks/{rankId} {
  allow read: if true; // Public read
  allow write: if false; // Only via admin
}

match /leaderboardMetadata/{doc} {
  allow read: if true;
  allow write: if false;
}
```

## 🚀 Future Enhancements

- [ ] Rank-specific profile badges
- [ ] Rank achievement certificates
- [ ] Social sharing of rank ups
- [ ] Rank leaderboard (top users per rank)
- [ ] Seasonal rank variations
- [ ] Rank-specific rewards and perks
- [ ] Rank progress history/timeline

---

**Version**: 1.0  
**Last Updated**: October 2025  
**Maintained by**: Uriel Academy Team
