# Design System — Family Chores App

**Version:** 1.0
**Last updated:** 2026-03-05
**Inspiration:** Apple Reminders (iOS 17+), minimal, soft, family-friendly

---

## 1. Design Principles

1. **Calm over busy** — The app should feel like a quiet helper, not another source of stress. Whitespace is generous. Elements breathe.
2. **Glanceable** — Every screen answers a question in under 2 seconds: "What do I need to do?" / "Is everything on track?"
3. **Inclusive across ages** — A 10-year-old and a 38-year-old must both feel at home. The design is playful but never childish.
4. **Invisible structure** — The system is opinionated about spacing, type, and color so that screens feel consistent without effort.
5. **Celebrate, don't punish** — Completion is rewarded visually. Overdue items are flagged gently, never with aggressive red.

---

## 2. Color Palette

All primary UI colors use a **pastel foundation** with soft saturation (HSL saturation 40-60%, lightness 75-90%). Backgrounds are warm neutrals. Accents are used sparingly to draw attention.

### 2.1 Core Palette

| Token | Hex | HSL | Usage |
|-------|-----|-----|-------|
| `pastel-blue` | `#A8D8EA` | 197, 58%, 79% | Primary actions, active states, links |
| `pastel-green` | `#B5E6C5` | 143, 45%, 80% | Success, task completed, streaks |
| `pastel-pink` | `#F2C4CE` | 345, 58%, 86% | Notifications, badges, Emma's view |
| `pastel-yellow` | `#FDE8A0` | 44, 95%, 81% | Warnings (gentle), highlights, stars |
| `pastel-lavender` | `#D5C8E6` | 268, 40%, 84% | Secondary accents, category tags |
| `pastel-peach` | `#FADCB0` | 32, 88%, 84% | Warm accents, reward elements |

### 2.2 Neutrals

| Token | Hex | Usage |
|-------|-----|-------|
| `neutral-50` | `#FAFAF8` | Page background (light mode) |
| `neutral-100` | `#F3F2EF` | Card background, surface |
| `neutral-200` | `#E5E3DE` | Dividers, subtle borders |
| `neutral-300` | `#C8C5BD` | Disabled states, placeholder text |
| `neutral-600` | `#6B6860` | Secondary text |
| `neutral-800` | `#2E2D2A` | Primary text, headings |
| `neutral-900` | `#1A1918` | High-emphasis text |

### 2.3 Semantic Colors

| Token | Value | Usage |
|-------|-------|-------|
| `color-success` | `pastel-green` | Task completed, positive feedback |
| `color-warning` | `pastel-yellow` | Due soon, gentle nudge |
| `color-overdue` | `#E8A0A0` (soft rose) | Overdue — not red, still calm |
| `color-info` | `pastel-blue` | Informational, default accent |
| `color-reward` | `pastel-peach` | Points, streaks, celebrations |

### 2.4 Dark Mode

In dark mode, pastel colors shift to **muted tones** (reduce lightness to 35-45%, keep saturation at 30-40%) over a dark warm background (`#1C1B19`). Cards use `#2A2926`. Text becomes `#E8E6E1` for body and `#FAFAF8` for headings.

### 2.5 Per-Family-Member Accent

Each family member gets a personal accent color used in avatars, progress rings, and contribution charts:

| Member | Accent | Token |
|--------|--------|-------|
| Dad (Marcus) | `pastel-blue` | `member-dad` |
| Mom (Sofia) | `pastel-lavender` | `member-mom` |
| Alex (10) | `pastel-green` | `member-alex` |
| Emma (3) | `pastel-pink` | `member-emma` |

---

## 3. Typography

### 3.1 Font Family

| Context | Font | Fallback | Reason |
|---------|------|----------|--------|
| **Primary** | **Nunito** | `system-ui, sans-serif` | Rounded terminals feel friendly and welcoming. Highly legible at small sizes. Free on Google Fonts. |
| **Numeric / data** | **Nunito** (tabular figures) | `system-ui` | Keep consistency; use `font-variant-numeric: tabular-nums` for aligned numbers. |
| **Emma's view** | **Nunito Bold** at larger sizes | — | Same font, bigger and bolder for pre-reader accessibility. |

> **Why Nunito?** It mirrors the rounded, approachable warmth of SF Rounded (used in iOS Reminders) while being open-source and cross-platform. Its range of weights (200-900) gives full flexibility.

### 3.2 Type Scale

Based on a **1.250 (Major Third)** scale with a 16px base. All sizes use `rem` for accessibility.

| Token | Size (rem) | Size (px) | Weight | Line Height | Usage |
|-------|-----------|-----------|--------|-------------|-------|
| `text-xs` | 0.75 | 12 | 400 | 1.5 | Captions, timestamps, metadata |
| `text-sm` | 0.875 | 14 | 400 | 1.5 | Secondary labels, helper text |
| `text-base` | 1.0 | 16 | 400 | 1.5 | Body text, task descriptions |
| `text-md` | 1.125 | 18 | 600 | 1.4 | Task titles in lists |
| `text-lg` | 1.25 | 20 | 600 | 1.4 | Card headings, section titles |
| `text-xl` | 1.5 | 24 | 700 | 1.3 | Page titles |
| `text-2xl` | 2.0 | 32 | 700 | 1.2 | Hero numbers (points, streaks) |
| `text-3xl` | 2.5 | 40 | 800 | 1.1 | Emma's view — task labels |

### 3.3 Type Styles

| Style Name | Token | Weight | Letter Spacing | Transform |
|------------|-------|--------|----------------|-----------|
| **Heading** | `text-xl` / `text-lg` | 700 / 600 | -0.01em | None |
| **Body** | `text-base` | 400 | 0 | None |
| **Label** | `text-sm` | 600 | 0.02em | None |
| **Caption** | `text-xs` | 400 | 0.02em | None |
| **Overline** | `text-xs` | 700 | 0.08em | Uppercase |
| **Button** | `text-sm` | 700 | 0.03em | None |

---

## 4. Spacing System

An **8px base grid** with a 4px half-step for fine adjustments. All spacing uses multiples of 4.

| Token | Value | Usage |
|-------|-------|-------|
| `space-0` | 0px | — |
| `space-1` | 4px | Inline icon-to-text gap, tight padding |
| `space-2` | 8px | Default gap between related elements |
| `space-3` | 12px | Inner card padding (compact), list item padding |
| `space-4` | 16px | Standard card padding, form field spacing |
| `space-5` | 20px | Section gap within a card |
| `space-6` | 24px | Gap between cards, between sections |
| `space-8` | 32px | Page margin (mobile), major section separation |
| `space-10` | 40px | Page top padding, hero area spacing |
| `space-12` | 48px | Large screen page margins |
| `space-16` | 64px | Maximum section separation |

### 4.1 Layout Rules

- **Page padding:** `space-4` (16px) on mobile, `space-8` (32px) on tablet+
- **Card internal padding:** `space-4` (16px) all sides
- **Gap between cards in a list:** `space-3` (12px)
- **Gap between sections on a page:** `space-8` (32px)
- **Icon-to-label gap:** `space-2` (8px)
- **Minimum touch target:** 44x44px (iOS HIG)
- **Emma's view touch target:** 56x56px minimum

---

## 5. Border Radius & Elevation

### 5.1 Border Radius

Following the iOS Reminders aesthetic: generous, rounded, smooth.

| Token | Value | Usage |
|-------|-------|-------|
| `radius-sm` | 8px | Chips, small badges, input fields |
| `radius-md` | 12px | Buttons, tags, small cards |
| `radius-lg` | 16px | Standard cards, modal sheets |
| `radius-xl` | 20px | Large cards, bottom sheets |
| `radius-full` | 9999px | Avatars, circular buttons, progress rings |

### 5.2 Elevation (Shadows)

Minimal shadows. Depth is communicated through **subtle background differences** more than box-shadow, like iOS Reminders.

| Token | Value | Usage |
|-------|-------|-------|
| `elevation-0` | none | Flat surfaces, inline elements |
| `elevation-1` | `0 1px 3px rgba(0,0,0,0.06)` | Cards resting on background |
| `elevation-2` | `0 4px 12px rgba(0,0,0,0.08)` | Floating cards, dropdown menus |
| `elevation-3` | `0 8px 24px rgba(0,0,0,0.12)` | Modals, bottom sheets |

---

## 6. Iconography

| Property | Value |
|----------|-------|
| **Style** | Outlined, rounded corners (Material Symbols Rounded) |
| **Weight** | 300 (light) for default, 500 for active/filled |
| **Sizes** | 20px (inline), 24px (standard), 32px (toolbar), 48px (Emma's view) |
| **Color** | Inherits text color or uses semantic color |

Use **Material Symbols Rounded** (variable font). The rounded style matches Nunito's soft terminals and the overall friendly aesthetic.

### 6.1 Key Icons

| Action | Icon name | Notes |
|--------|-----------|-------|
| Add task | `add_circle` | Filled pastel-blue |
| Complete | `check_circle` | Animated fill on tap |
| Overdue | `schedule` | Soft rose color |
| Reward / star | `star` | pastel-yellow, with micro-animation |
| Family member | `face` | Or custom avatar |
| Settings | `tune` | Not `settings` — feels friendlier |

---

## 7. Component Library

Built on **Material Design 3 (M3)** components, customized with the pastel palette and Nunito typography. M3 is recommended because:

- It provides accessible, well-tested components out of the box
- Its "Material You" theming system maps directly to our token structure
- It supports dynamic color, which aligns with per-member accents
- Flutter (M3 native) or React (MUI v6 with M3 theme) can implement it

### 7.1 Task Card

The primary UI element. Inspired by iOS Reminders list rows but with richer content.

```
+-------------------------------------------------------+
|  [ ] pastel-blue circle     Task Title        12:00 PM |
|       (checkbox)            Helper text / due    (tag) |
|                             [  Alex  ]                 |
+-------------------------------------------------------+
```

| Property | Value |
|----------|-------|
| Background | `neutral-100` (light), `#2A2926` (dark) |
| Border radius | `radius-lg` (16px) |
| Padding | `space-4` (16px) |
| Elevation | `elevation-1` |
| Checkbox | 24px circle, 2px border in member accent color. Filled with `pastel-green` + checkmark on complete. |
| Title | `text-md` (18px, semibold) |
| Subtitle | `text-sm` (14px, regular, `neutral-600`) |
| Member chip | Pill shape, member accent background at 20% opacity, `text-xs` bold |
| Swipe right | Complete (green) |
| Swipe left | Reschedule (blue) |
| Completed state | Title gets ~~strikethrough~~ + opacity 50%, checkbox fills green with animated check |

### 7.2 Category Card (Dashboard)

Grouped task summary, similar to iOS Reminders list groups.

```
+-----------------------------------------------+
|   icon       Category Name                     |
|   (pastel)   3 tasks · 1 overdue               |
|                                                 |
|   ████████████░░░░░  75% complete              |
+-----------------------------------------------+
```

| Property | Value |
|----------|-------|
| Background | Tinted with category pastel at 10% opacity |
| Border radius | `radius-xl` (20px) |
| Padding | `space-5` (20px) |
| Icon | 32px, category pastel color |
| Title | `text-lg` (20px, semibold) |
| Subtitle | `text-sm`, `neutral-600` |
| Progress bar | 4px height, `radius-full`, fill color = category pastel |

### 7.3 Family Member Avatar

| Property | Value |
|----------|-------|
| Shape | Circle (`radius-full`) |
| Sizes | 32px (inline), 40px (list), 56px (profile) |
| Border | 2px solid, member accent color |
| Fallback | First initial on member accent background at 30% opacity |
| Active indicator | 3px accent-colored ring with 2px gap |

### 7.4 Buttons

Following M3 button hierarchy:

| Type | Usage | Style |
|------|-------|-------|
| **Filled** | Primary CTA ("Add Chore", "Done") | `pastel-blue` background, `neutral-900` text, `radius-md` |
| **Tonal** | Secondary actions ("Edit", "Assign") | `pastel-blue` at 15% opacity background, `pastel-blue` darkened text |
| **Outlined** | Tertiary actions ("Cancel", "Skip") | 1px `neutral-200` border, `neutral-800` text |
| **Text** | Inline actions ("View all", "Details") | No background, `pastel-blue` text |
| **FAB** | Main add action | 56px circle, `pastel-blue`, `elevation-2`, `add` icon |

All buttons: minimum height 44px, `text-sm` bold, `radius-md` (12px), horizontal padding `space-4`.

### 7.5 Bottom Sheet

Used for task creation, task detail, and quick actions.

| Property | Value |
|----------|-------|
| Background | `neutral-50` (light) |
| Border radius | `radius-xl` top-left and top-right |
| Handle | 32px wide, 4px height, `neutral-300`, centered, `space-2` from top |
| Elevation | `elevation-3` |
| Padding | `space-4` sides, `space-6` bottom (safe area) |

### 7.6 Chips / Tags

Used for member assignment, categories, and due dates.

| Property | Value |
|----------|-------|
| Height | 28px |
| Padding | `space-1` vertical, `space-3` horizontal |
| Border radius | `radius-sm` (8px) |
| Font | `text-xs`, weight 600 |
| Variants | **Filled** (pastel bg, dark text), **Outlined** (1px border, no fill) |

### 7.7 Progress Ring

Used for daily/weekly progress per family member.

| Property | Value |
|----------|-------|
| Sizes | 40px (compact), 64px (standard), 96px (hero) |
| Stroke width | 4px (compact), 6px (standard/hero) |
| Track color | `neutral-200` |
| Fill color | Member accent color |
| Center content | Percentage (`text-sm` bold) or member avatar |
| Animation | Smooth stroke-dashoffset transition, 600ms ease-out |

### 7.8 Celebration Overlay (Emma & Rewards)

Triggered on task completion. Scales up for Emma's view.

| Property | Value |
|----------|-------|
| Type | Full-screen lottie/rive animation overlay |
| Duration | 1.5s (standard), 2.5s (Emma's view) |
| Elements | Confetti, stars, or stickers in pastel palette |
| Sound | Optional soft chime (respects device silent mode) |
| Dismiss | Auto-dismiss after duration or tap anywhere |

### 7.9 Empty State

| Property | Value |
|----------|-------|
| Illustration | Simple line art in `neutral-300` with one pastel accent |
| Headline | `text-lg`, `neutral-800` |
| Body | `text-base`, `neutral-600`, max 240px width, centered |
| CTA | Filled button below body, `space-6` gap |

### 7.10 Navigation

| Component | Style |
|-----------|-------|
| **Bottom navigation** (mobile) | M3 Navigation Bar, 4 destinations max, pastel-blue active indicator, Nunito labels |
| **Navigation rail** (tablet) | M3 Navigation Rail, left-aligned, same tokens |
| **Top app bar** | M3 Small Top App Bar, `neutral-50` background, no elevation, `text-xl` title |

---

## 8. Motion & Animation

Following M3 motion guidelines with a **gentle, family-friendly** feel.

| Action | Duration | Easing | Notes |
|--------|----------|--------|-------|
| Page transition | 300ms | ease-in-out | Shared element transitions where possible |
| Card appear | 200ms | ease-out | Fade + slight upward translate (8px) |
| Checkbox complete | 400ms | spring (damping 0.6) | Circle fills, checkmark draws in |
| Bottom sheet open | 350ms | ease-out | Slide up from bottom |
| Celebration | 1500ms | — | Lottie/Rive, auto-dismiss |
| Progress ring fill | 600ms | ease-out | Smooth stroke animation |
| List reorder | 200ms | ease-in-out | Smooth position swap |

---

## 9. Responsive Breakpoints

| Breakpoint | Width | Layout |
|------------|-------|--------|
| **Mobile** | < 600px | Single column, bottom nav, full-bleed cards |
| **Tablet** | 600–1024px | Two-column where useful, nav rail, card grid |
| **Desktop** | > 1024px | Three-column dashboard, sidebar nav, generous margins |

---

## 10. Accessibility

| Requirement | Implementation |
|-------------|----------------|
| **Color contrast** | All text meets WCAG 2.1 AA (4.5:1 for body, 3:1 for large text). Pastel backgrounds are paired with `neutral-800` or `neutral-900` text. |
| **Touch targets** | Minimum 44x44px (48x48px on Android M3 default) |
| **Font scaling** | All sizes in `rem`. Layout does not break up to 200% zoom. |
| **Screen reader** | All interactive elements have accessible labels. Task state (complete, overdue) announced. |
| **Reduced motion** | Respect `prefers-reduced-motion`. Replace animations with instant state changes. |
| **Color independence** | Status is never communicated by color alone — always paired with icon or text label. |

---

## 11. Emma's Simplified View

A dedicated mode for the 3-year-old persona. Activates when Emma's profile is selected.

| Property | Value |
|----------|-------|
| Background | `pastel-pink` at 10% opacity on `neutral-50` |
| Task cards | Full-width, 96px height minimum, large illustration/icon (48px), `text-3xl` label |
| Touch targets | 56px minimum, generous spacing (`space-6` between items) |
| Navigation | None — single scrollable list, parent controls via back gesture |
| Completion | Big animated celebration (confetti + sound), 2.5 seconds |
| Typography | `Nunito Bold`, minimum 24px for any visible text |
| Colors | Limited to `pastel-pink`, `pastel-peach`, `pastel-yellow` — warm and inviting |

---

## 12. Implementation Notes

### Recommended Tech Stack Alignment

| Layer | Recommendation |
|-------|----------------|
| **Component library** | Material Design 3 (M3) via MUI v6 (React) or Material 3 (Flutter) |
| **Theming** | M3 custom theme using tokens from this document. Map `pastel-blue` to M3 `primary`, `pastel-green` to `tertiary`, etc. |
| **Icons** | Material Symbols Rounded (variable font, weight 300/500) |
| **Font loading** | Google Fonts: `Nunito:wght@400;600;700;800` |
| **Animations** | Lottie (web/Flutter) or Rive for celebrations; CSS transitions for micro-interactions |
| **Dark mode** | Use M3 dynamic color with muted pastel tones as seed colors |

### M3 Theme Mapping

```
M3 Token              -> App Token
primary               -> pastel-blue (#A8D8EA)
onPrimary             -> neutral-900 (#1A1918)
primaryContainer      -> pastel-blue at 20% opacity
secondary             -> pastel-lavender (#D5C8E6)
tertiary              -> pastel-green (#B5E6C5)
error                 -> color-overdue (#E8A0A0)
surface               -> neutral-50 (#FAFAF8)
surfaceVariant        -> neutral-100 (#F3F2EF)
outline               -> neutral-200 (#E5E3DE)
outlineVariant        -> neutral-300 (#C8C5BD)
```

---

## 13. Design Tokens Summary (CSS Custom Properties)

```css
:root {
  /* Colors — Pastel */
  --color-pastel-blue: #A8D8EA;
  --color-pastel-green: #B5E6C5;
  --color-pastel-pink: #F2C4CE;
  --color-pastel-yellow: #FDE8A0;
  --color-pastel-lavender: #D5C8E6;
  --color-pastel-peach: #FADCB0;

  /* Colors — Neutrals */
  --color-neutral-50: #FAFAF8;
  --color-neutral-100: #F3F2EF;
  --color-neutral-200: #E5E3DE;
  --color-neutral-300: #C8C5BD;
  --color-neutral-600: #6B6860;
  --color-neutral-800: #2E2D2A;
  --color-neutral-900: #1A1918;

  /* Colors — Semantic */
  --color-success: var(--color-pastel-green);
  --color-warning: var(--color-pastel-yellow);
  --color-overdue: #E8A0A0;
  --color-info: var(--color-pastel-blue);
  --color-reward: var(--color-pastel-peach);

  /* Typography */
  --font-family: 'Nunito', system-ui, sans-serif;
  --text-xs: 0.75rem;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-md: 1.125rem;
  --text-lg: 1.25rem;
  --text-xl: 1.5rem;
  --text-2xl: 2rem;
  --text-3xl: 2.5rem;

  /* Spacing */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;

  /* Border Radius */
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 16px;
  --radius-xl: 20px;
  --radius-full: 9999px;

  /* Elevation */
  --elevation-0: none;
  --elevation-1: 0 1px 3px rgba(0, 0, 0, 0.06);
  --elevation-2: 0 4px 12px rgba(0, 0, 0, 0.08);
  --elevation-3: 0 8px 24px rgba(0, 0, 0, 0.12);
}
```

---

*This design system is a living document. Update it as the product evolves and new patterns emerge.*
