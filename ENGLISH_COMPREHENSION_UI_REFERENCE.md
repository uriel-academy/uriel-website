# English Comprehension UI Reference

## Visual Layout Examples

### 1. Question with Passage (Questions 1-5)

```
┌─────────────────────────────────────────────────────────────┐
│ 📖 The Farmer's Son                                    ▼    │  ← Collapsible header
├─────────────────────────────────────────────────────────────┤
│ Once upon a time, there lived a hardworking farmer in      │
│ a small village. He had three sons who were very lazy.     │
│ The farmer was worried about his sons' future. One day,    │
│ he called them and told them that he had hidden a          │
│ treasure in his field. After the farmer's death, the       │
│ sons started digging the field day and night in search     │
│ of the treasure. They dug the entire field but found no    │
│ treasure. However, because the field was well plowed,      │
│ they decided to sow seeds. That year, they had a great     │
│ harvest. The sons finally understood what their father     │
│ meant by 'treasure.' The treasure was the result of        │
│ hard work.                                                  │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│  Question 1 of 20                              [Uriel Blue] │
│                                                             │
│  From the passage, what was the farmer worried about?      │
│                                                             │
│  ○  A. His health                                          │
│  ○  B. His sons' laziness                                  │
│  ○  C. His crops                                           │
│  ○  D. His neighbors                                       │
│                                                             │
│                                          [Next] →          │
└─────────────────────────────────────────────────────────────┘
```

### 2. Question with Section Instructions (Questions 30-35)

```
┌─────────────────────────────────────────────────────────────┐
│ ⓘ From questions 30 to 35, choose the word closest in     │  ← Yellow instruction box
│   meaning to the underlined word.                          │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│  Question 30 of 50                             [Uriel Blue] │
│                                                             │
│  Choose the word that is closest in meaning to 'critical'  │
│  as used in the passage.                                   │
│                                                             │
│  ○  A. Unimportant                                         │
│  ○  B. Essential                                           │
│  ○  C. Negative                                            │
│  ○  D. Optional                                            │
│                                                             │
│                                          [Next] →          │
└─────────────────────────────────────────────────────────────┘
```

### 3. Regular Question (No Passage/Instructions)

```
┌─────────────────────────────────────────────────────────────┐
│  Question 40 of 50                             [Uriel Blue] │
│                                                             │
│  The teacher asked the students to _____ their homework    │
│  on time.                                                  │
│                                                             │
│  ○  A. submit                                              │
│  ○  B. submits                                             │
│  ○  C. submitted                                           │
│  ○  D. submitting                                          │
│                                                             │
│                                          [Next] →          │
└─────────────────────────────────────────────────────────────┘
```

### 4. Collapsed Passage View

```
┌─────────────────────────────────────────────────────────────┐
│ 📖 The Farmer's Son                                    ▶    │  ← Collapsed (click to expand)
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│  Question 2 of 20                              [Uriel Blue] │
│                                                             │
│  What did the sons find when they dug the field?           │
│  ...                                                       │
└─────────────────────────────────────────────────────────────┘
```

## Color Scheme

| Element | Background | Text | Border |
|---------|-----------|------|--------|
| **Passage Card** | #F5F5F5 (Light gray) | #2C2C2C (Dark gray) | None |
| **Passage Header** | #1A1E3F (5% opacity) | #1A1E3F (Uriel blue) | None |
| **Instruction Box** | #FFF9E6 (Soft yellow) | #78350F (Brown) | #FFD700 (Gold, 30%) |
| **Question Card** | #1A1E3F (Uriel blue) | #FFFFFF (White) | None |
| **Option (unselected)** | #FFFFFF (White, 90%) | #1A1E3F (Uriel blue) | #FFFFFF (30%) |
| **Option (selected)** | #D62828 (Uriel red) | #FFFFFF (White) | #D62828 |

## Typography

| Element | Font | Size (Desktop) | Size (Mobile) | Weight |
|---------|------|---------------|---------------|--------|
| **Passage Title** | Playfair Display | 18px | 16px | 700 (Bold) |
| **Passage Content** | Montserrat | 16px | 14px | 400 (Regular) |
| **Instructions** | Montserrat | 15px | 13px | 600 (Semi-bold) |
| **Question Text** | Playfair Display | 20px | 18px | 600 (Semi-bold) |
| **Options** | Montserrat | 16px | 14px | 500 (Medium) |

## Responsive Behavior

### Desktop (> 768px)
- Passage card: Full width with generous padding (24px)
- Question card: Full width with 24px padding
- Instructions: 16px padding
- Font sizes: Larger for readability

### Mobile (≤ 768px)
- Passage card: Full width with 16px padding
- Question card: Full width with 20px padding
- Instructions: 12px padding
- Font sizes: Slightly smaller for screen space
- Touch-friendly tap targets (48px minimum)

## User Interactions

### Passage Expand/Collapse
1. **Tap header** → Passage toggles between expanded/collapsed
2. **Expanded:** Full passage visible, icon shows ▼
3. **Collapsed:** Only title visible, icon shows ▶
4. **State persists:** Stays expanded/collapsed as user navigates questions

### Question Navigation
1. **Select answer** → Option highlights in Uriel red
2. **Tap Next** → Moves to next question
3. **Same passage:** Passage remains visible (if expanded)
4. **Different passage:** New passage loads seamlessly
5. **Same instructions:** Instructions remain visible

## Loading States

### Passage Loading
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    ⏳ Loading passage...                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Cached Passage (Instant)
- No loading indicator
- Passage appears immediately
- Smooth user experience

## Accessibility

- ✅ High contrast text (WCAG AA compliant)
- ✅ Touch targets ≥ 48px on mobile
- ✅ Clear visual hierarchy
- ✅ Readable fonts (Montserrat, Playfair Display)
- ✅ Collapsible passage for screen space management
- ✅ Icons with semantic meaning (📖 book, ⓘ info)

## Animation

- **Passage expand/collapse:** Smooth height transition (300ms)
- **Question transition:** Fade and slide (500ms)
- **Option selection:** Instant highlight
- **Loading:** Circular progress indicator (Uriel blue)

## Special Cases

### Multiple Questions, Same Passage
- Passage displays for Q1
- Passage stays visible for Q2, Q3, Q4, Q5
- User can collapse if desired
- Saves vertical space on mobile

### Section Instructions
- Displayed once for question range (e.g., Q30-35)
- Remains visible as user navigates Q30 → Q31 → Q32, etc.
- Clear visual separation from question

### Mixed Question Types
Quiz with all three types flows naturally:
1. Q1-5: Passage-based (same passage)
2. Q6-29: Regular questions
3. Q30-35: Section instructions (no passage)
4. Q36-50: Regular questions

Each type displays appropriately without UI jarring.

## Mobile Optimization

### Portrait Mode
- Single column layout
- Passage above question
- Full-width cards
- Collapsible passage saves vertical space

### Landscape Mode  
- Same layout (single column)
- Smaller padding
- Optimized font sizes
- Scrollable content

## Performance

### Metrics
- **Passage load:** <500ms (first time)
- **Cached passage:** <10ms (instant)
- **Question transition:** 500ms animation
- **Smooth scrolling:** 60 FPS

### Optimization
- Passage caching reduces Firestore reads
- Lazy loading: Passages loaded on-demand
- No re-fetching of already-cached passages
- Efficient state management

---

This UI reference shows exactly how the comprehension system looks and behaves in the Uriel Academy app!
