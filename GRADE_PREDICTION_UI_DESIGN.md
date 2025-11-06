## Grade Prediction Card - Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│  📈  BECE Grade Predictions                        🔄        │
│      AI-powered performance forecasting                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  [RME] [ICT] [Mathematics] [English] [Science] [Social...]  │
│   ▔▔▔▔  Selected subject chip in red                        │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                                                       │  │
│  │   ┌─────┐                                            │  │
│  │   │Grade│   Distinction                              │  │
│  │   │  3  │   📈 68.5%                                 │  │
│  │   └─────┘   [Medium Confidence]                      │  │
│  │    Blue                                               │  │
│  │                                                       │  │
│  │   ─────────────────────────────────────────────       │  │
│  │                                                       │  │
│  │   📅 Consistency    📊 Trend    🧠 Confidence        │  │
│  │      78%             +12%         Medium             │  │
│  │                                                       │  │
│  │   ─────────────────────────────────────────────       │  │
│  │                                                       │  │
│  │   ⚠️ Focus Areas                                      │  │
│  │   [Algebra] [Geometry] [Statistics]                  │  │
│  │                                                       │  │
│  │   ⭐ Strong Topics                                    │  │
│  │   [Numbers] [Measurement] [Graphs]                   │  │
│  │                                                       │  │
│  │   💡 Good progress. With focused effort, you can     │  │
│  │      reach distinction level. Focus on improving     │  │
│  │      "Algebra" to boost your grade. Improve by 6.5%  │  │
│  │      to reach Grade 2.                               │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  All Subjects Overview                                       │
│  ────────────────────────                                    │
│                                                              │
│  ┌─────┐  RME                                   📈           │
│  │  2  │  Higher Distinction                                │
│  └─────┘                                                     │
│   Green                                                      │
│                                                              │
│  ┌─────┐  ICT                                   📊           │
│  │  4  │  Credit                                            │
│  └─────┘                                                     │
│   Blue                                                       │
│                                                              │
│  ┌─────┐  English                               📉           │
│  │  6  │  Pass                                              │
│  └─────┘                                                     │
│  Orange                                                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Compact View

```
┌─────────────────────────────────────────────────────────────┐
│  📈  BECE Grade Predictions                        🔄        │
│      AI-powered performance forecasting                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────┐  Mathematics               📈                      │
│  │  3  │  Distinction                                       │
│  └─────┘                                                     │
│   Blue                                                       │
│                                                              │
│  ┌─────┐  RME                        📈                      │
│  │  2  │  Higher Distinction                                │
│  └─────┘                                                     │
│   Green                                                      │
│                                                              │
│  ┌─────┐  ICT                        📊                      │
│  │  4  │  Credit                                            │
│  └─────┘                                                     │
│   Blue                                                       │
│                                                              │
│         [View All Subjects →]                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Color Codes

### Grade Colors
- **Grade 1-2**: 🟢 Green (Excellence)
- **Grade 3-4**: 🔵 Blue (Good)
- **Grade 5-6**: 🟠 Orange (Average)
- **Grade 7-8**: 🟠 Deep Orange (Needs Improvement)
- **Grade 9**: 🔴 Red (Failing)

### Trend Icons
- **Improving**: 📈 Green up arrow
- **Declining**: 📉 Red down arrow
- **Stable**: 📊 Orange flat arrow

### Confidence Badges
- **High**: 🟢 Green border
- **Medium**: 🟠 Orange border
- **Low**: 🔴 Red border

## Loading State

```
┌─────────────────────────────────────────────────────────────┐
│  📈  BECE Grade Predictions                        🔄        │
│      AI-powered performance forecasting                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│                          ⚪                                  │
│                     Loading spinner                          │
│                                                              │
│              Analyzing your performance...                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Empty State (New User)

```
┌─────────────────────────────────────────────────────────────┐
│  📈  BECE Grade Predictions                        🔄        │
│      AI-powered performance forecasting                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│                          📝                                  │
│                      Quiz icon                               │
│                                                              │
│          Start practicing to see your predictions!           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Responsive Behavior

### Desktop (>768px)
- Full width card with horizontal layout
- Subject chips in single row
- Detailed stats in row layout
- Topic tags wrap gracefully

### Tablet (480-768px)
- Slightly compressed padding
- Subject chips may wrap to 2 rows
- Stats remain horizontal
- Recommendation text maintains readability

### Mobile (<480px)
- Compact view recommended
- Single column layout
- Grade badge remains prominent
- Touch-friendly chip selection
- Scrollable subject list
- Stacked stats (vertical)

## Interaction States

### Hover (Desktop)
- Subject chips: Slight scale (1.05x)
- Refresh button: Rotate icon
- Grade badge: Subtle glow effect

### Active/Selected
- Selected subject chip: Red background with white text
- Other chips: White text on transparent background

### Focus (Keyboard Navigation)
- Subject chips: Blue outline
- Refresh button: Focus ring
- Proper tab order maintained

## Accessibility Features

1. **Semantic HTML**: Proper heading hierarchy
2. **Color + Icons**: Never rely on color alone
3. **Text Contrast**: WCAG AA compliant (4.5:1 minimum)
4. **Touch Targets**: 44x44px minimum
5. **Screen Reader**: Descriptive labels on all interactive elements
6. **Keyboard Navigation**: All functions accessible via keyboard

## Animation Timing

- **Card Entry**: 300ms fade-in
- **Loading Spinner**: Continuous rotation
- **Subject Switch**: 200ms cross-fade
- **Refresh**: 400ms with stagger effect
- **Hover**: 150ms ease-in-out

## Spacing Guidelines

- **Card Padding**: 20px
- **Section Spacing**: 16-20px
- **Element Spacing**: 8-12px
- **Text Line Height**: 1.4-1.6
- **Touch Targets**: 44x44px minimum

This visual design ensures the prediction card is:
- ✅ Immediately understandable
- ✅ Visually appealing
- ✅ Mobile-responsive
- ✅ Accessible to all users
- ✅ Consistent with app design language
