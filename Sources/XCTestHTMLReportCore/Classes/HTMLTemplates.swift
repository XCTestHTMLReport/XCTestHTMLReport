
/// The hand-maintained source of truth for the report's markup, styles, and
/// scripts. Edit the template strings below directly.

struct HTMLTemplates
{
  static let index = """
  <!doctype html>

  <html lang=\"en\">
  <head>
    <meta charset=\"utf-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">

    <title>[[TITLE]]</title>
    <meta name=\"description\" content=\"Xcode Testing HTML Report\">

    <style type=\"text/css\">

    /* Design tokens (#439). The token layer is the whole theme: every colour
       the report paints comes from here, so the dark block below overrides
       values only — it contains no selectors of its own. */
    :root {
      /* Follow the OS. Also gives form controls and scrollbars the right
         appearance, which a background-colour alone does not. */
      color-scheme: light dark;

      /* Colour — brand.
         --color-accent is the selection fill (white text sits on it);
         --color-accent-text is the same blue used *as* text on a surface.
         They are separate tokens because dark mode cannot satisfy both
         roles with one value: a fill dark enough for white text is too
         dark to read as text itself. */
      --color-accent: #1163CC;
      --color-accent-text: #1163CC;
      --color-accent-soft: #B1D3FE;
      --color-on-accent: #FFF;

      /* Colour — text */
      --color-text-primary: #111;
      --color-text-secondary: #333;
      --color-text-muted: #555;
      --color-text-subtle: #555;
      --color-text-placeholder: #6E6E73;

      /* Colour — status. One token per outcome, because #439 gives all six
         states a glyph and a glyph needs a colour of its own. These are icon
         fills, so the floor is 3:1 (WCAG non-text contrast) against the
         lightest surface a row can sit on — the chrome ground, not the page.
         The
         values clear it with room: 3.76 (passed) to 4.81 (failed). */
      --status-passed: #1E8E3E;
      --status-failed: #D70015;
      --status-skipped: #6E6E73;
      --status-unknown: #6E6E73;
      --status-expected: #9A6400;
      /* Mixed is the one status the tree draws from two tokens rather than
         one — half passed, half failed, because that is what it means. A
         14px ring arc and a 10px legend swatch are too small to read a split
         at, so the summary header (#439, A1) paints mixed in a single hue of
         its own instead, chosen not to collide with any other status. The
         tree's split diamond is unchanged; both readings still say "some of
         each", one by geometry and one by being neither green nor red. */
      --status-mixed: #8944AB;

      /* Colour — surfaces.

         `--color-bg-chrome` was `--color-bg-sidebar` until A3a. The value is
         unchanged in both themes; only the name moved, because the two
         sidebars it was named for no longer exist. What it paints now is the
         report's chrome — the per-view toolbars, the device picker's panel and
         the attachment sheet's head — which is the same role it always had and
         the same ground every status token was measured against (the dark
         theme's #232327 is still the lightest surface a glyph can land on, so
         A1's and A2's 3:1 figures carry over unrecomputed). */
      --color-surface: #FFF;
      --color-bg-chrome: #F2F2F2;
      --color-bg-group-header: #F6F6F6;

      /* Colour — the tests tree (#439, A2). Four roles the sheet had no way
         to say before, because before this the tree painted nothing at all
         between the page background and a selected row.

         Every pairing was computed before it was used; the table is in the
         PR body. The tightest text pairing these introduce is the failure
         message on its own tint — 4.74:1 light, 5.35:1 dark, against a 4.5
         floor — and the tightest status badge is passed on a hovered row,
         3.69:1 light and 6.54:1 dark against the 3:1 non-text floor.

         --color-tree-guide is deliberately below 3:1 (1.28 light / 1.44
         dark, against the panel it is drawn on), for the same reason
         --color-summary-border is: the timeline
         rule restates the nesting that indentation already states, so it is
         decorative under 1.4.11 and drawing it at 3:1 would put a hard black
         bar down the middle of every expanded test. */
      --color-row-hover: #F0F0F2;
      --color-bg-activities: #F7F7F9;
      --color-fail-tint: #FDEDEC;
      --color-tree-guide: #DCDCE1;

      /* Colour — the summary header (#439, A1). A band with cards on it,
         which is one more surface level than the rest of the report has, so
         these are their own tokens rather than reuses. Values are Apple's
         grouped-background pairing; the dark block below is the primary one
         (this direction is dark-first) and light is its inversion.

         Every text pairing these introduce was computed before it was used;
         the table is in the PR body. The tightest are muted text on the
         striped digest row — 6.97:1 light, 5.11:1 dark — and the accent the
         digest's jump buttons use, 5.33:1 light, 6.50:1 dark. The status
         fills the ring and the bars paint clear the 3:1 non-text floor
         against the card by 4.21:1 (passed, light) at worst.

         --color-summary-border and --color-donut-track do not clear 3:1 and
         are not meant to: a card edge and the ring's empty groove carry no
         information the arcs and the legend do not already carry in colour
         *and* in text, and 1.4.11 scopes the floor to graphics you must
         perceive to understand the content. Raising them to 3:1 would draw
         the heavy outline the rest of the sheet already avoids. */
      --color-bg-summary: #ECECEE;
      --color-summary-card: #FFF;
      --color-summary-card-alt: #F7F7F9;
      --color-summary-border: #D2D2D7;
      --color-donut-track: #E3E3E8;

      /* Colour — borders.

         `--color-border-control` is the one border in the sheet held to a
         contrast floor, and it is new in A3a (#439). The rest of these outline
         regions — a card, a pane edge, a row's hairline — which 1.4.11 scopes
         out as decoration, because the thing they bound is identified by its
         own content. A control is not: the boundary of the device picker's
         summary and of the sheet's Close button is part of what says "this is
         a button", so it is sized against the ground it is drawn on (3.24:1
         light and 3.48:1 dark against the chrome ground; 3.62 and 4.02 against
         the surface) rather than picked to look quiet. The full table is in
         the PR body. */
      --color-border-control: #86868B;
      --color-border-strong: #BBB;
      --color-border-medium: #CCC;
      --color-border-light: #DDD;
      --color-border-faint: #E5E5E5;
      /* Was #021A40 — a near-black navy, and the only colour in the light
         theme that belonged to no family. It framed the screenshot flow in a
         hard dark rectangle; the dark theme had already been given a normal
         border value for it. This is the light theme's equivalent, so the
         frame now reads as a frame in both. Decorative: it outlines an image
         that is itself the content. */
      --color-preview-border: #D2D2D7;

      /* Typography — the system UI face, so the report looks native on the
         platform it is read on. `system-ui` first, `-apple-system` for the
         Safari versions that predate it, then named fallbacks, and a
         generic family last so the chain can always terminate. */
      --font-family-base: system-ui, -apple-system, \"Segoe UI\", Roboto, \"Helvetica Neue\", Helvetica, Arial, sans-serif;
      --font-size-xs: 11px;
      --font-size-sm: 12px;
      --font-size-md: 13px;
      --font-size-lg: 16px;
      --font-size-xl: 17px;
      --font-size-title: 20px;
      --font-weight-regular: 400;
      --font-weight-medium: 500;

      /* Spacing — the two steps used as a shared scale, i.e. repeated across
         unrelated components. 2px and 6px each also appear four times, but
         as component-local nudges (icon baseline shifts, the #title padding,
         a control's own inset) with no common meaning to name, so they stay
         inline. */
      --space-xs: 4px;
      --space-sm: 10px;

      /* Component sizes */
      --icon-size-sm: 10px;
      --icon-size: 14px;
      --icon-size-lg: 24px;
      --radius-sm: 3px;

      /* One nesting level of the tree. Applied to the child container, not
         written into the markup — see the indentation rule below for why
         that distinction is load-bearing for the differential. */
      --tree-indent: 16px;

      /* How far a row's background bleeds left, past the indentation its
         container spends. Declared here at its *off* value and overridden to
         a real distance by the three row kinds that want it, so the default
         lives in one place and `tokens.spec.ts` can see it declared like any
         other custom property. */
      --row-bleed: 0;

      /* Glyphs. Shapes, not colours — the colour is applied separately (see
         the icon block below), which is why these are shared by both themes
         and the dark block does not repeat them. Kept here so the sheet has
         exactly one place where the report's iconography is defined.

         Geometry note (#439, A2). Every status glyph is the same rounded
         square — Xcode 26's badge — and the six states differ by the glyph
         inside it and by whether the square is filled or outlined. Filled
         means the outcome is settled (passed, failed, skipped, mixed and
         expected-failure: a test that failed exactly as it declared it
         would is a settled outcome); outlined means it is not (unknown is
         the only state that means "we could not tell").

         This replaces the rounded diamond #459 drew. The six *shapes* are
         the same six #459 introduced, which is the property that mattered:
         status is never colour alone, and no state renders a blank cell.
         Only the silhouette moved, and it moved because Option A's whole
         premise is reading as a sibling of Xcode's own report.

         The glyph is a knock-out — a hole showing whatever surface the row
         paints — rather than the white glyph the mockup draws. White on the
         mockup's green is 3.13:1; a knock-out's contrast against its fill
         is by construction the status token's contrast against the row,
         which is the pairing #439 already sized to clear 3:1 in both
         themes. Same picture on a white row, a measured one everywhere
         else. */
      --icon-status-passed: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1' y='1' width='14' height='14' rx='4.2' fill='white'/%3E%3Cpath d='M4.6 8.15 6.85 10.4 11.4 5.75' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-failed: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1' y='1' width='14' height='14' rx='4.2' fill='white'/%3E%3Cpath d='M5.7 5.7 10.3 10.3M10.3 5.7 5.7 10.3' fill='none' stroke='black' stroke-width='2' stroke-linecap='round'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-skipped: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1' y='1' width='14' height='14' rx='4.2' fill='white'/%3E%3Cpath d='M5.5 10.1 10.4 5.9M6.2 5.9h4.3v4.3' fill='none' stroke='black' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-mixed: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1' y='1' width='14' height='14' rx='4.2' fill='white'/%3E%3Cpath d='M8 .6V15.4' fill='none' stroke='black' stroke-width='1.4'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-unknown: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Crect x='1.8' y='1.8' width='12.4' height='12.4' rx='3.4' fill='none' stroke='black' stroke-width='1.6'/%3E%3Cpath d='M6.5 6.4a1.6 1.6 0 1 1 1.6 1.9v.8' fill='none' stroke='black' stroke-width='1.3' stroke-linecap='round'/%3E%3Ccircle cx='8.1' cy='11.2' r='.8'/%3E%3C/svg%3E");
      --icon-status-expected: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1' y='1' width='14' height='14' rx='4.2' fill='white'/%3E%3Cpath d='M8 4.3v4.2' fill='none' stroke='black' stroke-width='2' stroke-linecap='round'/%3E%3Ccircle cx='8' cy='11.4' r='1.05' fill='black'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-disclosure: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'%3E%3Cpath d='M3 1.4 8 5 3 8.6Z'/%3E%3C/svg%3E");
      --icon-disclosure-open: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'%3E%3Cpath d='M1.4 3 8.6 3 5 8Z'/%3E%3C/svg%3E");
      --icon-paperclip: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M2.7 15.3c-.7 0-1.4-.3-1.9-.8-.9-.9-1.2-2.5 0-3.7l8.9-8.9c1.4-1.4 3.8-1.4 5.2 0s1.4 3.8 0 5.2l-7.4 7.4c-.2.2-.5.2-.7 0s-.2-.5 0-.7l7.4-7.4c1-1 1-2.7 0-3.7s-2.7-1-3.7 0l-8.9 8.9c-.8.8-.6 1.7 0 2.2.6.6 1.5.8 2.2 0l8.9-8.9c.2-.2.2-.5 0-.7s-.5-.2-.7 0l-7.4 7.4c-.2.2-.5.2-.7 0s-.2-.5 0-.7l7.4-7.4c.6-.6 1.6-.6 2.2 0s.6 1.6 0 2.2l-8.9 8.9c-.6.4-1.3.7-1.9.7z'/%3E%3C/svg%3E");
      --icon-preview: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 12'%3E%3Cpath d='M1 6s2.7-4 7-4 7 4 7 4-2.7 4-7 4-7-4-7-4z' fill='none' stroke='black' stroke-width='1.3'/%3E%3Ccircle cx='8' cy='6' r='1.9'/%3E%3C/svg%3E");
      --icon-document: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Cpath d='M3.2 1.4h6L13 5.2v9.4H3.2Z' fill='white'/%3E%3Cpath d='M5.2 7.4h5.6M5.2 9.6h5.6M5.2 11.8h3.6' stroke='black' stroke-width='1.1' stroke-linecap='round'/%3E%3Cpath d='M8.9 1.6v3.6h3.6' fill='none' stroke='black' stroke-width='1.1'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1.4' y='2.8' width='13.2' height='10.4' rx='1.4' fill='white'/%3E%3Cpath d='M2.6 12 6.3 7.6l2.5 2.6 2-2 2.6 3.8Z' fill='black'/%3E%3Ccircle cx='5.4' cy='6' r='1.3' fill='black'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-video: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1.4' y='3.2' width='13.2' height='9.6' rx='1.4' fill='white'/%3E%3Cpath d='M6.6 5.9 11 8l-4.4 2.1Z' fill='black'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
    }

    /* Dark theme. Token values only — every selector in the sheet is shared
       with the light theme, which is what the token layer bought us. */
    @media (prefers-color-scheme: dark) {
      :root {
        /* The selection fill lands on three different backgrounds — the
           chrome ground (#232327, the lightest and so the binding one), the
           surface, and the group header — and has to clear 3:1 against each
           while still carrying white text at 4.5:1. That window is narrow:
           at this hue no value clears both floors by more than ~7%, and this
           one sits at its centre (chrome 3.25, white 4.82). Splitting a
           separate fill token would buy nothing, because the selected device
           option needs both floors satisfied at once. */
        --color-accent: #2170D6;
        --color-accent-text: #7FB0FF;
        --color-accent-soft: #274A73;
        --color-on-accent: #FFF;

        --color-text-primary: #E8E8EA;
        --color-text-secondary: #C9C9CE;
        --color-text-muted: #9A9AA2;
        --color-text-subtle: #9A9AA2;
        --color-text-placeholder: #8A8A92;

        /* Same 3:1 floor, measured against the dark chrome ground (#232327):
           5.61 (skipped/unknown) to 6.74 (expected). */
        --status-passed: #4FBF6B;
        --status-failed: #FF6E6A;
        --status-skipped: #9A9AA2;
        --status-unknown: #9A9AA2;
        --status-expected: #D9A038;
        --status-mixed: #C89AF5;

        --color-surface: #161619;
        --color-bg-chrome: #232327;
        --color-bg-group-header: #202024;

        /* The tree's own surfaces. The activities panel is *lighter* than the
           page here and *darker* than it in light, because white has no room
           above it and this ground has little worth reading below it: each
           theme steps the panel in the direction it actually has. What
           carries the meaning is that it steps at all — one value off the
           page is what makes an expanded test's steps read as their own
           region under the row rather than as more tree. */
        --color-row-hover: #25252A;
        --color-bg-activities: #1D1D21;
        --color-fail-tint: #3A2226;
        --color-tree-guide: #38383E;

        /* The summary header's own surfaces. The card is the same value as
           the chrome ground, which is deliberate: it is the lightest ground in
           the dark theme, so every status token was already sized against it and
           the header inherits those measurements unchanged (5.61 skipped to
           6.74 expected). The band beneath the cards is darker than the page
           so the cards read as raised, the way Xcode's do. */
        --color-bg-summary: #19191C;
        --color-summary-card: #232327;
        --color-summary-card-alt: #2A2A2F;
        --color-summary-border: #3A3A40;
        --color-donut-track: #3A3A40;

        --color-border-control: #767680;
        --color-border-strong: #3A3A40;
        --color-border-medium: #33333A;
        --color-border-light: #2E2E34;
        --color-border-faint: #2A2A2F;
        --color-preview-border: #3A3A40;
      }
    }

    html, body {
      margin: 0;
      padding: 0;
      font-family: var(--font-family-base);
      height: 100%;
      overflow: hidden;
      /* Explicit, so the canvas is ours in both themes. Previously unset:
         the white page was the browser default, which is what made dark
         mode impossible to bolt on. */
      background-color: var(--color-surface);
      color: var(--color-text-primary);
    }

    ul li {
      list-style: none;
    }

    p, ul {
      margin: 0;
      padding: 0;
    }

    a {
      text-decoration: none;
    }

    /* ---- The shell (#439, A3a) ----------------------------------------

       Three panes became per-view surfaces. The header is what every view
       shares — the report's identity, which run is being read, and which view
       is showing it — and below it exactly one view owns the whole content
       area, toolbar included.

       What that replaces: an always-on 200px device sidebar and an always-on
       400px attachment pane, both of which were in the layout whether or not
       they had anything to say. On a single-device run at 1440px that was
       ~600px, 42% of the window, spent on one device card and the words "No
       Selected Attachment" (audit findings 1 and 3). Both jobs move: device
       selection into the header picker below, attachments into a sheet the
       Tests view summons. */
    header {
      color: var(--color-text-primary);
      background-color: var(--color-surface);
      width: 100%;
      /* A flex item shrinks by default, and #439's summary band made that
         visible: in a short window the header shrank below its content and
         `overflow: hidden` on the body clipped the digest. The band caps its
         own height at 50vh, so refusing to shrink cannot starve the views. */
      flex: none;
    }

    /* The title band: identity on the left, which run on the right. */
    #title {
      display: flex;
      align-items: center;
      gap: var(--space-sm);
      border-bottom: 1px solid var(--color-border-light);
      padding: 6px var(--space-sm);
    }

    #title h1 {
      font-size: var(--font-size-title);
      margin: 0;
      font-weight: var(--font-weight-regular);
    }

    /* ---- The device picker (#439, A3a) --------------------------------

       One control, not two. A1 gave the summary band a "Devices &
       Configurations" card that stated each run's pass/fail split, and the
       shell separately carried a sidebar that *selected* a run — two places
       naming the same set, one of which could not act and one of which could
       not tell you anything. The bars are now inside the picker: every option
       is a real button carrying the glyph, the destination, the proportional
       bar and the same spoken tally the card had.

       `<details>`, so the disclosure is the browser's — keyboard-operable,
       announced as expanded or collapsed, and correct with no script at all.
       The options inside are ordinary buttons, so Tab reaches them and Enter
       and Space activate them without a roving-tabindex widget; the current
       one carries `aria-current`, which is exactly "the current member of a
       set" and needs no live region to stay true. */
    .device-picker {
      margin-left: auto;
      position: relative;
      font-size: var(--font-size-sm);
    }

    .device-picker > summary {
      display: flex;
      align-items: center;
      gap: 6px;
      max-width: 46vw;
      padding: 3px 8px;
      border: 1px solid var(--color-border-control);
      border-radius: var(--radius-sm);
      background-color: var(--color-bg-chrome);
      cursor: pointer;
      /* The marker is replaced by the chevron span below, which can be
         painted from a token; `::marker` cannot. */
      list-style: none;
    }

    .device-picker > summary::-webkit-details-marker {
      display: none;
    }

    .device-picker > summary:hover {
      background-color: var(--color-row-hover);
    }

    .device-picker > summary:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: 1px;
    }

    .picker-label {
      color: var(--color-text-muted);
      flex: none;
    }

    /* The one line that has to survive a narrow window: it says which run is
       on screen, so it truncates rather than wraps or pushes. */
    .picker-current {
      overflow: hidden;
      white-space: nowrap;
      text-overflow: ellipsis;
    }

    .picker-chevron {
      flex: none;
      width: var(--icon-size-sm);
      height: var(--icon-size-sm);
      background-color: var(--color-text-muted);
      -webkit-mask-image: var(--icon-disclosure);
      mask-image: var(--icon-disclosure);
      -webkit-mask-repeat: no-repeat;
      mask-repeat: no-repeat;
      -webkit-mask-position: center;
      mask-position: center;
      -webkit-mask-size: contain;
      mask-size: contain;
    }

    .device-picker[open] > summary .picker-chevron {
      -webkit-mask-image: var(--icon-disclosure-open);
      mask-image: var(--icon-disclosure-open);
    }

    /* Absolutely positioned, so opening the picker does not reflow the header
       and push the view below it down a row. Capped and scrollable because a
       merged report can hold more destinations than fit a window. */
    .picker-panel {
      position: absolute;
      right: 0;
      top: calc(100% + 4px);
      z-index: 60;
      width: max(280px, 100%);
      max-height: 60vh;
      overflow-y: auto;
      padding: var(--space-xs);
      background-color: var(--color-bg-chrome);
      border: 1px solid var(--color-border-strong);
      border-radius: 8px;
    }

    .device-option {
      display: block;
      width: 100%;
      margin: 0;
      padding: 6px 8px;
      border: 0;
      border-radius: var(--radius-sm);
      background: none;
      font: inherit;
      color: var(--color-text-primary);
      text-align: left;
      cursor: pointer;
    }

    .device-option:hover {
      background-color: var(--color-row-hover);
    }

    .device-option:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: -2px;
    }

    /* `aria-current`, not a class, drives the selected look: the attribute is
       the accessible fact and a second class saying the same thing is a second
       thing to keep in sync. */
    .device-option[aria-current="true"] {
      background-color: var(--color-accent);
      color: var(--color-on-accent);
    }

    .device-option-head {
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .device-option .device-result {
      flex: none;
    }

    /* Three lines, not one run-on sentence: the destination, then what it
       produced, then what it is. `display: block` because both are `<span>`s —
       they carry no layout of their own, so the option is where the stacking
       is decided. */
    .device-option-meta,
    .device-row-tally {
      display: block;
      color: var(--color-text-muted);
      font-size: var(--font-size-xs);
      line-height: 1.4;
    }

    /* Every muted part of the option, on the one option that is not on a muted
       ground. Listed rather than matched with `*` so a future element has to
       be considered rather than inheriting a colour by accident. */
    .device-option[aria-current="true"] .device-option-meta,
    .device-option[aria-current="true"] .device-row-tally,
    .device-option[aria-current="true"] .device-row-os,
    .device-option[aria-current="true"] .device-row-run {
      color: var(--color-on-accent);
    }

    /* ---- The view switcher (#439, A3a) --------------------------------

       A real tablist, replacing two `<li onclick>` that no keyboard could
       reach. Tests and Logs are the two views today; the pattern is what a
       third would join, which is why the tab and its panel are wired by
       `aria-controls` rather than by position. */
    .view-tabs {
      display: flex;
      gap: 2px;
      padding: 0 var(--space-sm);
      border-bottom: 1px solid var(--color-border-strong);
    }

    .view-tab {
      padding: 5px var(--space-sm);
      border: 0;
      border-bottom: 2px solid transparent;
      background: none;
      font: inherit;
      font-size: var(--font-size-sm);
      color: var(--color-text-muted);
      cursor: pointer;
    }

    .view-tab:hover {
      color: var(--color-text-primary);
    }

    .view-tab[aria-selected="true"] {
      color: var(--color-accent-text);
      border-bottom-color: var(--color-accent);
    }

    .view-tab:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: -2px;
    }

    /* ---- Per-view surfaces (#439, A3a) --------------------------------

       Each view is a column that owns everything below the tabs: its own
       toolbar, its own content, and — on Tests — its own attachment sheet.
       Only one is in the layout at a time, and the inactive one is removed by
       `display: none` rather than moved off screen, which is also what takes
       it out of the accessibility tree — so a screen reader on the Logs tab
       cannot walk into the tests tree, and nothing attachment-shaped exists
       for it to find. */
    .view {
      flex: 1;
      min-height: 0;
      flex-direction: column;
    }

    .view.active {
      display: flex;
    }

    .view:not(.active) {
      display: none;
    }

    /* One run's slice of a view. Every run renders both slices; the picker
       activates the pair belonging to one destination. */
    .run-view {
      display: none;
      flex: 1;
      min-height: 0;
      flex-direction: column;
    }

    .run-view.active {
      display: flex;
    }

    /* The per-view toolbar. Left group is the view's own controls; the
       trailing group is deliberately empty and deliberately present — it is
       where A3b's text filter and its dropdowns land (#460), and reserving it
       here is what keeps that from being a re-layout. */
    .view-toolbar {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: var(--space-xs);
      flex: none;
      min-height: 26px;
      padding: var(--space-xs) var(--space-sm);
      background-color: var(--color-bg-chrome);
      border-bottom: 1px solid var(--color-border-light);
    }

    .view-toolbar-trailing {
      margin-left: auto;
      display: flex;
      align-items: center;
      gap: var(--space-xs);
    }

    /* A label, not a control. The Logs view has one scope and no way to change
       it, and the shipped markup said otherwise: `<li class="selected">All
       Messages</li>` in a `toggle-toolbar`, wearing a selected pill's fill and
       hover with nothing bound to it. Dressing an inert string as the chosen
       one of several options is the kind of thing a keyboard user finds out
       the hard way. Real log filters are #460's, and land in the trailing slot
       beside this. */
    .view-toolbar-label {
      padding: 2px var(--space-sm);
      color: var(--color-text-muted);
      font-size: var(--font-size-xs);
    }

    /* The status filters. Buttons in a radiogroup, because they are mutually
       exclusive and only one can be in effect — `aria-checked` says which,
       where the old `<li class="selected">` said nothing at all. A3b upgrades
       what they filter; the five functions behind them are unchanged. */
    .filter-pills {
      display: flex;
      flex-wrap: wrap;
      gap: 2px;
    }

    .pill {
      padding: 2px var(--space-sm);
      border: 0;
      border-radius: var(--radius-sm);
      background: none;
      font: inherit;
      font-size: var(--font-size-xs);
      color: var(--color-text-muted);
      cursor: pointer;
    }

    .pill:hover {
      background-color: var(--color-accent-soft);
      /* Primary, not --color-on-accent: the soft tint is a pale wash, and
         white on it was 1.55:1. */
      color: var(--color-text-primary);
    }

    .pill[aria-checked="true"] {
      background-color: var(--color-accent);
      color: var(--color-on-accent);
    }

    .pill:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: 1px;
    }

    /* The tree's column header. Two labels, at the two ends of the row the
       columns actually occupy, rather than the old "Status | Tests" pair
       stacked against the left edge — there is a duration column to name now,
       and naming it is the only thing that makes it read as a column.

       A3a lifts it out of the scroll container: it names the columns of every
       row, so scrolling it away was the one thing it could not afford to do. */
    .table-header {
      display: flex;
      flex: none;
      min-height: 18px;
      margin: 0;
      padding: 2px var(--space-sm) 2px 6px;
      border-bottom: 1px solid var(--color-border-light);
    }

    .table-header li {
      font-size: var(--font-size-xs);
      color: var(--color-text-muted);
    }

    .table-header li+li {
      margin-left: auto;
    }

    .logs-iframe {
      border: 0;
      flex: 1;
      min-height: 0;
    }

    /* Icons (#439).

       Every glyph is a one-colour SVG applied as a CSS *mask* rather than
       painted as a background image, and its colour comes from
       `background-color` showing through. That indirection is the whole
       point: a data-URI image cannot see the token layer, so the ~300KB of
       base64 PNGs this replaces could not be themed at all — which is why
       the sheet used to ship a second, white copy of four of them just for
       selected rows. With a mask, `currentColor` inherits the row's colour
       for free (white on a selected row, red on a failure row) and status
       glyphs take a token that the dark block re-points.

       The SVGs are URL-encoded rather than base64: same bytes on the wire
       minus the ~33% base64 overhead, and readable in this file. Where a
       glyph is knocked out of a filled shape (the check inside the pass
       diamond, the lines inside the document) the cut-out is an SVG
       `<mask>` inside the image, so what reaches CSS is a single alpha
       shape. Nothing here fetches anything: `-i` single-file reports keep
       working byte-for-byte the same way. */
    .icon {
      height: var(--icon-size);
      width: var(--icon-size);
      margin: 0 var(--space-xs);
    }

    .icon.big {
      height: var(--icon-size-lg);
      width: var(--icon-size-lg);
      margin: 0;
    }

    .icon,
    .test-result-icon,
    .drop-down-icon,
    .paperclip-icon,
    .preview-icon {
      -webkit-mask-repeat: no-repeat;
      mask-repeat: no-repeat;
      -webkit-mask-position: center;
      mask-position: center;
      -webkit-mask-size: contain;
      mask-size: contain;
      background-color: currentColor;
    }

    .inline-block {
      display: inline-block;
    }

    /* `.left` went in A2 and `.clear` goes here, for the same reason and with
       the same check: A2 made the tree a flex line, A3a made the title band
       and the shell flex too, and the last two `<div class="clear">` left with
       the floats they cleared. Neither class reaches anything in the rendered
       page — verified against both goldens. */

    .paperclip-icon {
      width: var(--icon-size-sm);
      height: var(--icon-size-sm);
      -webkit-mask-image: var(--icon-paperclip);
      mask-image: var(--icon-paperclip);
    }

    .text-icon {
      -webkit-mask-image: var(--icon-document);
      mask-image: var(--icon-document);
    }

    .screenshot-icon {
      -webkit-mask-image: var(--icon-image);
      mask-image: var(--icon-image);
    }

    .video-icon {
      -webkit-mask-image: var(--icon-video);
      mask-image: var(--icon-video);
    }

    /* The status badge. It is a flex item of the row now rather than a float
       beside it, so the gutter it used to need — a 28px margin on the icon
       plus a matching 52px padding on every `<p>` in the tree, whether or not
       that row had a badge — is gone, and the tree recovers ~38px of width at
       every screen size. */
    .test-result-icon {
      display: none;
      flex: none;
      margin: 0;
    }

    /* Which rows show a status glyph at all. Before #439 only the three
       states that had a PNG appeared here, so `mixed`, `unknown` and
       `expectedFailure` rows rendered an empty status cell — the audit's
       finding 4. All six states now have one, and each is a distinct shape,
       not just a distinct colour.

       Suite headings join them in A2. #459 left them out because the badge
       was a float and giving one to a heading meant reworking the gutter;
       now that a row is a flex line it is a selector, and the mockup's tree
       puts a badge on every suite. Nothing new is computed for it —
       `TestGroup.status` already folds its children's outcomes and already
       writes the class onto the row.

       `> p >`, not a descendant combinator, throughout. It used to be
       `> .test-result-icon` because the badge was a sibling of the row; A2
       makes it a flex item *of* the row, so the path gained a level and kept
       the same property. That property is load-bearing twice over: a retried
       test nests its iterations inside the row and a suite nests its cases
       inside its own, and every one of those carries a `.test-result-icon`.
       Matched loosely, an outer row's rule reaches all of them, and since
       these selectors all have the same specificity the winner would be
       whichever is written last — which is how `testRetryOnFailure()`'s two
       iterations, one failed and one passed, once both drew their parent's
       split glyph.

       `:is()` groups the three row kinds rather than writing eighteen
       selectors out. It contributes the specificity of its most specific
       argument, and every argument here is one class, so each rule stays at
       exactly the (0,3,1) the written-out form had — which the selection
       override below relies on. */
    :is(.test-summary, .test-summary-group, .iteration):is(
      .succeeded, .skipped, .failed, .mixed, .unknown, .expected-failure
    ) > p > .test-result-icon {
      display: block;
    }

    :is(.test-summary, .test-summary-group, .iteration).succeeded > p > .test-result-icon,
    .success {
      background-color: var(--status-passed);
      -webkit-mask-image: var(--icon-status-passed);
      mask-image: var(--icon-status-passed);
    }

    :is(.test-summary, .test-summary-group, .iteration).skipped > p > .test-result-icon,
    .skip {
      background-color: var(--status-skipped);
      -webkit-mask-image: var(--icon-status-skipped);
      mask-image: var(--icon-status-skipped);
    }

    :is(.test-summary, .test-summary-group, .iteration).failed > p > .test-result-icon,
    .failure {
      background-color: var(--status-failed);
      -webkit-mask-image: var(--icon-status-failed);
      mask-image: var(--icon-status-failed);
    }

    /* Mixed is the one glyph that carries two colours, because "some passed,
       some failed" is what it means. The mask is a plain badge split by a
       thin cut, and the two halves are a hard-stop gradient — so both halves
       are tokens and follow the theme, which a two-colour image could not. */
    :is(.test-summary, .test-summary-group, .iteration).mixed > p > .test-result-icon {
      background-color: transparent;
      background-image: linear-gradient(
        90deg,
        var(--status-passed) 0 50%,
        var(--status-failed) 50% 100%
      );
      -webkit-mask-image: var(--icon-status-mixed);
      mask-image: var(--icon-status-mixed);
    }

    :is(.test-summary, .test-summary-group, .iteration).unknown > p > .test-result-icon {
      background-color: var(--status-unknown);
      -webkit-mask-image: var(--icon-status-unknown);
      mask-image: var(--icon-status-unknown);
    }

    :is(.test-summary, .test-summary-group, .iteration).expected-failure > p > .test-result-icon {
      background-color: var(--status-expected);
      -webkit-mask-image: var(--icon-status-expected);
      mask-image: var(--icon-status-expected);
    }

    /* On a selected row the badge is painted in the selection's own text
       colour and the accent knocks through the glyph, rather than the badge
       staying a status hue. Measured against the fill it would otherwise sit
       on: passed is 1.36:1 light and 2.07:1 dark against the accent — an
       invisible badge on precisely the row the reader is looking at.
       White-on-accent is 5.71 / 4.82. The outcome stays readable because the
       *shape* carries it, which is the #459 property that status is never
       colour alone.

       Written with the element selector and placed after the status rules
       deliberately: it has to match their (0,3,1) and win on order, and it
       has to clear `mixed`'s gradient as well as the flat fills. */
    p.list-item.selected > .test-result-icon {
      background-color: var(--color-on-accent);
      background-image: none;
    }

    /* The triangle is the row's quietest element, so it takes the muted text
       colour rather than `currentColor` — which on a failure row would have
       made it as loud as the failure. `flex: none` because it is the column
       every row's badge aligns against; a shrunk triangle is a bent column. */
    .drop-down-icon {
      cursor: pointer;
      flex: none;
      height: var(--icon-size-sm);
      width: var(--icon-size-sm);
      margin: 0;
      background-color: var(--color-text-muted);
      -webkit-mask-image: var(--icon-disclosure);
      mask-image: var(--icon-disclosure);
    }

    .drop-down-icon.dropped {
      -webkit-mask-image: var(--icon-disclosure-open);
      mask-image: var(--icon-disclosure-open);
    }

    p.list-item.selected > .drop-down-icon {
      background-color: var(--color-on-accent);
    }

    /* The eye is a control, not a label, so it takes the accent the rest of
       the sheet uses for "you can click this" (`.digest-jump`) instead of
       inheriting the row's text colour.

       A real `<button>` since A3a, wearing the same mask it always did. It was
       a `<span onclick>`: the only way to open an attachment was to point at
       it, which is the report's single most consequential control and the one
       a keyboard could not reach. The reset below is what a button costs —
       `padding`, `border` and the UA background — and `background-color` is
       not a surface here but the ink the mask clips, so it must survive. */
    .preview-button {
      display: inline-flex;
      align-items: center;
      flex: none;
      padding: 2px;
      border: 0;
      border-radius: var(--radius-sm);
      background: none;
      cursor: pointer;
      /* The accent the rest of the sheet uses for "you can click this"
         (`.digest-jump`), handed to the glyph as `currentColor`. */
      color: var(--color-accent-text);
    }

    .preview-button:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: 1px;
    }

    /* The ring lives on the button and the mask lives on this span, which is
       the whole reason there are two elements. A mask applies to everything
       the element paints, its outline included, so a focus ring drawn on a
       masked element is clipped to the eye's own silhouette and effectively
       invisible — on the one control in the report that had no keyboard path
       at all before A3a. */
    .preview-icon {
      display: block;
      height: 11px;
      width: 14px;
      margin: 0;
      -webkit-mask-image: var(--icon-preview);
      mask-image: var(--icon-preview);
    }

    p.list-item.selected > .paperclip-icon {
      background-color: var(--color-on-accent);
    }

    p.list-item.selected > .preview-button {
      color: var(--color-on-accent);
    }

    /* An expanded test's activities (#439, A2). The mockup draws this as a
       timeline: an inset panel under the test, a rule down its gutter, and an
       elapsed offset against every row.

       The offsets are not here, and are not faked. 4.0's `ParsedActivity`
       carries a title, a failure flag, attachments and sub-activities —
       `finish` and the per-activity timestamps left with the legacy reader
       (see the port's decision 2), so there is no field to render and no
       honest way to derive one. The rest of the treatment applies unchanged,
       and the gutter still does the job the offsets shared: it says where the
       detail of one test starts and stops. */
    .activities {
      display: none;
      margin-left: var(--tree-indent);
      border-left: 2px solid var(--color-tree-guide);
      background-color: var(--color-bg-activities);
    }

    /* Single class, so `.list-item:hover` (two) still wins the background and
       a failure row highlights like any other. The red text is what survives
       the hover, which is the part that carries the meaning. */
    .activity-assertion-failure > p {
      background-color: var(--color-fail-tint);
      color: var(--status-failed);
      font-weight: var(--font-weight-medium);
    }

    .sub-activities {
      display: none;
    }

    /* Depth inside the activities panel, one 10px step per level, written by
       `Activity.padding` into the element's own style attribute. Kept as a
       spacer element rather than folded into the row's padding because the
       model already computes it — including the +18px a leaf spends standing
       in for the triangle it does not draw. `float` had to go: floats do not
       apply to flex items, and the row is a flex line now. */
    .padding {
      flex: none;
      width: 1px;
      height: 1px;
    }

    .activity.no-drop-down .drop-down-icon {
      display: none;
    }

    /* The tree itself, and nothing else: A3a lifted the toolbar and the column
       header out of it, so what scrolls is exactly the rows. `overflow-y:
       auto`, not `scroll` — a run short enough to fit no longer reserves a
       dead gutter down the right of the page. */
    .tests {
      display: flex;
      flex: 1;
      min-height: 0;
      flex-direction: column;
      overflow-y: auto;
    }

    /* The list takes focus so it can be scrolled from the keyboard (see the
       `runTests` template). `:focus-visible`, not `:focus`, so clicking a row
       does not draw a ring around the whole tree; `outline-offset` is negative
       because the outline of a scroll container is drawn at its padding edge
       and a positive offset would sit under the sheet below it. */
    .tests:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: -2px;
    }

    .tests > .summary {
      width: 100%;
    }

    .iteration {
      margin-left: var(--space-sm);
    }

    /* ---- The tests tree (#439, A2) ------------------------------------

       Every row in the tree — suite heading, test case, iteration, activity,
       attachment — is one flex line: triangle, status badge, name, then the
       duration pushed to its own right-hand column. What this replaces was a
       pair of floats clearing a fixed 52px of left padding, which is why the
       duration could only ever be more text after the name and why a row with
       no badge still paid for the gutter of one. */
    .test-summary p, .test-summary-group p, .iteration p, .activity p {
      display: flex;
      align-items: center;
      gap: 6px;
      min-height: 24px;
      font-size: var(--font-size-sm);
      padding: 3px var(--space-sm) 3px 6px;
      border-bottom: 1px solid var(--color-border-faint);
    }

    /* No hairlines inside an expanded test. The panel's own inset surface and
       the rule down its gutter already bound the region, and the mockup's
       timeline draws no separators between its steps — with them, a test with
       thirty activities reads as thirty more tests. */
    .activities p {
      border-bottom: 0;
    }

    /* The name takes the slack and wraps inside it; `min-width: 0` because a
       flex item refuses to shrink below its content otherwise, and test names
       are long unbroken identifiers. */
    .row-name {
      flex: 1 1 auto;
      min-width: 0;
      overflow-wrap: anywhere;
    }

    /* Inside the activities panel there is no right-hand column to push
       against — no per-activity duration exists to put there — so the name
       stops claiming the slack and the paperclip and the eye stay beside the
       thing they belong to instead of drifting to the far edge. */
    .activity > p > .row-name,
    .attachment > .row-name {
      flex: 0 1 auto;
    }

    /* The duration column.

       `(N.NNs)` is not a styling choice and must not be edited into a bare
       `N.NNs`: it is literally the shape `KnownLossMasker`'s `durations` rule
       normalises, so every duration in the tree inherits a loss the allow-list
       already declares. A2 moves where the text sits and changes nothing about
       what it says. `RunSummaryTests.testTheHeadersDurationIsWrittenInAMaskedShape`
       holds the same property for the header. */
    .row-duration {
      flex: none;
      padding-left: var(--space-sm);
      color: var(--color-text-muted);
      font-variant-numeric: tabular-nums;
    }

    /* Annotations beside a name — today only a retried test's per-status
       breakdown ("1 failed, 1 succeeded"). A bordered chip, the mockup's
       treatment for the same class of aside. */
    .row-note {
      flex: none;
      padding: 0 5px;
      border: 1px solid var(--color-border-medium);
      border-radius: var(--radius-sm);
      color: var(--color-text-muted);
      font-size: var(--font-size-xs);
    }

    p.list-item.selected > .row-duration,
    p.list-item.selected > .row-note {
      color: var(--color-on-accent);
    }

    /* Indentation.

       Nesting depth is carried by the DOM and applied to the child container,
       never written into the markup as a number. That is not a stylistic
       preference: the legacy backend interposes two wrapper levels ("Selected
       tests", "<target>.xctest") that the modern backend does not, so a depth
       written into an attribute would differ between the two renders in every
       row of the tree — and `KnownLossMasker`'s `wrapperGroups` rule unwraps
       the *element*, which would leave the numbers behind and turn
       `DifferentialTests` red with no allow-list entry able to cover it.
       Nested padding indents by construction and costs the differential
       exactly nothing. */
    .test-summary-group > .test-summary,
    .test-summary-group > .test-summary-group {
      padding-left: var(--tree-indent);
    }

    /* Rows are indented by their container's padding, so a row's own box
       starts at the indent and its background would too. `--row-bleed` is how
       far that background is carried back out into the gutter the indentation
       spent; `.tests` is a scroll container, so it clips there. The mockup
       does this — its failure tint and its expanded-test band both run to the
       card's edge, under the disclosure column rather than starting after it.

       A strip painted by `::before`, not an outer `box-shadow`. A shadow is
       the whole border box translated, so an offset far enough left to clear
       any indentation drags the box's *right* edge that far left with it: at
       `-100vw` the shadow lands entirely at `x <= 0`, outside the viewport
       and outside the container that clips it, and paints nothing at all. An
       offset small enough to still overlap the row is one that a deep enough
       tree or a narrow enough pane outruns. `right: 100%` has no such
       arithmetic — the strip begins where the row begins and runs left for as
       far as it is told, at every depth and every width.

       `background-color: inherit`, so hover, selection and a suite heading's
       own ground each reach the gutter by the same declaration that paints
       the row, and a fourth state would too. Leftward overflow is unreachable
       in a left-to-right scroll container, so nothing here widens the page —
       the 375px probe covers that.

       Only the three row kinds that sit *in* the tree get a strip. Activity
       and attachment rows deliberately do not: they live inside the
       activities panel, whose inset background and gutter rule are the thing
       that says "this belongs to the test above", and a row bleeding past
       them would erase exactly that. They keep the `:root` default of `0` and
       highlight in place. */
    .test-summary > p,
    .test-summary-group > p,
    .iteration > p {
      --row-bleed: 100vw;
      position: relative;
    }

    /* `bottom: -1px`, not `0`: an absolutely positioned child is laid out
       against its containing block's *padding* box, so `0` would stop the
       strip one hairline short of the row's own background and leave a bright
       seam under every selected row. The 1px is the row's `border-bottom`
       above. */
    .test-summary > p::before,
    .test-summary-group > p::before,
    .iteration > p::before {
      content: "";
      position: absolute;
      top: 0;
      bottom: -1px;
      right: 100%;
      width: var(--row-bleed);
      background-color: inherit;
    }

    .list-item:hover {
      background-color: var(--color-row-hover);
    }

    .test-summary-group > p {
      background-color: var(--color-bg-group-header);
      font-weight: var(--font-weight-medium);
    }

    /* `visibility`, not `display`: a suite row has no working disclosure to
       draw — collapsing a group is a script change, and the filter and
       collapse scripts are A3's to rewire, not A2's to restyle around — but
       the column still has to hold, or a suite's badge would sit 16px left of
       its own children's and the tree would look bent. */
    .test-summary-group > p > .drop-down-icon {
      visibility: hidden;
    }

    /* The per-attachment source elements the sheet copies from. They have
       never been displayed — every one of them carried `display: none` — but
       until A3a they also carried a full-window absolute position and a
       600px height behind it, which read as a lightbox the report does not
       have. What they actually are is where the payload's URL lives, one
       element per attachment, addressed by id. */
    .screenshot,
    .video,
    .gif,
    .file-attachment-link {
      display: none;
    }

    /* The screenshot flow — the frames a UI test walked through, rendered in
       the tree rather than in the attachment pane.

       Sized like the mockup's inline player: a bounded box, not a slab. At a
       fixed 200px (350px for the tail) and no width bound these were the
       tallest thing in the tree by a factor of eight, so a test with a flow
       pushed every row after it off the screen — and `.screenshot-tail` is
       emitted *between* rows, so it did that to the tree, not to the panel.
       `max-height` with `height: auto` keeps whatever aspect ratio the device
       recorded instead of stretching a phone frame to a fixed height. */
    .screenshot-flow,
    .screenshot-tail {
        display: block;
        width: auto;
        max-width: min(300px, 100%);
        height: auto;
        max-height: 200px;
        margin: 6px 0 6px var(--tree-indent);
        object-fit: contain;
        border: 1px solid var(--color-preview-border);
        border-radius: 8px;
        background-color: var(--color-surface);
    }

    #content {
      height: 100%;
      display: flex;
      flex-direction: column;
    }

    #main-content {
      display: flex;
      flex: 1;
      min-height: 0;
      flex-direction: column;
    }

    /* A page footer rather than the bottom of the device sidebar it used to
       live in. `contentinfo` is the landmark it belongs in, and the link is
       the only thing in the report that is about the report rather than about
       the run. */
    #report-issue {
      flex: none;
      padding: var(--space-xs) var(--space-sm);
      text-align: right;
      background-color: var(--color-bg-chrome);
      border-top: 1px solid var(--color-border-light);
    }

    #report-issue a {
      color: var(--color-text-subtle);
      font-weight: var(--font-weight-regular);
      font-size: var(--font-size-xs);
    }

    #report-issue a:hover {
      text-decoration: underline;
    }

    #report-issue a:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: 2px;
      border-radius: var(--radius-sm);
    }

    /* ---- The attachment sheet (#439, A3a) -----------------------------

       A2 gave the ≤700px layout a bottom sheet that joined the layout only
       while an attachment was selected. A3a makes that the *only* treatment,
       at every width, and moves it inside the Tests view.

       Three things follow from that, and each was a finding before it was a
       decision. The pane no longer reserves 400px of a 1440px window to say
       "No Selected Attachment" — there is no placeholder, because a sheet with
       nothing in it is simply not there. Nothing attachment-shaped can render
       on Logs, because the sheet is a child of the Tests view and Logs hides
       that whole subtree. And there is one layout to reason about instead of
       two, which is what lets the narrow-screen query below shrink to spacing.

       Docked, not `position: fixed`. A2's sheet floated over the tree and paid
       for it with `padding-bottom: 50vh` on the list so the last rows could
       still be reached; a flex item takes its share instead, and the tree
       simply gets shorter. Nothing overlaps, so nothing needs compensating. */
    .attachment-sheet {
      display: none;
      flex: none;
      flex-direction: column;
      max-height: 50vh;
      overflow: auto;
      background-color: var(--color-surface);
      border-top: 1px solid var(--color-border-strong);
    }

    body.attachment-open .attachment-sheet {
      display: flex;
    }

    .attachment-sheet-head {
      display: flex;
      align-items: center;
      gap: var(--space-sm);
      flex: none;
      padding: var(--space-xs) var(--space-sm);
      background-color: var(--color-bg-chrome);
      border-bottom: 1px solid var(--color-border-light);
    }

    .attachment-sheet-head h2 {
      margin: 0;
      font-size: var(--font-size-md);
      font-weight: var(--font-weight-medium);
      overflow: hidden;
      white-space: nowrap;
      text-overflow: ellipsis;
    }

    .attachment-close {
      margin-left: auto;
      flex: none;
      padding: 2px var(--space-sm);
      border: 1px solid var(--color-border-control);
      border-radius: var(--radius-sm);
      background: none;
      font: inherit;
      font-size: var(--font-size-xs);
      color: var(--color-text-muted);
      cursor: pointer;
    }

    .attachment-close:hover {
      background-color: var(--color-row-hover);
      color: var(--color-text-primary);
    }

    .attachment-close:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: 1px;
    }

    .attachment-sheet-body {
      display: flex;
      flex: 1;
      min-height: 0;
      flex-direction: column;
    }

    /* `max-height` on the media, not just on the sheet: an image is
       replaced content and would otherwise size to its intrinsic height and
       make the sheet scroll rather than fit. */
    .displayed-screenshot,
    .displayed-gif,
    .displayed-video {
      display: none;
      width: 100%;
      max-height: 40vh;
      object-fit: contain;
      background-color: var(--color-surface);
    }

    #file-attachment {
      display: none;
      margin: var(--space-sm);
      font-size: var(--font-size-md);
    }

    #file-attachment a {
      color: var(--color-accent-text);
    }

    #file-attachment a:hover {
      text-decoration: underline;
    }

    .attachments {
      display: none;
    }

    #text-attachment {
      display: none;
      border: 0;
      width: 100%;
      flex: 1;
      min-height: 30vh;
      background-color: var(--color-surface);
    }

    .list-item {
      color: var(--color-text-primary);
    }

    .list-item.list-item-failed {
      color: var(--status-failed);
    }

    /* After `.list-item:hover`, and matching its specificity, so hovering the
       selected row leaves it selected rather than tinting it. */
    .list-item.selected {
      background-color: var(--color-accent);
      color: var(--color-on-accent);
    }

    /* Summary header (#439, redesign A1).

       Everything from here to the media query is the header's own. A1 landed
       it without restyling anything else; A2 has since restyled the tree, in
       the block above, and the filter pills are still A3's. So a rule about a
       row or a pill belongs where that thing is styled, not here — this block
       stays the header's or it stops being findable.

       The band is a flex item of #content, capped at half the viewport so a
       run with a long failure digest can never push the tree off the screen —
       the digest scrolls inside itself rather than growing without bound. */
    #run-summary {
      background-color: var(--color-bg-summary);
      border-bottom: 1px solid var(--color-border-strong);
      padding: var(--space-sm) var(--space-sm) 12px;
      max-height: 50vh;
      overflow-y: auto;
    }

    /* The band belongs to the test run, so the Logs tab gets the column to
       itself (#439, A2). `display: none` rather than a height animation: the
       band is up to half the viewport and the log is an iframe, so anything
       that resized it over several frames would reflow and repaint the frame
       the whole way down. One class, one reflow, no jank. The rule sits with
       the band's own styles and applies at every width — below 700px, where
       the band already yields to a 40vh cap, reclaiming all of it is the
       difference between a readable log and four lines of one. */
    body.logs-active #run-summary {
      display: none;
    }

    .summary-card {
      background-color: var(--color-summary-card);
      border: 1px solid var(--color-summary-border);
      border-radius: 10px;
      /* So the striped digest rows are clipped by the rounded corner rather
         than squaring it off. */
      overflow: hidden;
    }

    .summary-card + .summary-card {
      margin-top: var(--space-sm);
    }

    .summary-card > h2 {
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 0;
      padding: 8px 12px;
      border-bottom: 1px solid var(--color-summary-border);
      font-size: var(--font-size-md);
      font-weight: var(--font-weight-medium);
    }

    .summary-meta {
      margin-left: auto;
      color: var(--color-text-muted);
      font-size: var(--font-size-sm);
      font-weight: var(--font-weight-regular);
    }

    .summary-grid {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 20px;
      padding: 12px;
    }

    /* One class per status drives all three readings of it — the ring's arc,
       the bar's segment and the legend's swatch — by setting `color` and
       letting `currentColor` do the rest. A stroke, a fill and a background
       from one declaration, which is also why the dark block has to override
       nothing here. */
    .status-tint-succeeded { color: var(--status-passed); }
    .status-tint-failed { color: var(--status-failed); }
    .status-tint-skipped { color: var(--status-skipped); }
    .status-tint-mixed { color: var(--status-mixed); }
    .status-tint-unknown { color: var(--status-unknown); }
    .status-tint-expected-failure { color: var(--status-expected); }

    /* The ring and its label share one grid cell, which centres the label
       without positioning it. */
    .donut {
      display: grid;
      place-items: center;
      flex: none;
      width: 108px;
      height: 108px;
    }

    .donut > * {
      grid-area: 1 / 1;
    }

    .donut-ring {
      width: 108px;
      height: 108px;
    }

    .donut-track {
      fill: none;
      stroke: var(--color-donut-track);
      stroke-width: 12;
    }

    .donut-seg {
      fill: none;
      stroke: currentColor;
      stroke-width: 12;
    }

    .donut-center {
      text-align: center;
      line-height: 1.15;
    }

    .donut-center strong {
      display: block;
      font-size: var(--font-size-title);
      font-weight: var(--font-weight-medium);
    }

    .donut-center small {
      display: block;
      font-size: var(--font-size-xs);
      color: var(--color-text-muted);
    }

    .summary-legend {
      flex: 0 1 auto;
      min-width: 170px;
      font-size: var(--font-size-sm);
    }

    .summary-legend li {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 2px 0;
    }

    .legend-swatch {
      width: var(--icon-size-sm);
      height: var(--icon-size-sm);
      border-radius: var(--radius-sm);
      background-color: currentColor;
      flex: none;
    }

    .legend-count {
      margin-left: auto;
      color: var(--color-text-secondary);
      font-variant-numeric: tabular-nums;
    }

    /* The per-device reading A1 put in the summary band's third column. A3a
       moves the rows themselves into the picker — see `.device-option` — and
       what stays here is how one row is drawn, because that is unchanged: a
       destination, a proportional bar, and the same split stated in words.
       The classes are the ones A1 minted, so `RunSummaryTests`' assertions
       about a row's name and its spoken tally still describe the same thing
       in the same words; only the ancestor moved. */
    .device-row-name {
      display: block;
      font-size: var(--font-size-sm);
      overflow-wrap: anywhere;
    }

    .device-row-os,
    .device-row-run {
      color: var(--color-text-muted);
    }

    /* Only rendered when a report holds several runs, because that is the only
       time two options can carry the same destination — see
       `RunSummary.DeviceRow.ordinal`. */
    .device-row-run {
      font-size: var(--font-size-xs);
    }

    /* An SVG rather than nested divs so no width lands in a `style`
       attribute: the segments are `<rect>`s in a 0-100 user space, which is
       the same arithmetic the ring's dash lengths use. `border-radius` on the
       element clips them, and the track shows through wherever a run produced
       no tests at all. */
    .segbar {
      display: block;
      width: 100%;
      height: 8px;
      margin: var(--space-xs) 0 2px;
      border-radius: var(--radius-sm);
      overflow: hidden;
      background-color: var(--color-donut-track);
    }

    .segbar rect {
      fill: currentColor;
    }

    .failure-digest {
      font-size: var(--font-size-sm);
      max-height: 168px;
      overflow-y: auto;
    }

    .failure-digest li {
      display: grid;
      grid-template-columns: auto 1fr auto;
      gap: 8px;
      align-items: baseline;
      padding: 6px 12px;
    }

    .failure-digest li:nth-child(even) {
      background-color: var(--color-summary-card-alt);
    }

    .failure-digest .icon {
      margin: 0;
      align-self: center;
    }

    .digest-body {
      min-width: 0;
    }

    /* A real <button>, so the digest is reachable and operable from the
       keyboard, wearing a link's clothes. */
    .digest-jump {
      display: block;
      padding: 0;
      border: 0;
      background: none;
      font: inherit;
      font-weight: var(--font-weight-medium);
      color: var(--color-accent-text);
      text-align: left;
      cursor: pointer;
      overflow-wrap: anywhere;
    }

    .digest-jump:hover {
      text-decoration: underline;
    }

    .digest-jump:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: 2px;
      border-radius: var(--radius-sm);
    }

    .digest-message {
      display: block;
      color: var(--color-text-muted);
      overflow-wrap: anywhere;
    }

    .digest-suite {
      color: var(--color-text-muted);
      white-space: nowrap;
    }

    /* Narrow screens (#439).

       Everything above this point is one layout, not two, which is A3a's
       biggest change to this query rather than a change *in* it. The
       three-pane shell is gone: there is no device sidebar to fold into a
       horizontal strip, no attachment pane to convert into a bottom sheet
       (the sheet is now the treatment at every width), and no resizers to
       hide. What that query had to *restructure*, it no longer has to, so
       what is left below is spacing, indentation and two caps.

       700px stays the breakpoint even though nothing structural happens at it
       any more, because what does happen is still real: below it the header's
       two rows and the summary band together outweigh the content, and the
       tree's 16px indentation step outruns the width. The three rules that
       used to carry `!important` to beat a dragged pixel width are gone with
       the drag.

       What a reader loses at 375px, stated plainly: the picker's summary
       truncates to the destination name, the digest's suite column drops
       under the message, and the ring shrinks. Nothing becomes unreachable —
       which was not true before A3a, when the device strip and the tree
       competed for the same column. */
    @media (max-width: 700px) {
      /* A flex item's automatic minimum size is its *content's* minimum, and
         the tree holds rows that do not break — assertion messages, exported
         filenames. In a column that minimum became the column's width, which
         pushed the whole tree, and the filter pills with it, off the side of a
         375px screen.

         `min-height` for the same reason on the other axis, and it fixes a
         worse bug: the views are columns, so the tree is sized on the block
         axis by this same automatic minimum, and `min-height: auto` let
         `.tests` grow to the full height of every row it holds instead of
         scrolling inside its share. `body` has `overflow: hidden`, so
         everything past the first viewport was not merely unscrolled but
         unreachable — on a long run the last test in the report could not be
         brought on screen at all. Only the scroll container itself strictly
         needs it, but the automatic minimum propagates up a flex chain, so
         every level does.

         Pre-existing — the column layout arrived with the narrow-screen work
         in #459 — and made materially worse by A1: the summary band spends
         real height above the tree, so the clipped region grew by exactly
         what the band occupies. `visual/tests/behaviour.spec.ts` scrolls to
         the last row at 375 so it cannot come back. A3a keeps the rule and
         extends it to the new levels: `#main-content` and the views are
         columns at *every* width now, so the chain is longer, not shorter. */
      #main-content,
      .view,
      .run-view,
      .tests {
        min-width: 0;
        min-height: 0;
      }

      /* Clipped, not `display: none`. The summary's accessible name is its
         own text — no `aria-label`, because one would replace the destination
         with the word "Device" and the destination is the whole point — so
         removing the label outright would make the control announce as a bare
         device name at exactly the width where there is least context around
         it. This frees the 44px and keeps the reading. */
      .picker-label {
        position: absolute;
        width: 1px;
        height: 1px;
        overflow: hidden;
        clip-path: inset(50%);
        white-space: nowrap;
      }

      .device-picker > summary {
        max-width: 58vw;
      }

      /* Anchored to the header rather than to the control, so a panel wider
         than the summary cannot hang off the right edge of a 375px screen. */
      .picker-panel {
        position: fixed;
        left: var(--space-xs);
        right: var(--space-xs);
        top: auto;
        width: auto;
        max-height: 50vh;
      }

      #report-issue {
        display: none;
      }

      /* The flex row already spends only what it draws, so there is no fixed
         gutter left to reclaim here. What is left is the indentation step:
         16px per level is right at 1440px and profligate on a 375px screen
         four levels deep, where the legacy backend's two wrapper levels alone
         would eat 32px before the first suite. */
      .test-summary-group > .test-summary,
      .test-summary-group > .test-summary-group {
        padding-left: 10px;
      }

      .activities {
        margin-left: 10px;
      }

      /* Long identifiers still have to break somewhere rather than push the
         duration column off the screen. */
      .row-name {
        overflow-wrap: break-word;
      }

      /* 40vh, not the desktop 50: the sheet and the tree share one column, so
         a half-viewport sheet on an 812px phone leaves the tree with fewer
         rows than the sheet has pixels. */
      .attachment-sheet {
        max-height: 40vh;
      }

      .displayed-screenshot,
      .displayed-gif,
      .displayed-video {
        max-height: 30vh;
      }

      #text-attachment {
        min-height: 25vh;
      }

      /* Summary header, narrow (#439, A1). The two columns of the summary
         grid stack on their own — `flex-wrap` already does that — so this only
         tightens the spacing and shrinks the ring, which at 108px would
         otherwise eat a third of a 375px row. */
      /* 40vh, not the desktop 50: the title band and the view tabs are a fixed
         cost, and on an 812px phone a half-viewport band left the tree with
         less than the summary above it. */
      #run-summary {
        padding: 6px;
        max-height: 40vh;
      }

      .summary-grid {
        gap: 12px;
        padding: var(--space-sm);
      }

      .donut,
      .donut-ring {
        width: 84px;
        height: 84px;
      }

      .summary-legend {
        min-width: 140px;
      }

      /* The suite drops under the message rather than off the page: it is the
         column the mockup deletes at this width, but it is also the only
         thing telling two same-named tests apart. */
      .failure-digest li {
        grid-template-columns: auto 1fr;
      }

      .failure-digest .digest-suite {
        grid-column: 2;
        white-space: normal;
      }

      /* One scroller, not two. On a phone the band's own cap is always the
         binding one, so a second scroll region nested inside it would only
         ever swallow the gesture that was meant for the band. */
      .failure-digest {
        max-height: none;
        overflow-y: visible;
      }
    }

    </style>
  </head>

  <body>
    <div id=\"content\">
      <header>
        <div id=\"title\">
          <span class=\"icon big [[RESULT_CLASS]]\"></span>
          <h1>XCTestHTMLReport</h1>
          [[DEVICE_PICKER]]
        </div>
        [[RUN_SUMMARY]]
        <div class=\"view-tabs\" role=\"tablist\" aria-label=\"Report views\">
          <button type=\"button\" role=\"tab\" class=\"view-tab\" id=\"tab-tests\" aria-controls=\"view-tests\" aria-selected=\"true\" tabindex=\"0\">Tests</button>
          <button type=\"button\" role=\"tab\" class=\"view-tab\" id=\"tab-logs\" aria-controls=\"view-logs\" aria-selected=\"false\" tabindex=\"-1\">Logs</button>
        </div>
      </header>

      <main id=\"main-content\">
        <section class=\"view active\" id=\"view-tests\" role=\"tabpanel\" aria-labelledby=\"tab-tests\">
          [[TESTS_VIEWS]]

          <aside class=\"attachment-sheet\" id=\"attachment-sheet\" aria-labelledby=\"attachment-sheet-title\">
            <div class=\"attachment-sheet-head\">
              <h2 id=\"attachment-sheet-title\">Attachment</h2>
              <button type=\"button\" class=\"attachment-close\" id=\"attachment-close\">Close</button>
            </div>
            <div class=\"attachment-sheet-body\">
              <img src=\"\" class=\"displayed-screenshot\" id=\"screenshot\" alt=\"\" loading=\"lazy\"/>
              <img src=\"\" class=\"displayed-gif\" id=\"gif\" alt=\"\" loading=\"lazy\"/>
              <video class=\"displayed-video\" controls src=\"\" id=\"video\" preload=\"none\"></video>
              <iframe id=\"text-attachment\" src=\"\" title=\"Selected attachment\" loading=\"lazy\"></iframe>
              <p id=\"file-attachment\"><a target=\"_blank\" rel=\"noopener\"></a></p>
            </div>
          </aside>
        </section>

        <section class=\"view\" id=\"view-logs\" role=\"tabpanel\" aria-labelledby=\"tab-logs\">
          [[LOGS_VIEWS]]
        </section>
      </main>

      <footer id=\"report-issue\"><a href=\"https://github.com/TitouanVanBelle/XCTestHTMLReport/blob/master/CONTRIBUTING.md#reporting-issues\">Report an issue</a></footer>
    </div>

    <script type=\"text/javascript\">
    // ---- A3a (#439): the per-view shell -------------------------------
    //
    // What this replaces: one script that knew about a device sidebar, two
    // resizable panes and a pair of `<li>` tabs, all of which are gone. What
    // survives unchanged is the part nothing asked to change — the five status
    // filters, the tree's disclosure toggling, and the digest jump — because
    // A3b upgrades the filters and breaking them here would spend that PR's
    // budget on repairs.
    //
    // Three groups of state, and each has exactly one writer:
    //
    //   * which view is showing        -> showView()
    //   * which run is showing         -> selectDevice()
    //   * which row and attachment     -> selectListItem() / openAttachment()
    //
    // Everything else reads them.

    var screenshot = document.getElementById('screenshot'),
        video = document.getElementById('video'),
        gif = document.getElementById('gif'),
        iframe = document.getElementById('text-attachment'),
        fileAttachment = document.getElementById('file-attachment'),
        attachmentTitle = document.getElementById('attachment-sheet-title');

    // The tests tree of whichever run is active. Every filter, every scroll
    // and every jump is scoped through this rather than through the document,
    // because a merged report holds one tree per destination and only one of
    // them is on screen.
    function activeTestsView() {
      return document.querySelector('#view-tests .run-view.active');
    }

    function activeTree() {
      var view = activeTestsView();
      return view ? view.querySelector('.tests') : null;
    }

    function inActiveTests(selector) {
      var view = activeTestsView();
      return view ? view.querySelectorAll(selector) : [];
    }

    // ---- Roving focus --------------------------------------------------
    //
    // Shared by the view tabs and the status filters, which are the two
    // composite widgets A3a introduces. Both are "one of these is chosen":
    // ARIA gives such a group a single tab stop and moves between its members
    // with the arrow keys, so Tab still steps *past* the whole toolbar in one
    // press instead of through five pills.
    //
    // Keyboard only. Clicks are already wired — the tabs bind `showView`
    // below, the pills carry the filter call the report has always used — and
    // an `activate` that reached for `.click()` from a listener bound on the
    // same element would call itself forever.
    function rovingGroup(container, itemSelector, activate) {
      if (!container) {
        return;
      }
      var items = Array.prototype.slice.call(container.querySelectorAll(itemSelector));

      function focusItem(index) {
        var wrapped = (index + items.length) % items.length;
        items[wrapped].focus();
        activate(items[wrapped]);
      }

      container.addEventListener('keydown', function (e) {
        var index = items.indexOf(e.target);
        if (index < 0) {
          return;
        }
        if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
          e.preventDefault();
          focusItem(index + 1);
        } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
          e.preventDefault();
          focusItem(index - 1);
        } else if (e.key === 'Home') {
          e.preventDefault();
          focusItem(0);
        } else if (e.key === 'End') {
          e.preventDefault();
          focusItem(items.length - 1);
        }
      });
    }

    // Which member of a roving group carries the page's single tab stop.
    function setRovingTabStop(items, current) {
      for (var i = 0; i < items.length; i++) {
        items[i].tabIndex = items[i] === current ? 0 : -1;
      }
    }

    // ---- Views ---------------------------------------------------------

    var viewTabs = Array.prototype.slice.call(document.querySelectorAll('[role=\"tab\"]'));

    // A body class rather than a style written onto #run-summary, so the
    // band's own rules — including its two max-heights — stay in the
    // stylesheet. The band describes the *test* run; the log it does not
    // describe gets the column to itself, which is what Xcode does when you
    // switch reports.
    function showView(tab) {
      var panel = document.getElementById(tab.getAttribute('aria-controls'));
      if (!panel) {
        return;
      }

      // Focus that is inside the panel about to be hidden would otherwise be
      // stranded on a `display: none` element: the browser drops it to
      // <body>, and a keyboard reader loses their place entirely. Moving it
      // to the tab that caused the switch is both recoverable and where the
      // reader already is.
      var active = document.activeElement;
      var leaving = document.querySelector('.view.active');
      if (leaving && leaving !== panel && active && leaving.contains(active)) {
        tab.focus();
      }

      for (var i = 0; i < viewTabs.length; i++) {
        var each = viewTabs[i];
        var eachPanel = document.getElementById(each.getAttribute('aria-controls'));
        var selected = each === tab;
        each.setAttribute('aria-selected', selected ? 'true' : 'false');
        if (eachPanel) {
          eachPanel.classList.toggle('active', selected);
        }
      }
      setRovingTabStop(viewTabs, tab);
      document.body.classList.toggle('logs-active', panel.id === 'view-logs');
    }

    rovingGroup(document.querySelector('[role=\"tablist\"]'), '[role=\"tab\"]', showView);
    for (var t = 0; t < viewTabs.length; t++) {
      viewTabs[t].addEventListener('click', function (e) {
        showView(e.currentTarget);
      }, false);
    }

    // ---- Devices -------------------------------------------------------
    //
    // The picker is the sidebar's whole job in one control: it lists every
    // run, states each one's outcome, and activates the pair of per-view
    // slices — the tests tree and the log — that belong to one destination.
    // Both slices are switched together, so the Logs tab is never showing one
    // destination's log while the Tests tab holds another's tree.
    var devicePicker = document.getElementById('device-picker'),
        deviceOptions = Array.prototype.slice.call(
          document.querySelectorAll('.device-option')
        ),
        pickerCurrent = document.getElementById('device-picker-current');

    function selectDevice(deviceId, el) {
      for (var i = 0; i < deviceOptions.length; i++) {
        deviceOptions[i].setAttribute(
          'aria-current', deviceOptions[i] === el ? 'true' : 'false'
        );
      }

      var previous = document.querySelectorAll('.run-view.active');
      for (var p = 0; p < previous.length; p++) {
        previous[p].classList.remove('active');
      }

      var tests = document.getElementById('tests_' + deviceId),
          logs = document.getElementById('logs_' + deviceId);
      if (tests) {
        tests.classList.add('active');
      }
      if (logs) {
        logs.classList.add('active');
      }

      // The selection belonged to the run that just left the layout, and a
      // `display: none` row cannot be scrolled to or read out.
      selectedListItem = null;
      closeAttachment();

      if (pickerCurrent && el) {
        var label = el.querySelector('.device-row-name');
        if (label) {
          // textContent, never innerHTML: the destination name is
          // test-plan-controlled text and this is the one place a script
          // moves it between elements.
          pickerCurrent.textContent = label.textContent.trim();
        }
      }
      if (devicePicker) {
        devicePicker.open = false;
      }
    }

    if (devicePicker) {
      // `<details>` has no Escape handling of its own, and a panel that
      // covers the header is exactly the kind that needs one.
      devicePicker.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && devicePicker.open) {
          devicePicker.open = false;
          devicePicker.querySelector('summary').focus();
        }
      });
      document.addEventListener('click', function (e) {
        if (devicePicker.open && !devicePicker.contains(e.target)) {
          devicePicker.open = false;
        }
      }, false);
    }

    // ---- Rows ----------------------------------------------------------

    var listItems = document.querySelectorAll('.list-item');

    function visibleListItems() {
      var array = Array.prototype.slice.call(listItems);
      return array.filter(function(el) { return el.offsetParent != null; })
    }

    var selectedListItem;
    for (var i = 0; i < listItems.length; i++) {
      listItems[i].addEventListener('mousedown', listItemMouseDown, false);
    }

    function listItemMouseDown(e) {
      var item = e.target;
      while (item && !item.classList.contains('list-item')) {
        item = item.parentElement;
      }

      selectListItem(item);

      // So the arrow keys carry on from the row just clicked. The tree is the
      // focusable scroll region (#439, A2) and clicking inside it used to
      // leave focus on <body>, which is why the key handler had to be on the
      // document at all. `preventScroll`, because the row is already where
      // the reader put it.
      var tree = activeTree();
      if (tree) {
        tree.focus({ preventScroll: true });
      }
    }

    function selectListItem(listItem) {
      if (selectedListItem) {
        selectedListItem.classList.remove(\"selected\");
      }

      selectedListItem = listItem;
      selectedListItem.classList.add(\"selected\");

      // A test row summons the sheet for the first attachment it holds; a row
      // with none dismisses it. That is what makes the sheet on-demand rather
      // than permanent: there is no placeholder state, because a sheet showing
      // nothing is simply not in the layout.
      var firstAttachment = selectedListItem.querySelector('.attachment .preview-button');
      if (firstAttachment == null) {
        closeAttachment();
        return;
      }
      openAttachment(firstAttachment);
    }

    // ---- The attachment sheet ------------------------------------------
    //
    // One entry point, taking the element that names the attachment rather
    // than a path. Two things follow. The kind comes from `data-kind`, written
    // by the template that knows it, instead of being sniffed off the end of a
    // URL — which is what `data:` URIs defeated, and what made a `.png` taken
    // from a row selection fall through to the download branch (the extension
    // list was tested with `indexOf(...) > 0`, and \"png\" is at index 0). And
    // the sheet can be titled with the attachment's own name, read out of the
    // row as text, so the pane says what is in it.
    function openAttachment(icon) {
      var kind = icon.getAttribute('data-kind'),
          path = icon.getAttribute('data');

      hideAttachmentMedia();

      if (kind === 'text') {
        iframe.style.display = 'block';
        iframe.src = path;
      } else if (kind === 'video') {
        var vid = document.getElementById('video-' + path);
        video.style.display = 'block';
        video.src = vid.src;
        video.play();
      } else if (kind === 'screenshot') {
        var image = document.getElementById('screenshot-' + path);
        screenshot.style.display = 'block';
        screenshot.src = image.src;
        screenshot.alt = image.alt;
      } else if (kind === 'gif') {
        var gf = document.getElementById('gif-' + path);
        gif.style.display = 'block';
        gif.src = gf.src;
        gif.alt = gf.alt;
      } else {
        var target = document.getElementById('file-attachment-' + path);
        var link = fileAttachment.querySelector('a');
        var name = attachmentNameOf(icon);
        link.textContent = 'Download ' + (name || 'attachment');
        link.href = target.href;
        fileAttachment.style.display = 'block';
      }

      attachmentTitle.textContent = attachmentNameOf(icon) || 'Attachment';
      document.body.classList.add('attachment-open');
    }

    /// The display name the tree already renders for this attachment. Read as
    /// text and written as text, so a hostile file name cannot become markup
    /// on the way between two elements of the same page.
    function attachmentNameOf(icon) {
      var row = icon.closest('.attachment');
      var name = row ? row.querySelector('.row-name') : null;
      return name ? name.textContent.trim() : '';
    }

    // Pausing belongs here rather than in `closeAttachment`, because the sheet
    // is reused: opening a screenshot while a recording is playing hides the
    // player and, without this, leaves it playing behind the image. The old
    // pane had the same hole and no way to notice it — it never closed, so
    // nothing ever stopped.
    function hideAttachmentMedia() {
      screenshot.style.display = 'none';
      gif.style.display = 'none';
      video.style.display = 'none';
      iframe.style.display = 'none';
      fileAttachment.style.display = 'none';
      if (!video.paused) {
        video.pause();
      }
    }

    function closeAttachment() {
      hideAttachmentMedia();
      document.body.classList.remove('attachment-open');
    }

    document.getElementById('attachment-close')
      .addEventListener('click', function () {
        closeAttachment();
        var tree = activeTree();
        if (tree) {
          tree.focus({ preventScroll: true });
        }
      }, false);

    // ---- Tree keyboard navigation --------------------------------------

    function keyDown(e) {
        e = e || window.event;

        // The toolbars, the picker and the tabs are roving groups: the arrow
        // keys belong to whichever one has focus, not to the tree. Before A3a
        // no control in the page could take focus at all, so a document-level
        // handler could not collide with anything; now it can, and the tree
        // only claims the keys while it is the thing being read.
        var tree = activeTree();
        if (!tree) {
          return;
        }
        var focused = document.activeElement;
        if (focused && focused !== document.body && !tree.contains(focused)
            && focused !== tree) {
          return;
        }

        var items = visibleListItems();
        if (e.keyCode == 40) {
          e.preventDefault();
          var index = Array.prototype.slice.call(visibleListItems()).indexOf(selectedListItem) + 1;
          navigateListItems(items.slice(index, items.length));
        } else if (e.keyCode == 38) {
          e.preventDefault();
          var index = Array.prototype.slice.call(visibleListItems()).indexOf(selectedListItem) + 1;
          navigateListItems(items.slice(0, index - 1).reverse());
        } else if (e.keyCode == 39) {
          unfoldCurrentListItem();
        } else if (e.keyCode == 37) {
          foldCurrentListItem();
        }
    }

    function foldCurrentListItem() {
      if (!selectedListItem) {
        return;
      }
      var dropIcon = selectedListItem.querySelector('.drop-down-icon');
      if (dropIcon == null) {
        return;
      }

      if (dropIcon.classList.contains(\"dropped\")) {
        selectedListItem.querySelector('.drop-down-icon').onclick();
      }
    }

    function unfoldCurrentListItem() {
      if (!selectedListItem) {
        return;
      }
      var dropIcon = selectedListItem.querySelector('.drop-down-icon');
      if (dropIcon == null) {
        return;
      }

      if (!dropIcon.classList.contains(\"dropped\")) {
        selectedListItem.querySelector('.drop-down-icon').onclick();
      }
    }

    function navigateListItems(items) {
      if (selectedListItem) {
        for (var i = 0; i < items.length; i++) {
          var item = items[i];
          if (item.offsetParent) {
            selectListItem(item);

            var scrollView = activeTree();
            if (scrollView && !divInsideOfDiv(item, scrollView)) {
              scrollToItem(item);
            }

            return;
          }
        }
      } else if (items.length) {
        selectListItem(items[0]);
      }
    }

    function scrollToItem(item) {
      var scrollView = activeTree(),
          itemBounds = item.getBoundingClientRect(),
          scrollBounds = scrollView.getBoundingClientRect();

      if (itemBounds.bottom > scrollBounds.bottom) {
        scrollView.scrollBy(0, itemBounds.bottom - scrollBounds.bottom);
      } else if (itemBounds.top < scrollBounds.top) {
        scrollView.scrollBy(0, itemBounds.top - scrollBounds.top);
      }
    }

    function divInsideOfDiv(divA, divB) {
      var boundariesA = divA.getBoundingClientRect();
      var boundariesB = divB.getBoundingClientRect();

      return boundariesA.top >= boundariesB.top &&
       boundariesA.bottom <= boundariesB.bottom;
    }

    document.onkeydown = keyDown;

    // ---- Disclosure ----------------------------------------------------

    function toggle(el, id) {
      el.classList.toggle('dropped');
      var iterations = document.getElementById('iterations-'+id);
      var activities = document.getElementById('activities-'+id);
      var attachments = document.getElementById('attachments-'+id);
  
      if (iterations) {
        iterations.style.display = (iterations.style.display == 'block' ? 'none' : 'block');
      }
  
      if (activities) {
        activities.style.display = (activities.style.display == 'block' ? 'none' : 'block');
      }

      if (attachments) {
        attachments.style.display = (attachments.style.display == 'block' ? 'none' : 'block');
      }
    }

    function toggleVideo(el, id) {
      el.classList.toggle('dropped');
      var video = document.getElementById('test-video-'+id);

      if (video) {
        video.style.display = (video.style.display == 'block' ? 'none' : 'block');
      }
    }

    // ---- Status filters ------------------------------------------------
    //
    // The five functions A3b upgrades, unchanged in what they do. What
    // changed is only what they are scoped to: `.run.active` named the shell's
    // per-run pane, which the per-view split replaced with one slice per view.
    // Everything downstream of the scope — which classes are shown, which are
    // hidden, and the group-collapsing pass — is the same code it was.

    function setDisplayToElementsWithSelector(sel, display) {
      [].forEach.call(inActiveTests(sel), function (el) {
        el.style.display = display;
      });
    }

    function hideElementsWithSelector(sel) {
      setDisplayToElementsWithSelector(sel, 'none');
    }

    function showElementsWithSelector(sel) {
      setDisplayToElementsWithSelector(sel, 'block');
    }

    // The chosen filter, as an ARIA fact rather than a class: these are
    // mutually exclusive, so the group is a radiogroup and `aria-checked`
    // is the state a screen reader reads out.
    function selectedElement(el) {
      var group = el.closest('[role=\"radiogroup\"]');
      var pills = Array.prototype.slice.call(group.querySelectorAll('[role=\"radio\"]'));
      for (var i = 0; i < pills.length; i++) {
        pills[i].setAttribute('aria-checked', pills[i] === el ? 'true' : 'false');
      }
      setRovingTabStop(pills, el);
    }

    function showAllScenarios(el) {
      selectedElement(el);
      showElementsWithSelector('.test-summary.succeeded');
      showElementsWithSelector('.test-summary.skipped');
      showElementsWithSelector('.test-summary.failed');
      showElementsWithSelector('.test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function showSuccessfulScenariosOnly(el) {
      selectedElement(el);
      showElementsWithSelector('.test-summary.succeeded');
      hideElementsWithSelector('.test-summary.skipped');
      hideElementsWithSelector('.test-summary.failed');
      hideElementsWithSelector('.test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function showSkippedScenariosOnly(el) {
      selectedElement(el);
      hideElementsWithSelector('.test-summary.succeeded');
      showElementsWithSelector('.test-summary.skipped');
      hideElementsWithSelector('.test-summary.failed');
      hideElementsWithSelector('.test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function showFailedScenariosOnly(el) {
      selectedElement(el);
      hideElementsWithSelector('.test-summary.succeeded');
      hideElementsWithSelector('.test-summary.skipped');
      showElementsWithSelector('.test-summary.failed');
      hideElementsWithSelector('.test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }
  
    function showMixedScenariosOnly(el) {
      selectedElement(el);
      hideElementsWithSelector('.test-summary.succeeded');
      hideElementsWithSelector('.test-summary.skipped');
      hideElementsWithSelector('.test-summary.failed');
      showElementsWithSelector('.test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function hideSummaryGroupsIfNeeded() {
      var testSummaryGroups = Array.prototype.slice.call(
        inActiveTests('.test-summary-group')
      );
      for (var i = 0; i < testSummaryGroups.length; i++) {
          var testSummaryGroup = testSummaryGroups[i];
          var children = Array.prototype.slice.call(testSummaryGroup.children);
          var testSummaryChildren = children.filter(function(a) { return a.classList.contains('test-summary'); });
          var testSummaryGroupChildren = children.filter(function(a) { return a.classList.contains('test-summary-group'); });
          if (testSummaryChildren == 0 || testSummaryGroupChildren.length > 0) {
            continue;
          }

          if (testSummaryChildren.filter(function(a) { return a.style.display == 'block' }).length == 0) {
            testSummaryGroup.style.display = 'none';
          } else {
            testSummaryGroup.style.display = 'block';
          }
      }
    }

    // Arrow keys inside a radiogroup both move focus and choose, which is the
    // behaviour a native radio group has. The pill's own `onclick` is the one
    // definition of what choosing does, so the handler dispatches to it rather
    // than restating the mapping from pill to filter.
    var filterGroups = document.querySelectorAll('.filter-pills');
    for (var f = 0; f < filterGroups.length; f++) {
      rovingGroup(filterGroups[f], '[role=\"radio\"]', function (pill) {
        pill.onclick();
      });
    }

    // ---- Boot ----------------------------------------------------------
    //
    // The first destination is the one the report opens on, which is the same
    // rule the sidebar's first card followed.
    if (deviceOptions.length) {
      selectDevice(
        deviceOptions[0].getAttribute('data-device'), deviceOptions[0]
      );
    }

    // Failure digest (#439, A1). Each row's button carries the failing test's
    // element id in `data-target`; nothing about the test reaches a script
    // context, which is the shape #463 left behind.
    //
    // The digest lists every run's failures, but only one run is in the
    // layout at a time, so a jump has four things to undo before the row is
    // on screen: the Logs tab, a non-active run, a filter that hid the row,
    // and the collapsed disclosure it sits behind.
    var digestButtons = document.querySelectorAll('.digest-jump');
    for (var d = 0; d < digestButtons.length; d++) {
      digestButtons[d].addEventListener('click', digestJump, false);
    }

    function digestJump(e) {
      var uuid = e.currentTarget.getAttribute('data-target'),
          // A test with one iteration hangs its rows off `activities-`; a
          // retried one off `iterations-`. Both ids come from the same uuid,
          // and the outer row is the nearest .test-summary either way.
          disclosure = document.getElementById('activities-' + uuid)
                    || document.getElementById('iterations-' + uuid);
      if (!disclosure) {
        return;
      }

      var row = disclosure.closest('.test-summary');
      if (!row) {
        return;
      }

      var testsTab = document.getElementById('tab-tests');
      if (testsTab && testsTab.getAttribute('aria-selected') !== 'true') {
        showView(testsTab);
      }

      activateRunContaining(row);

      // The filter writes `display: none` onto the element itself, and its
      // group as well. Clearing both un-hides this one row without resetting
      // the filter the reader chose.
      row.style.display = 'block';
      var group = row.closest('.test-summary-group');
      if (group) {
        group.style.display = 'block';
      }

      disclosure.style.display = 'block';
      var chevron = row.querySelector('.drop-down-icon');
      if (chevron) {
        chevron.classList.add('dropped');
      }

      var listItem = row.querySelector('.list-item');
      if (listItem) {
        selectListItem(listItem);
      }
      row.scrollIntoView({ block: 'start' });
    }

    // Going through selectDevice rather than toggling the classes here keeps
    // one definition of what \"active\" means — including switching the log
    // slice to match, which a jump into another destination's tree would
    // otherwise leave pointing at the destination the reader just left.
    function activateRunContaining(el) {
      var view = el.closest('.run-view');
      if (!view || view.classList.contains('active')) {
        return;
      }
      var deviceId = view.id.replace('tests_', '');
      var option = document.querySelector(
        '.device-option[data-device=\"' + deviceId + '\"]'
      );
      if (option) {
        selectDevice(deviceId, option);
      }
    }

    </script>
  </body>
  </html>
  """

  /// The summary header (#439, A1). Rendered whole by `RunSummary` and
  /// substituted into the index as `[[RUN_SUMMARY]]`, so the header's markup
  /// lives beside the templates it is built from rather than inside the
  /// thousand-line index string.
  ///
  /// It sits inside `<header>`, which is already the banner landmark, so the
  /// section needs no landmark of its own to satisfy axe's `region` rule.
  ///
  /// The run duration is written `Duration (5.04s)` — a label, then the value
  /// parenthesised in its own element. The parentheses are not decoration:
  /// `(N.NNs)` is the shape the differential's `durations` known-loss rule
  /// normalises, and this total inherits that loss because a parameterized
  /// Swift Testing case reports a different duration on each backend. Writing
  /// it in any other shape would leave a declared divergence unmasked and turn
  /// the differential red on a slow enough runner. `RunSummaryTests` asserts
  /// against the masker that this actually holds, rather than assuming it.
  static let runSummary = """
  <section id=\"run-summary\" aria-labelledby=\"run-summary-heading\">
        <div class=\"summary-card\">
          <h2 id=\"run-summary-heading\">
            <span class=\"icon [[OVERALL_STATUS_CLASS]]\"></span>
            Tests
            <span class=\"summary-meta\">Duration <span class=\"summary-duration\">([[RUN_DURATION]])</span> &middot; [[DEVICES_LABEL]]</span>
          </h2>
          <div class=\"summary-grid\">
            <div class=\"donut\">
              [[DONUT]]
              <span class=\"donut-center\"><strong>[[N_OF_TESTS]]</strong><small>[[TESTS_LABEL]]</small></span>
            </div>
            <ul class=\"summary-legend\">
              [[LEGEND]]
            </ul>
          </div>
        </div>
        [[FAILURE_DIGEST]]
      </section>
  """

  /// The device picker (#439, A3a) — what the device sidebar and A1's
  /// "Devices & Configurations" card became once they stopped being two
  /// things.
  ///
  /// It sits in the title band, above the summary band rather than inside it,
  /// which is the property that makes the shell work: the band stands down for
  /// the Logs view, and picking a destination is not a thing you stop being
  /// able to do because you are reading a log. Every navigation the sidebar
  /// offered is here — list the runs, read each one's outcome, switch to one —
  /// and two the sidebar could not: the per-device pass/fail split, and a
  /// keyboard.
  ///
  /// `<details>` rather than a scripted popover, so the disclosure is the
  /// browser's own: focusable, operable with Enter and Space, and announced as
  /// expanded or collapsed with nothing bound to it.
  static let devicePicker = """
  <details id=\"device-picker\" class=\"device-picker\">
            <summary>
              <span class=\"picker-label\">Device</span>
              <span class=\"picker-current\" id=\"device-picker-current\">[[CURRENT_DEVICE]]</span>
              <span class=\"picker-chevron\" aria-hidden=\"true\"></span>
            </summary>
            <div class=\"picker-panel\">
              [[DEVICE_OPTIONS]]
            </div>
          </details>
  """

  /// One destination in the picker.
  ///
  /// `data-device` carries the same identifier the `onclick` passes, because
  /// two callers need it without going through a handler: the boot sequence,
  /// which activates the first option, and a digest jump into another
  /// destination's tree. Both are `IdentifierPath` digests — opaque by
  /// construction, which is what `HTMLEscapingTests` pins.
  static let deviceOption = """
  <button type=\"button\" class=\"device-option\" data-device=\"[[DEVICE_IDENTIFIER]]\" aria-current=\"false\" onclick=\"selectDevice('[[DEVICE_IDENTIFIER]]', this);\">
                <span class=\"device-option-head\">
                  <span class=\"icon device-result [[DEVICE_STATUS_CLASS]]\"></span>
                  <span class=\"device-row-name\">[[DEVICE_LABEL]]</span>
                </span>
                <svg class=\"segbar\" viewBox=\"0 0 100 8\" preserveAspectRatio=\"none\" aria-hidden=\"true\" focusable=\"false\">[[SEGMENTS]]</svg>
                <span class=\"device-row-tally\">[[DEVICE_TALLY]]</span>
                <span class=\"device-option-meta\">[[DEVICE_MODEL]]</span>
              </button>
  """

  /// The ring. `aria-hidden` because the legend beside it already states every
  /// count in text; announcing both would read the same run out twice.
  static let summaryDonut = """
  <svg class=\"donut-ring\" viewBox=\"0 0 120 120\" aria-hidden=\"true\" focusable=\"false\">
                <circle class=\"donut-track\" cx=\"60\" cy=\"60\" r=\"48\"></circle>
                [[SEGMENTS]]
              </svg>
  """

  static let summaryDonutSegment = """
  <circle class=\"donut-seg status-tint-[[STATUS_CLASS]]\" cx=\"60\" cy=\"60\" r=\"48\" pathLength=\"100\" stroke-dasharray=\"[[DASH]] [[GAP]]\" stroke-dashoffset=\"[[OFFSET]]\" transform=\"rotate(-90 60 60)\"></circle>
  """

  /// The space before the count is load-bearing for assistive technology and
  /// free for layout: a whitespace-only text node between flex items is not
  /// rendered, but without it the row's text content is \"Passed1\".
  static let summaryLegendRow = """
  <li><span class=\"legend-swatch status-tint-[[STATUS_CLASS]]\"></span>[[LABEL]] <span class=\"legend-count\">[[COUNT]]</span></li>
  """

  static let summaryBarSegment = """
  <rect class=\"status-tint-[[STATUS_CLASS]]\" x=\"[[X]]\" y=\"0\" width=\"[[WIDTH]]\" height=\"8\"></rect>
  """

  /// The failure digest. Omitted entirely when nothing failed.
  static let summaryFailureDigest = """
  <div class=\"summary-card\">
          <h2>Test Failures <span class=\"summary-meta\">[[FAILURES_LABEL]]</span></h2>
          <ul class=\"failure-digest\">
            [[FAILURE_ROWS]]
          </ul>
        </div>
  """

  /// `data-target`, not an interpolated `onclick`: #463 took the last report
  /// datum out of a script context, and the handler is bound from the script
  /// instead. The value is an `IdentifierPath` digest, so it is hex either
  /// way — the point is that nothing that follows this pattern can ever put a
  /// test-author-controlled string into JavaScript.
  static let summaryFailureRow = """
  <li>
              <span class=\"icon failure\"></span>
              <span class=\"digest-body\">
                <button type=\"button\" class=\"digest-jump\" data-target=\"[[UUID]]\">[[TEST_NAME]]</button>
                <span class=\"digest-message\">[[MESSAGE]]</span>
              </span>
              <span class=\"digest-suite\">[[SUITE_NAME]]</span>
            </li>
  """

  /// One destination's tests view (#439, A3a).
  ///
  /// The view owns its whole surface: a toolbar of its own, a column header
  /// that does not scroll away, and the tree. What it no longer shares with
  /// anything is a shell — there is no device pane beside it and no attachment
  /// pane reserved next to it, so at 1440px the tree is the window.
  ///
  /// `tabindex="0"` on the scrolling test list is an accessibility fix, not a
  /// layout one: axe's `scrollable-region-focusable` (serious) requires that a
  /// region a sighted user can scroll is reachable by a keyboard user too, and
  /// a `div` with `overflow-y` and no focusable descendant is not. With the
  /// attribute the list takes focus and Page Up/Down, Home and End scroll it;
  /// the arrow keys keep going to the row navigation, which scrolls the same
  /// region by moving the selection.
  ///
  /// The trailing group in the toolbar is empty on purpose. A3b's text filter
  /// and its dropdowns (#460) land in it, and having the slot already laid out
  /// — right-aligned, in the flex row, with the pills sized against it — is
  /// what makes that an addition rather than a second toolbar redesign.
  static let runTests = """
  <div class=\"run-view\" id=\"tests_[[DEVICE_IDENTIFIER]]\">
      <div class=\"view-toolbar\">
        <div class=\"filter-pills\" role=\"radiogroup\" aria-label=\"Filter tests by status\">
          <button type=\"button\" role=\"radio\" class=\"pill\" aria-checked=\"true\" tabindex=\"0\" onclick=\"showAllScenarios(this);\">All ([[N_OF_TESTS]])</button>
          <button type=\"button\" role=\"radio\" class=\"pill\" aria-checked=\"false\" tabindex=\"-1\" onclick=\"showSuccessfulScenariosOnly(this);\">Passed ([[N_OF_PASSED_TESTS]])</button>
          <button type=\"button\" role=\"radio\" class=\"pill\" aria-checked=\"false\" tabindex=\"-1\" onclick=\"showSkippedScenariosOnly(this);\">Skipped ([[N_OF_SKIPPED_TESTS]])</button>
          <button type=\"button\" role=\"radio\" class=\"pill\" aria-checked=\"false\" tabindex=\"-1\" onclick=\"showFailedScenariosOnly(this);\">Failed ([[N_OF_FAILED_TESTS]])</button>
          <button type=\"button\" role=\"radio\" class=\"pill\" aria-checked=\"false\" tabindex=\"-1\" onclick=\"showMixedScenariosOnly(this);\">Mixed ([[N_OF_MIXED_TESTS]])</button>
        </div>
        <div class=\"view-toolbar-trailing\"></div>
      </div>
      <ul class=\"table-header\">
        <li>Test</li>
        <li>Duration</li>
      </ul>
      <div class=\"tests\" tabindex=\"0\">
        [[TEST_SUMMARIES]]
      </div>
    </div>
  """

  /// One destination's log view (#439, A3a).
  ///
  /// Its own toolbar and its own frame, and — unlike the shell it replaces —
  /// its own element ids. Before A3a every run rendered `id="logs"`,
  /// `id="logs-header"` and `id="logs-iframe"`, so a report built from two
  /// bundles emitted each of them twice; the page only behaved because the
  /// duplicates were hidden inside an inactive run. The ids are per
  /// destination now, which is also what lets the picker switch the log and
  /// the tree together.
  static let runLogs = """
  <div class=\"run-view\" id=\"logs_[[DEVICE_IDENTIFIER]]\">
      <div class=\"view-toolbar\">
        <p class=\"view-toolbar-label\">All Messages</p>
        <div class=\"view-toolbar-trailing\"></div>
      </div>
      <iframe class=\"logs-iframe\" src=\"[[LOG_SOURCE]]\" title=\"Run log\" loading=\"lazy\"></iframe>
    </div>
  """

  static let testSummary = """
  <div class=\"summary\" id=\"[[UUID]]\">
      [[TESTS]]
  </div>
  """
    
  /// A test-case row (#439, A2).
  ///
  /// Three things about this shape are contracts rather than layout, and the
  /// three of them are why the restyle is markup-shallow:
  ///
  /// - The status badge is now a child of the `<p>` instead of a float beside
  ///   it, which is what lets the row be a single flex line. The stylesheet's
  ///   status rules moved from `> .test-result-icon` to `> p >` to match, and
  ///   the direct combinator is still doing the work of keeping a retried
  ///   test's iterations off their parent's glyph.
  /// - `[[TITLE]]` and `([[DURATION]])` are separate elements so the duration
  ///   can be a right-hand column, but the rendered *text* is unchanged:
  ///   whitespace between the two spans keeps `text()` reading
  ///   `name (1.23s)`, which `KnownLossMasker`'s `durations` and
  ///   `wrapperGroups` rules and `CoreTests`' `hasPrefix` lookups all depend
  ///   on. The parentheses are the masked shape; do not drop them.
  /// - `p.list-item > span.drop-down-icon` is pinned by
  ///   `ReproducibilityTests` as the place a test case's identifier is
  ///   findable in the rendered page.
  ///
  /// The blue test tile that used to sit between the triangle and the title is
  /// gone: the status badge beside it already says "this row is a test", the
  /// mockup has no equivalent, and it cost 20px of a 375px row to repeat a
  /// fact. Nothing selects it.
  static let testCase = """
    [[SCREENSHOT_TAIL]]
    <div class=\"[[ITEM_CLASS]] [[ICON_CLASS]]\">
        <p class=\"list-item\">
            <span class=\"icon drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon test-result-icon\"></span>
            <span class=\"row-name\">[[TITLE]]</span>
            <span class=\"row-duration\">([[DURATION]])</span>
        </p>
        <div id=\"activities-[[UUID]]\" class=\"activities\">
            [[SCREENSHOT_FLOW]]
            [[ACTIVITIES]]
        </div>
    </div>
  """

  static let testCaseWithIterations = """
    <div class=\"[[ITEM_CLASS]] [[ICON_CLASS]]\">
        <p class=\"list-item\">
            <span class=\"icon drop-down-icon dropped\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon test-result-icon\"></span>
            <span class=\"row-name\">[[TITLE]]</span>
            <span class=\"row-note\">[[RESULT_STRING]]</span>
            <span class=\"row-duration\">([[DURATION]])</span>
        </p>
        <div id=\"iterations-[[UUID]]\" class=\"iterations\" style=\"display: block\">
            [[ITERATIONS]]
        </div>
    </div>
  """

  /// A suite heading. Its `<p>` carries no `list-item` class — group rows are
  /// not selectable and never have been — and `KnownLossMasker`'s
  /// `wrapperGroups` rule reads this heading's text to recognise the two
  /// wrapper levels only the legacy backend emits, so the `Title (1.23s)`
  /// reading has to survive the split into spans. It does: the newline
  /// between them is a text node.
  static let testGroup = """
    <div class=\"[[ITEM_CLASS]] [[ICON_CLASS]]\">
        <p>
            <span class=\"icon drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon test-result-icon\"></span>
            <span class=\"row-name\">[[TITLE]]</span>
            <span class=\"row-duration\">([[DURATION]])</span>
        </p>
        [[SUB_TESTS]]
    </div>
  """

  static let iteration = """
    <div class=\"iteration [[ICON_CLASS]]\">
        <p class=\"list-item\">
            <span class=\"icon drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon test-result-icon\"></span>
            <span class=\"row-name\">[[TITLE]]</span>
            <span class=\"row-duration\">([[DURATION]])</span>
        </p>
        <div id=\"activities-[[UUID]]\" class=\"activities\">
            [[SCREENSHOT_FLOW]]
            [[ACTIVITIES]]
        </div>
    </div>
  """

  static let activity = """
  <div class=\"activity [[ACTIVITY_TYPE_CLASS]] [[HAS_SUB-ACTIVITIES_CLASS]]\">
    <p class=\"list-item\">
      <span style=\"margin-left: [[PADDING]]px\" class=\"padding\"></span>
      <span class=\"icon drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
      <span class=\"row-name\">[[TITLE]]</span>
      <span class=\"icon paperclip-icon\" style=\"display: [[PAPER_CLIP_CLASS]]\"></span>
    </p>
    <div id=\"attachments-[[UUID]]\" class=\"attachments\">
        [[ATTACHMENTS]]
    </div>
    <div id=\"activities-[[UUID]]\" class=\"sub-activities\">
        [[SUB_ACTIVITY]]
    </div>
  </div>
  """

  /// The attachment rows (#439, A3a).
  ///
  /// One handler for all five kinds, taking the element rather than a path,
  /// and a `data-kind` written by the template that already knows which kind
  /// this is. What that replaces is a script that took the path and guessed
  /// from the characters after the last dot — which cannot work for a `data:`
  /// URI (inline rendering mode's whole output) and did not work for `.png`
  /// either, because the extension list was probed with `indexOf(...) > 0` and
  /// `png` sits at index 0. Clicking the eye always worked; selecting the row
  /// that held it sent a PNG to the download branch.
  ///
  /// `data`, not the handler, still carries the file name, and it is still
  /// escaped on the way in: `HTMLEscapingTests` pins that no `onclick` may
  /// carry attachment-derived text, because XML escaping cannot make a value
  /// safe inside a JavaScript string literal.
  static let screenshot = """
  <p class=\"attachment list-item\">
    <span class=\"icon screenshot-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <button type=\"button\" class=\"preview-button\" aria-label=\"Preview attachment\" data-kind=\"screenshot\" data=\"[[FILENAME]]\" onclick=\"openAttachment(this)\"><span class=\"icon preview-icon\" aria-hidden=\"true\"></span></button>
    <img class=\"screenshot\" src=\"[[SOURCE]]\" id=\"screenshot-[[FILENAME]]\" alt=\"[[NAME]]\" loading=\"lazy\"/>
  </p>
  """

  static let gif = """
  <p class=\"attachment list-item\">
    <span class=\"icon screenshot-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <button type=\"button\" class=\"preview-button\" aria-label=\"Preview attachment\" data-kind=\"gif\" data=\"[[FILENAME]]\" onclick=\"openAttachment(this)\"><span class=\"icon preview-icon\" aria-hidden=\"true\"></span></button>
    <img class=\"gif\" src=\"[[SOURCE]]\" id=\"gif-[[FILENAME]]\" alt=\"[[NAME]]\" loading=\"lazy\"/>
  </p>
  """

  static let video = """
  <p class=\"attachment list-item\">
    <span class=\"icon video-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <button type=\"button\" class=\"preview-button\" aria-label=\"Preview attachment\" data-kind=\"video\" data=\"[[FILENAME]]\" onclick=\"openAttachment(this)\"><span class=\"icon preview-icon\" aria-hidden=\"true\"></span></button>
    <video class=\"video\" controls src=\"[[SOURCE]]\" id=\"video-[[FILENAME]]\" preload=\"none\"></video>
  </p>
  """

  static let text = """
  <p class=\"attachment list-item\">
    <span class=\"icon text-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <button type=\"button\" class=\"preview-button\" aria-label=\"Preview attachment\" data-kind=\"text\" data=\"[[SOURCE]]\" onclick=\"openAttachment(this)\"><span class=\"icon preview-icon\" aria-hidden=\"true\"></span></button>
  </p>
  """

  static let link = """
  <p class=\"attachment list-item\">
    <span class=\"icon text-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <button type=\"button\" class=\"preview-button\" aria-label=\"Preview attachment\" data-kind=\"link\" data=\"[[FILENAME]]\" onclick=\"openAttachment(this)\"><span class=\"icon preview-icon\" aria-hidden=\"true\"></span></button>
    <a class=\"file-attachment-link\" href=\"[[SOURCE]]\" id=\"file-attachment-[[FILENAME]]\"></a>
  </p>
  """
}
