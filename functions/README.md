# Functions README

This folder contains Firebase Cloud Functions used by Uriel Academy.

## Required config

Set the OpenAI key and Tavily key (Tavily is used for web search in the `facts` endpoint):

```powershell
firebase functions:config:set openai.key="YOUR_OPENAI_KEY"
firebase functions:config:set tavily.key="YOUR_TAVILY_KEY"
```

## Build

```powershell
npm --prefix functions run build
```

## Deploy

Deploy specific functions (recommended):

```powershell
firebase deploy --only functions:aiChat,functions:facts,functions:ping --project uriel-academy-41fb0
```

Or deploy all functions:

```powershell
firebase deploy --only functions --project uriel-academy-41fb0
```

## Smoke tests

AI chat:

```powershell
Invoke-RestMethod -Method Post -Uri "https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChat" -ContentType "application/json" -Body (@{message="Say hi in 3 words"} | ConvertTo-Json)
```

Facts:

```powershell
Invoke-RestMethod -Method Post -Uri "https://us-central1-uriel-academy-41fb0.cloudfunctions.net/facts" -ContentType "application/json" -Body (@{query="When is BECE 2026 in Ghana?"} | ConvertTo-Json)
```

## Notes

- The `aiChat` endpoint uses the OpenAI key from functions config.
- The `facts` endpoint uses Tavily for web search and then asks the model to answer from the search results with citations.
- Consider upgrading `firebase-functions` dependency in `package.json` when convenient; test carefully for breaking changes.
