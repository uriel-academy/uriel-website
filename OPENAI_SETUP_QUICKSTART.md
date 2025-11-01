# Quick Setup: OpenAI API Key

## ⚡ Fast Setup (3 Steps)

### 1. Get OpenAI API Key
Visit: https://platform.openai.com/api-keys
- Login/Sign up
- Click "Create new secret key"
- Copy the key (starts with `sk-...`)

### 2. Configure Firebase
```bash
firebase functions:config:set openai.api_key="YOUR_KEY_HERE"
```

### 3. Deploy
```bash
firebase deploy --only functions:generateAIQuiz
```

## ✅ What Changed

**Before**: Anthropic Claude Sonnet 4
- Cost: $3-15 per million tokens
- Required: ANTHROPIC_API_KEY

**After**: OpenAI GPT-4o  
- Cost: $2.50-10 per million tokens (30% cheaper!)
- Required: OPENAI_API_KEY
- Better JSON mode support
- Faster responses

## 🧪 Test It

1. Go to Generate Quiz page
2. Toggle "AI-Generated Questions" ON
3. Select subject and exam type
4. (Optional) Enter custom topic
5. Click "Generate with AI"

## 📊 Expected Costs

| Questions | Cost Range |
|-----------|------------|
| 10 Qs     | $0.03-0.08 |
| 20 Qs     | $0.06-0.15 |
| 40 Qs     | $0.12-0.30 |

## 🔧 Current Status

- ✅ Code migrated to OpenAI
- ✅ Anthropic SDK removed
- ✅ Documentation updated
- ✅ Changes committed (7a299fd)
- ⏳ Waiting for API key setup
- ⏳ Function deployment pending

## 🆘 Troubleshooting

**Function won't deploy?**
- Make sure you ran the config command
- Check your OpenAI account has credits
- Verify key starts with `sk-`

**Questions not generating?**
- Check Firebase console logs
- Verify API key is active
- Check OpenAI usage limits

See **AI_QUIZ_GENERATION_SETUP.md** for full documentation.
