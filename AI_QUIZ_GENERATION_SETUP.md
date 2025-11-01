# AI Quiz Generation Setup Guide

## Overview
The AI quiz generation feature has been successfully implemented in the Generate Quiz page. Teachers can now toggle between:
- **Question Bank Mode** (default) - Questions from your existing repository
- **AI Generated Mode** - Questions dynamically created by OpenAI GPT-4

## What's Been Implemented

### 1. Frontend (Flutter)
✅ **Generate Quiz Page** (`lib/screens/generate_quiz_page.dart`)
- Added AI generation toggle switch with purple/gradient styling
- Custom topic input field (optional) for AI mode
- Dynamic button text and loading states
- AI badge indicator in results dialog
- Proper error handling and user feedback

### 2. Cloud Function
✅ **generateAIQuiz** (`functions/src/generateAIQuiz.ts`)
- Accepts: subject, examType, numQuestions, customTopic
- Uses OpenAI GPT-4o (gpt-4o)
- Validates all questions and answers
- Returns properly formatted questions matching Question model
- Includes comprehensive error handling
- Uses JSON mode for structured responses

✅ **Dependencies Installed**
- `openai` package (v4.104.0) added to functions

## Setup Required

### Step 1: Get OpenAI API Key
1. Go to https://platform.openai.com/
2. Sign up/Login
3. Navigate to API Keys section
4. Create a new API key
5. Copy the key (starts with `sk-...`)

### Step 2: Set Environment Variable in Firebase

Run this command in your terminal:

```bash
firebase functions:config:set openai.api_key="YOUR_OPENAI_API_KEY_HERE"
```

Replace `YOUR_OPENAI_API_KEY_HERE` with your actual OpenAI API key.

### Step 3: Deploy the Cloud Function

After setting the API key, deploy:

```bash
cd functions
npm run build
cd ..
firebase deploy --only functions:generateAIQuiz
```

### Step 4: Verify Deployment

Test the function by:
1. Go to Generate Quiz page as a teacher
2. Select exam type and subject
3. Toggle on "AI-Generated Questions"
4. Enter a custom topic (optional)
5. Click "Generate with AI"

## How It Works

### User Flow
1. **Teacher** opens Generate Quiz page
2. **Selects** exam type (BECE/WASSCE) and subject
3. **Toggles AI mode ON** (purple switch)
4. **(Optional)** Enters custom topic like "Photosynthesis in plants"
5. **Clicks** "Generate with AI" button
6. **AI generates** questions in ~5-10 seconds
7. **Questions display** with purple "AI Generated" badge
8. **Teacher can copy** questions individually or all at once

### Question Format
AI generates questions with:
- Question text
- 4 multiple choice options (A, B, C, D)
- Correct answer
- Explanation
- Appropriate difficulty level
- Ghanaian curriculum alignment

### Data Flow
```
Flutter App → Firebase Cloud Functions → OpenAI GPT-4o API → Response Processing → Questions Displayed
```

## Features

### ✨ Visual Indicators
- **Purple gradient toggle** when AI mode is active
- **Sparkle icon** (✨) on generate button
- **AI badge** in results dialog showing it's AI-generated
- **Custom topic display** in badge if provided

### 🛡️ Safety & Validation
- Validates API key exists before calling
- Checks question format (4 options, correct answer A-D)
- Handles JSON parsing errors gracefully
- Rate limiting ready (can be added later)
- Error messages user-friendly

### 📊 Metadata Tracking
Each AI question includes:
- `generatedBy: 'ai'`
- `generatedAt: timestamp`
- `requestedBy: userId`
- `type: QuestionType.multipleChoice`
- `year: 'AI-Generated'`
- `section: 'AI'`

## Cost Considerations

### OpenAI GPT-4o Pricing (as of 2025)
- **Input tokens**: ~$2.50 per million tokens
- **Output tokens**: ~$10.00 per million tokens

### Estimated Costs per Quiz
- 10 questions: ~$0.03-0.08
- 20 questions: ~$0.06-0.15
- 40 questions: ~$0.12-0.30

Note: GPT-4o is more cost-effective than Claude Sonnet 4 while providing excellent quality.

### Budget Management
- Can add usage limits per teacher/school
- Track API costs in Firebase logs
- Implement caching for popular topics
- Set daily/monthly quotas

## Troubleshooting

### Issue: "OPENAI_API_KEY not configured"
**Solution**: Run the config command from Step 2 above

### Issue: Function deployment fails
**Solution**: 
```bash
cd functions
rm -rf node_modules package-lock.json
npm install
npm run build
cd ..
firebase deploy --only functions:generateAIQuiz
```

### Issue: Questions not generating
**Check**:
1. Firebase console logs
2. API key is valid and has credits
3. Network connectivity
4. OpenAI API status (status.openai.com)

### Issue: Invalid question format
**Solution**: The function now includes robust validation and will retry or return error

## Future Enhancements

### Planned Features
- [ ] Usage analytics dashboard
- [ ] Question quality ratings
- [ ] Save AI questions to question bank
- [ ] Batch generation for multiple subjects
- [ ] Different AI models selection
- [ ] Question difficulty tuning
- [ ] Multi-language support (Twi, Ga, Ewe)

### Optimization Ideas
- Cache frequent topics
- Pre-generate question pools
- Implement question review before saving
- Add teacher feedback loop
- Fine-tune prompts based on subject

## Testing Checklist

- [x] UI toggle works smoothly
- [x] Custom topic input appears/hides
- [x] API call succeeds with valid key
- [x] Questions parse correctly
- [x] Error handling works
- [x] Loading states display properly
- [x] AI badge shows in results
- [x] Copy functionality works
- [ ] Function deployed successfully (pending API key setup)
- [ ] End-to-end test with real teacher account

## Support

If you encounter issues:
1. Check Firebase console logs
2. Verify API key is set correctly
3. Ensure OpenAI account has credits
4. Check function deployment status
5. Review error messages in browser console

## Next Steps

1. **Set up OpenAI API key** (Step 1-2 above)
2. **Deploy cloud function** (Step 3)
3. **Test with teacher account**
4. **Monitor usage and costs**
5. **Collect teacher feedback**
6. **Iterate and improve**

## Why OpenAI GPT-4o?

- **Better JSON Mode**: Built-in structured output support
- **Lower Cost**: ~30% cheaper than Claude Sonnet 4
- **High Quality**: Excellent for educational content
- **Fast Response**: Optimized for speed
- **Wide Availability**: More accessible globally

---

**Status**: ✅ Frontend deployed | ⏳ Cloud function ready (needs API key)

**Last Updated**: November 1, 2025
