---
name: Carp24 Editorial
colors:
  surface: '#f6fbec'
  surface-dim: '#d7dccd'
  surface-bright: '#f6fbec'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f6e7'
  surface-container: '#ebf0e1'
  surface-container-high: '#e5eadb'
  surface-container-highest: '#dfe4d6'
  on-surface: '#181d14'
  on-surface-variant: '#45483f'
  inverse-surface: '#2d3228'
  inverse-on-surface: '#eef3e4'
  outline: '#76786e'
  outline-variant: '#c6c8bc'
  surface-tint: '#556342'
  primary: '#546140'
  on-primary: '#ffffff'
  primary-container: '#6c7a57'
  on-primary-container: '#fdfff0'
  inverse-primary: '#bdcca4'
  secondary: '#61603a'
  on-secondary: '#ffffff'
  secondary-container: '#e7e5b4'
  on-secondary-container: '#67663f'
  tertiary: '#496163'
  on-tertiary: '#ffffff'
  tertiary-container: '#617a7c'
  on-tertiary-container: '#faffff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d9e8be'
  primary-fixed-dim: '#bdcca4'
  on-primary-fixed: '#141f05'
  on-primary-fixed-variant: '#3e4b2c'
  secondary-fixed: '#e7e5b4'
  secondary-fixed-dim: '#cbc99a'
  on-secondary-fixed: '#1d1d01'
  on-secondary-fixed-variant: '#494824'
  tertiary-fixed: '#cde7e9'
  tertiary-fixed-dim: '#b1cbcd'
  on-tertiary-fixed: '#061f21'
  on-tertiary-fixed-variant: '#334b4d'
  background: '#f6fbec'
  on-background: '#181d14'
  surface-variant: '#dfe4d6'
typography:
  display-lg:
    fontFamily: Source Serif 4
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Source Serif 4
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: Source Serif 4
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  headline-md:
    fontFamily: Source Serif 4
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Source Sans 3
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Source Sans 3
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-sm:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.1em
  nav-item:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.08em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  gutter: 20px
  margin-mobile: 16px
  margin-desktop: 64px
---

## Brand & Style

The design system is centered on a **Premium Editorial** aesthetic, evoking the tactile sensation of a high-end, leather-bound fishing journal. It moves away from the typical rugged, "outdoor-utility" look of fishing apps in favor of a sophisticated, literary experience that treats angling as an art form.

The style leans into **Minimalism with Tactile Accents**, utilizing generous whitespace and thin, precise hairlines to organize data. The interface should feel calm, permanent, and archival. Subtle grain overlays on the background and card surfaces are encouraged to enhance the physical "bound book" atmosphere.

**Target Audience:** Discerning anglers who value the story of the catch as much as the data, seeking a refined environment to document their heritage on the water.

## Colors

The palette is a curated selection of organic tones that mirror the lakefront environment:

- **Background (Warm Sand):** Used for the base canvas of the application to provide a warm, non-glare reading experience.
- **Surface (Khaki):** Used for primary content containers and cards, providing a soft contrast against the sand background.
- **Primary (Olive):** Reserved for interactive elements, primary buttons, and iconography.
- **Neutral (Dark Moss):** The sole color for typography to ensure maximum legibility and a classic ink-on-paper feel.
- **Accent (Water Blue):** Used sparingly for data visualizations (e.g., barometric pressure or depth charts) and subtle success states.

## Typography

This design system employs a tiered typographic hierarchy to establish an editorial rhythm:

1. **Headlines (Source Serif 4):** Provides a literary and authoritative tone. Larger headings should use tighter letter spacing for a premium "masthead" feel.
2. **Body (Source Sans 3):** Offers high legibility for long-form catch logs and descriptions. It remains neutral to allow the serif headlines to shine.
3. **Labels & Metadata (JetBrains Mono):** Injected to represent the "logbook" aspect—precise, technical, and slightly utilitarian. Always use uppercase for labels with increased letter-spacing to ensure a modern, clean look.

## Layout & Spacing

The layout philosophy follows a **Fixed Grid with Wide Margins**. On desktop, the content is centered with expansive lateral whitespace to focus the eye, similar to the layout of a premium hardcover book.

- **Grid:** A 12-column grid for desktop; a 4-column grid for mobile.
- **Rhythm:** Use increments of 8px for vertical rhythm, but increase to 40px (xl) between major sections to maintain the "airy" editorial feel.
- **Gutters:** Standardized at 20px to provide clear separation between cards while maintaining a tight, professional structure.

## Elevation & Depth

This design system avoids heavy shadows and floating elements to maintain its grounded, tactile nature.

- **Low-Contrast Outlines:** Depth is created through color shifts (Sand background vs. Khaki surfaces) and **Thin Olive Hairlines** (1px at 40% opacity).
- **Tonal Layering:** Instead of elevation, use "inset" or "pressed" states for interactive fields, reinforcing the physical journal metaphor.
- **No Box Shadows:** Avoid traditional CSS box shadows. If depth is required for a modal, use a solid 2px offset border in Dark Moss or a very subtle, large-radius tint-based shadow that mimics the soft light of a lakeside morning.

## Shapes

The shape language is consistently soft but structured. All primary cards and containers must use a **16px border radius** to soften the layout and make it feel approachable.

- **Primary Buttons:** Should use a fully pill-shaped radius (rounded-xl) to contrast against the rectangular content cards.
- **Input Fields:** 8px (rounded-lg) for a more precise, technical feel compared to the softer container cards.
- **Images:** Catch photos should feature the same 16px radius as cards to integrate seamlessly into the layout.

## Components

- **Cards:** The primary container. Background: `#CCCA9B`; Border: 1px `#4A5338` at 40% opacity; Radius: 16px. Content inside cards should have at least 24px of internal padding.
- **Buttons (Primary):** Solid `#6C7A57` background with white or very light sand text. Pill-shaped. Label font: JetBrains Mono.
- **Buttons (Secondary):** 1px Olive hairline border with no fill.
- **Lists:** Separated by thin 1px horizontal hairlines in `#4A5338` (20% opacity). Items should have generous vertical padding (16px+).
- **Inputs:** Use a subtle inset fill (Sand color) within the Khaki cards. Labels must be JetBrains Mono, Uppercase, positioned above the field.
- **Chips/Tags:** Small, pill-shaped tags using Water Blue (`#7B9496`) at 10% opacity with solid Water Blue text for weather or gear tags.
- **Navigation:** Top-tier navigation uses JetBrains Mono with 8% letter spacing. The active state is indicated by a simple 1px underline in Olive rather than a background change.
