# DOCX Importer (BECE)

This small tool converts `.docx` question files into JSON and can optionally import them into Firestore.

Prerequisites
- Node.js (16+ recommended)
- A Firebase service account JSON (if you plan to import to Firestore)

Install

PowerShell (run from repo root):

```powershell
cd scripts\docx_import
npm install
```

Convert (dry-run)

```powershell
node import_word_questions.js --folder "..\..\assets\bece french" --out ../output
```

Convert and import to Firestore

```powershell
node import_word_questions.js --folder "..\..\assets\bece french" --out ../output --import --serviceAccountPath "..\..\uriel-academy-...json"
```

Notes
- The parser uses heuristics; review the generated JSON in `scripts/docx_import/output` before importing.
- For `bece french` the script will try to detect a passage (text before question 1) and attach it to subsequent questions.
- Filenames in `assets` are inconsistent; the script attempts to handle common `questions`/`answers` naming patterns.
