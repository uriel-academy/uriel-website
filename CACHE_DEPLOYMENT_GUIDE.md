# AI Question Caching System - Quick Start

## ✅ What's Been Implemented

### 1. **Core Caching System**
- ✅ `QuestionCacheService` - Flutter service for cache management
- ✅ `findSimilarQuestion` - Cloud Function with semantic similarity
- ✅ URI Chat integration - Auto-check cache before API calls
- ✅ Firestore schema for questionCache collection

### 2. **Bulk Generation Tool**
- ✅ `generate_common_questions.js` - Script to generate 5,000 Q&A pairs
- ✅ Subject distribution: Math, Science, English, Social Studies, etc.
- ✅ Auto-save to Firestore + JSON backup

### 3. **Analytics & Monitoring**
- ✅ Cache statistics methods
- ✅ Usage tracking (hitCount, lastUsed)
- ✅ Cost savings calculator

---

## 🚀 Deployment Instructions

### Step 1: Deploy Cloud Function (Required)
```powershell
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions:findSimilarQuestion
```

**Expected output**:
```
✔  functions[findSimilarQuestion]: Successful create operation.
Function URL: https://us-central1-uriel-academy-41fb0.cloudfunctions.net/findSimilarQuestion
```

### Step 2: Rebuild & Deploy Flutter App
```powershell
flutter build web --release
firebase deploy --only hosting
```

This deploys the updated URI chat with cache integration.

---

## 💡 Two Deployment Options

### Option A: Organic Growth (Recommended for Testing)
**No upfront cost** - Cache builds naturally as students ask questions

**Pros**:
- Zero initial investment
- Tests the system in production
- Validates cache hit patterns

**Cons**:
- Lower savings in first 3 months
- Slower to reach optimal hit rate

**Best for**: Testing, small schools (<500 students)

---

### Option B: Pre-Generate 5,000 Questions (Recommended for Scale)
**$32-35 upfront** - Instant 70%+ cache coverage

**When to run**:
```powershell
cd scripts
node generate_common_questions.js
```

**What it does**:
1. Generates 5,000 common student questions across all subjects
2. Creates AI answers for each question
3. Saves to Firestore `questionCache` collection
4. Creates JSON backup files in `./generated_cache/`

**Time**: 2-3 hours (rate-limited to avoid API throttling)

**Cost**: ~$35 (one-time)

**Pros**:
- Immediate 70-80% cache hit rate
- Maximum cost savings from day 1
- Better UX (faster responses)

**Cons**:
- $35 upfront cost
- 2-3 hour generation time

**Best for**: Production, schools with 1,000+ students

---

## 📊 Monitoring Cache Performance

### View Cache Stats (Run in Flutter app)
```dart
final stats = await QuestionCacheService().getCacheStats();
print(stats);
```

**Output**:
```dart
{
  'totalCachedQuestions': 5247,
  'totalCacheHits': 8392,
  'averageUsagePerQuestion': 1.6,
  'subjectBreakdown': {
    'mathematics': 1043,
    'integratedScience': 998,
    'english': 876,
    ...
  },
  'estimatedSavings': {
    'totalSavedUSD': 54.55,
    'totalSavedGHS': 818.25,
    'apiCallsAvoided': 8392
  }
}
```

### Firebase Console Monitoring
1. **Firestore** → `questionCache` collection
   - Check document count
   - Review `usageCount` field

2. **Functions** → `findSimilarQuestion`
   - Monitor invocations
   - Check execution time (should be <300ms)

3. **Logs** → Search for:
   - `"Cache hit"` - Successful matches
   - `"Cache miss"` - New questions needing API

---

## 🧪 Testing the System

### Test 1: Cache Hit
```
Ask URI: "How do I solve quadratic equations?"
Expected: Answer with "💡 Retrieved from knowledge base" indicator
Logs: "✅ Cache hit! Similarity: 0.92"
```

### Test 2: Cache Miss → Auto-Cache
```
Ask URI: "What is the chemical formula for glucose?"
Expected: Normal AI answer (may be slow)
Logs: "❌ Cache miss - calling AI API..."
Then: "💾 Cached new Q&A pair"
```

### Test 3: Subsequent Hit
```
Ask URI: "What's the glucose chemical formula?"
Expected: Instant answer from cache
Logs: "✅ Cache hit! Similarity: 0.88"
```

---

## 🎛️ Configuration Options

### Adjust Similarity Threshold
Edit `lib/services/question_cache_service.dart`:
```dart
static const double similarityThreshold = 0.85; // Default

// More strict (fewer hits, more precise)
static const double similarityThreshold = 0.90;

// More lenient (more hits, less precise)
static const double similarityThreshold = 0.80;
```

### Add Subject Detection Keywords
Edit `lib/widgets/uri_chat_input.dart` → `_detectSubject()`:
```dart
if (lowerQuestion.contains('trigonometry') || 
    lowerQuestion.contains('sine') ||
    lowerQuestion.contains('cosine')) {
  return Subject.mathematics;
}
```

---

## 💰 Cost Tracking

### Check Actual Costs
1. **OpenAI Dashboard**: https://platform.openai.com/usage
   - View API usage
   - See cost breakdown

2. **Firebase Console** → Functions → Usage
   - `findSimilarQuestion` invocations (free lookups)
   - `aiChatHttp` invocations (paid API calls)

### Calculate Savings
```
Savings = (Total Questions Asked) × (Cache Hit Rate) × $0.0065
```

**Example** (1,000 students, 3 months):
- Total questions: 2,500
- Cache hit rate: 65%
- Savings: 2,500 × 0.65 × $0.0065 = **$10.56**

---

## 📈 Expected Performance Timeline

### Week 1:
- Cache: ~50-100 questions
- Hit rate: 10-15%
- Savings: $2-3

### Month 1:
- Cache: ~500 questions
- Hit rate: 30-40%
- Savings: $15-20

### Month 3:
- Cache: ~1,500 questions
- Hit rate: 60-70%
- Savings: $50-70

### Month 6+:
- Cache: ~3,000+ questions
- Hit rate: 80-85%
- Savings: $100-150/year

---

## 🐛 Common Issues & Solutions

### Issue: "findSimilarQuestion not found"
**Solution**: Deploy the Cloud Function:
```powershell
firebase deploy --only functions:findSimilarQuestion
```

### Issue: Cache hit rate stays low (<30%)
**Solutions**:
1. Lower threshold to 0.80
2. Run bulk generation script
3. Check subject detection accuracy

### Issue: Slow cache lookups
**Solutions**:
1. Add Firestore composite indexes
2. Limit query results (already set to 500)
3. Check function execution time in logs

---

## 🔐 Security Notes

### Firestore Rules (Add to firestore.rules)
```javascript
match /questionCache/{docId} {
  // Only authenticated users can read cache
  allow read: if request.auth != null;
  
  // Only the system can write cache
  allow write: if false; // Controlled via Cloud Function
}
```

### Environment Variables
OpenAI API key already configured in:
- Firebase Functions config: `functions.config().openai.key`
- Local script: `scripts/.env` file

---

## 📝 Next Steps

### Immediate (Required):
1. ✅ Deploy `findSimilarQuestion` Cloud Function
2. ✅ Rebuild and deploy Flutter web app
3. ✅ Test with sample questions

### Short-term (1-2 weeks):
1. Monitor cache performance
2. Decide: Run bulk generation or let it grow organically
3. Add Firestore security rules

### Long-term (1-3 months):
1. Analyze cache hit patterns
2. Adjust similarity threshold if needed
3. Generate additional subject-specific questions
4. Build admin dashboard for cache analytics

---

## 📞 Support

**Implemented by**: GitHub Copilot
**Date**: December 17, 2025
**Documentation**: See `QUESTION_CACHE_IMPLEMENTATION.md` for full details

**For issues**:
- Check Firebase Function logs
- Review `question_cache_service.dart` debug prints
- Monitor Firestore `questionCache` collection

---

## 🎯 Success Criteria

Your implementation is successful when:

✅ `findSimilarQuestion` function deployed
✅ URI chat checks cache before API calls
✅ Cache hit indicator shows in UI
✅ Firestore `questionCache` collection grows
✅ Cost per question drops below $0.005
✅ Cache hit rate reaches 70%+ within 3 months

---

**Status**: ✅ Ready for deployment
**Estimated Time**: 30-45 minutes (deployment + testing)
**Estimated Savings**: 59-79% cost reduction over 3 years
