# BECE English Questions - Import Guide

## ✅ Current Status

**Imported:** 30 English questions from 2022  
**Live on:** https://uriel-academy-41fb0.web.app  
**⚠️ Note:** All answers are currently set to 'A' as placeholders - MUST BE UPDATED!

## 📁 Available Resources

### Question Files (DOCX)
- `assets/bece English/bece english 1990-2025 questions.docx` (35 files)

### Answer Keys (PDF)
- `assets/bece English/ENGLISH ANSWERS 1990 - 2018.pdf` ✅
- `assets/bece English/2019 BECE ENGLISH LANGUAGE 1 SOLUTION.pdf` ✅
- `assets/bece English/2021 BECE ENGLISH LANGUAGE 1 SOLUTION.pdf` ✅
- **Missing:** 2020, 2022, 2023, 2024, 2025 (need to find or extract)

## 🚀 Quick Start - Import More Years

### Step 1: Parse Questions from DOCX
```powershell
# Parse a single year
node parse_english_to_json.js 2023

# Parse multiple years
node parse_english_to_json.js 2020 2021 2022

# Parse all years (1990-2025)
node parse_english_to_json.js all
```

**Output:** `english_YEAR_questions.json` files

### Step 2: Add Correct Answers

#### Method A: Batch Entry (Fastest)
```powershell
node add_answers_to_json.js english_2022_questions.json
```

Then enter answers in format: `1D 2A 3B 4C 5A 6B 7C 8D...`

Example for 2022 (if you have the answer key):
```
1D 2D 3A 4D 5D 6A 7C 8B 9A 10C 11D 12B 13C 14A 15D 16B 17A 18C 19D 20A
```

#### Method B: Direct JSON Edit
Open `english_2022_questions.json` and update:
```json
{
  "id": "english_2022_q1",
  "correctAnswer": "D",  // Change from "A" to correct answer
  ...
}
```

#### Method C: Import with Placeholders, Update Later
Import with 'A' placeholders, then update via:
- Admin panel (Question Management)
- Direct Firestore edits
- Re-import corrected JSON

### Step 3: Import to Firestore
```powershell
node import_bece_english.js --file=./english_2022_questions.json
```

### Step 4: Deploy & Test
```powershell
flutter build web --release
firebase deploy --only hosting
```

## 📊 Extraction Status

| Year | Questions Extracted | Answers Available | Status |
|------|-------------------|-------------------|--------|
| 1990-2018 | ✅ Ready | ✅ PDF Available | 📝 Add answers & import |
| 2019 | ✅ Ready | ✅ PDF Available | 📝 Add answers & import |
| 2020 | ✅ Ready | ❌ Missing | ⚠️ Need answer key |
| 2021 | ✅ Ready | ✅ PDF Available | 📝 Add answers & import |
| 2022 | ✅ **IMPORTED** | ⚠️ Placeholders (A) | 🔧 Update answers |
| 2023 | ⚠️ Parse issues | ❌ Missing | 🔧 Fix parsing |
| 2024 | ⚠️ Parse issues | ❌ Missing | 🔧 Fix parsing |
| 2025 | ⚠️ Parse issues | ❌ Missing | 🔧 Fix parsing |

## 🔧 Scripts Reference

### Extraction
- `extract_english_questions.js` - Initial DOCX → text extraction
- `parse_english_to_json.js` - Parse text → structured JSON

### Answer Management  
- `add_answers_to_json.js` - Interactive answer entry
- `add_placeholder_answers.js` - Add 'A' placeholders for testing

### Import
- `import_bece_english.js` - Import questions + passages to Firestore

## 📝 Answer Key Format

The PDF answer keys typically show answers as:
```
1. D    11. B    21. C
2. A    12. C    22. D
3. B    13. A    23. A
...
```

Extract these and enter them in the batch format: `1D 2A 3B...`

## 💡 Tips & Best Practices

### 1. **Start with Years that Have Answer Keys**
Process 1990-2019, 2021 first (answer keys available)

### 2. **Verify Before Mass Import**
- Test with one year (2022 ✅ already done)
- Check questions display correctly on site
- Verify answer validation works

### 3. **Handle Missing Answers**
For years without answer keys:
- Import with placeholders
- Mark as "Draft" or "Under Review"
- Gradually add correct answers as they're verified

### 4. **Quality Check**
After importing:
- Take a quiz on the site
- Verify questions readable
- Check answer validation
- Test on mobile

### 5. **Passages & Instructions**
Most BECE English questions are standalone grammar/vocabulary.
Comprehension passages are rare but check for:
- Section A: May have reading passages
- Section B: Grammar with instructions
- Section C: Essay/writing (may not need to import)

## 🎯 Priority Import Order

1. **2022** ✅ Done (update answers from PDF when available)
2. **2019, 2021** - Have solution PDFs
3. **2010-2018** - Have answer key PDF  
4. **1990-2009** - Have answer key PDF
5. **2020, 2023-2025** - Find answer keys or mark as draft

## 📂 File Structure

```
uriel_mainapp/
├── assets/bece English/          # Source DOCX & PDF files
├── extracted_english/             # Raw text & templates
├── english_YEAR_questions.json    # Formatted JSON (ready to import)
├── extract_english_questions.js   # Step 1: DOCX → text
├── parse_english_to_json.js       # Step 2: Text → JSON
├── add_answers_to_json.js         # Step 3: Add answers
├── import_bece_english.js         # Step 4: JSON → Firestore
└── ENGLISH_IMPORT_GUIDE.md        # This file
```

## ⚠️ Important Notes

1. **Placeholder Answers:** 2022 questions currently have all answers as 'A'
   - Students will get incorrect feedback
   - Update ASAP from answer key

2. **Section Structure:** BECE English typically has:
   - Section A: Lexis & Structure (Q1-15)
   - Section B: Comprehension/Grammar (Q16-25)
   - Section C: Essay Writing (Q26-30)

3. **Question Types:**
   - Most are multiple choice
   - Essay questions should be marked differently or excluded

4. **Batch Processing:**
   - Process years with answer keys first
   - Can import ~30 years × 30 questions = 900 questions quickly

## 🚀 Quick Batch Import (Example)

To import multiple years at once:

```powershell
# Parse all years 2010-2019 (have answers)
for ($year=2010; $year -le 2019; $year++) {
  node parse_english_to_json.js $year
}

# Add answers for each (requires manual entry or batch script)
# ...

# Import all
for ($year=2010; $year -le 2019; $year++) {
  node import_bece_english.js --file="./english_${year}_questions.json"
}

# Deploy
flutter build web --release
firebase deploy --only hosting
```

## ✅ Verification Checklist

After importing:
- [ ] Questions visible in admin panel
- [ ] Students can take English quiz
- [ ] Questions display correctly
- [ ] Options show properly (A, B, C, D)
- [ ] Answer validation works
- [ ] Mobile display works
- [ ] Year filter works
- [ ] Section filter works

## 📞 Support

If you encounter issues:
1. Check script output for errors
2. Verify JSON structure matches `bece_english_sample.json`
3. Test import with small dataset first
4. Check Firestore console for imported questions
5. Review browser console for frontend errors

---

**Next Steps:**
1. Find/extract answer keys for 2020, 2022-2025
2. Update 2022 answers from 'A' placeholders to correct answers
3. Parse and import years 1990-2021 (have answer keys)
4. Test thoroughly on live site
5. Add passages for comprehension questions if needed
