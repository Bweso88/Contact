---
name: Harvest Field
colors:
  surface: '#f9f9ff'
  surface-dim: '#cfdaf2'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f3ff'
  surface-container: '#e7eeff'
  surface-container-high: '#dee8ff'
  surface-container-highest: '#d8e3fb'
  on-surface: '#111c2d'
  on-surface-variant: '#56423d'
  inverse-surface: '#263143'
  inverse-on-surface: '#ecf1ff'
  outline: '#89726b'
  outline-variant: '#dcc1b9'
  surface-tint: '#9d4225'
  primary: '#9a4023'
  on-primary: '#ffffff'
  primary-container: '#ba5838'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb59e'
  secondary: '#376756'
  on-secondary: '#ffffff'
  secondary-container: '#baeed8'
  on-secondary-container: '#3e6d5c'
  tertiary: '#8b4c00'
  on-tertiary: '#ffffff'
  tertiary-container: '#af6102'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbd0'
  primary-fixed-dim: '#ffb59e'
  on-primary-fixed: '#3a0b00'
  on-primary-fixed-variant: '#7e2c10'
  secondary-fixed: '#baeed8'
  secondary-fixed-dim: '#9fd1bc'
  on-secondary-fixed: '#002117'
  on-secondary-fixed-variant: '#1e4f3f'
  tertiary-fixed: '#ffdcc2'
  tertiary-fixed-dim: '#ffb77a'
  on-tertiary-fixed: '#2e1500'
  on-tertiary-fixed-variant: '#6d3a00'
  background: '#f9f9ff'
  on-background: '#111c2d'
  surface-variant: '#d8e3fb'
typography:
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system serves frontline evangelists, pastoral teams, and community outreach volunteers operating dynamically in the field—frequently outdoors, under direct sun, and using one hand while walking or conversing. The atmosphere is warm, mission-driven, dignified, and grounding, avoiding clinical CRM detachment in favor of relational warmth and pastoral care.

The visual approach marries modern functional minimalism with tactile warmth:
- **Atmosphere**: Grounded, organic, and steadfast. Warm cream substrates replace cold digital starkness, evoking natural parchment and open community settings.
- **Physical Usability**: Tailored strictly for variable outdoor light. Text contrast reaches high legibility ratings against both paper-cream and white card tiers. 
- **Emotional Cadence**: Purposeful and uplifting. Interactive cues reinforce intentional discipleship and care without feeling gamified or corporate.

## Colors

The palette is rooted in earth and harvest tones, balanced specifically for outdoor display environments where sunlight washes out lower-contrast designs.

- **Primary (`#C25E3E` - Terracotta)**: The primary action driver. Used for core missionary actions, follow-up commits, active floating action buttons, and critical spiritual milestones.
- **Secondary (`#4A7A68` - Sage)**: Grounding pastoral tone. Used for relational updates, prayer request tracking, confirmed contact touchpoints, and growth indicators.
- **Tertiary (`#D9822B` - Amber)**: Used for warmth, prompt alerts, scheduled visit reminders, and secondary tags.
- **Neutral Charcoal (`#1E293B`)**: Ultra-high-contrast text and structural icons. Avoid pure black to maintain an organic, warm tone while retaining maximum legibility under bright glare.
- **Canvas & Containers**:
  - Global Canvas: `#FAF8F5` (Warm Cream).
  - Surface Tier 1 (Cards, Floating Bars): `#FFFFFF` (Pure White) with warm outline boundaries.
  - Surface Tier 2 (Nested sections, inactive chips): `#F3EFEA` (Pressed Sand).
  - Border/Divider Tone: `#E8E2D9` (Warm Linen).

## Typography

Typography prioritizes rapid glanceability and scan speed during live conversation.

- **Headlines & Person Names (`Plus Jakarta Sans`)**: Delivers friendly, open letterforms with sturdy stroke geometry. It keeps personal names and key metrics distinct and welcoming.
- **Body & Functional Labels (`Inter`)**: Chosen for its high x-height, robust hinting, and zero ambiguity among tabular numbers, dates, and microcopy outdoors.
- **Scale Rules**:
  - Contact names in card headers use `title-lg` (`18px/600`) to guarantee instant recognition.
  - Prayer requests and interaction notes default to `body-md` (`14px/20px`) with relaxed line spacing to prevent visual crowding when notes are brief or conversational.
  - Tracking numbers and quick badges use uppercase tracking (`+0.04em`) on `label-sm` to maintain optical crispness against soft background pills.

## Layout & Spacing

Field interactions demand large ergonomic touch surfaces and clear separation to prevent accidental taps while moving.

- **Layout Model**: Single-column vertical stream optimized for mobile widths (360px to 428px viewport baseline). On tablet/desktop administrative views, content centers within a 640px focused feed or expands to a split view (contact list left, narrative profile right).
- **One-Handed Zone Ergonomics**:
  - Primary interaction zones (quick calls, log notes, journey stage selectors) sit primarily in the lower 60% of the screen.
  - Critical actions are pinned in an elevated bottom action bar resting above the native home indicator.
- **Touch Target Rules**:
  - All interactive elements adhere to a strict minimum bounding box of 48×48px, even when visually rendered as compact 32px icons or pills.
  - Vertical stacking between distinct contact entries requires a minimum gap of `space-md` (1rem) to prevent errant clicks.

## Elevation & Depth

To preserve outdoor visibility where subtle dark drop-shadows turn into muddy smudges under glare, depth is achieved through layered tonal contrast combined with light, warm-tinted ambient containment.

- **Surface Tiers**:
  - **Level 0 (Canvas)**: Background `#FAF8F5` provides a restful, non-blinding backplane.
  - **Level 1 (Cards & Lists)**: `#FFFFFF` card surfaces framed with a 1px solid border of `#E8E2D9`. This creates hard visual boundaries even under direct sunlight.
  - **Level 2 (Modals & Bottom Drawers)**: `#FFFFFF` elevated with an ambient shadow: `0px 8px 24px -4px rgba(30, 41, 59, 0.08)`.
  - **Level 3 (Floating Action & Outreach Launchers)**: `#C25E3E` surface cast with a directional primary glow: `0px 6px 16px 0px rgba(194, 94, 62, 0.28)`.
- **Ghost Borders**: Rather than relying purely on elevation shadows, cards and floating controls use a crisp `1px` inner or outer border in `#E8E2D9` to ensure separation when the display auto-adjusts brightness.

## Shapes

The shape system employs consistent `0.5rem` (8px) corners for standard controls and `1rem` (16px) for cards, establishing a friendly, approachable aesthetic that stays structured and organized.

- **Base Components (Inputs, Buttons, Lists)**: `rounded` (8px). Delivers a dependable, functional feel without feeling sharp or aggressive.
- **Containers & Cards**: `rounded-lg` (16px). Softens large blocks of information, imparting warmth to person profiles and prayer cards.
- **Status Tags & Action Badges**: Pill-shaped (`rounded-full` / 9999px) for quick-tap status chips, spiritual milestone pills, and call/message badges to signify tapability at a glance.

## Components

### Buttons & Action Triggers
- **Primary CTA**: `#C25E3E` background, `#FFFFFF` text, min-height 52px for primary outreach events, bold `16px` font. Radius: 12px.
- **Direct Comm Badges (WhatsApp & Call)**: Dedicated dual button group.
  - **Call Button**: `#F3EFEA` background, `#1E293B` text, with a dark slate telephone icon. Min 48px height.
  - **WhatsApp / Message Button**: `#E8F2EC` (pale sage wash), `#2D5746` label and messaging icon. High affordance for conversational outreach.

### Spiritual Journey Stage Badges
- Represent stages (e.g., *Connected*, *Exploring*, *Believer*, *Baptized*, *Disciple*).
- Full pill format (`rounded-full`), padded `6px 14px`.
- Stage variants:
  - *Initial Connection*: `#F3EFEA` container, `#57534E` text.
  - *Seeking / Exploring*: `#FEF3E2` (light amber wash), `#B45309` text.
  - *Committed / Growing*: `#E8F2EC` (light sage wash), `#234E3F` text.
  - *Leader / Multiplying*: `#FAECE7` (light terracotta wash), `#9C3D20` text.

### Quick-Tap Chips
- Used for fast tagging after a street or doorstep encounter (e.g., "Needs Bible", "Prayer for Healing", "Family", "Follow-Up Tuesday").
- Compact height (36px visually, 48px touch zone), 1px solid border `#E8E2D9`, background `#FFFFFF`. When selected, transitions to `#C25E3E` fill with `#FFFFFF` text.

### Contact Cards
- Pure white `#FFFFFF` surface with `1px solid #E8E2D9` perimeter. 
- Internal padding: `space-md` (16px).
- Top row: Contact full name (`title-lg`), spiritual stage badge on the right.
- Middle row: Last contact timestamp and last prayer point in `body-md` (`#1E293B`).
- Bottom row: Fast communication actions (WhatsApp / Call / Quick Log Note) separated by thin dividers.

### Form Inputs & Fast-Log Fields
- 52px height minimum, `#FFFFFF` background with `1px solid #D5CFC7`.
- Focus state: `2px solid #C25E3E` with zero blur displacement to prevent interface vibration on mobile keyboards.
- Large multi-line speech-to-text note capture area styled with clear mic indicator.

### Checkboxes & Segmented Controls
- Checkboxes: 24×24px visual box (with 48px touch padding), rounded 6px, `#4A7A68` active fill with white checkmark.
- Segmented Filters: Sand container (`#F3EFEA`) with sliding white pill toggles for filtering outreach territories and team rosters.