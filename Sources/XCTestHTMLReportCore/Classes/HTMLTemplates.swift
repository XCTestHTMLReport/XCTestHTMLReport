
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
         lightest surface a row can sit on — the sidebar, not the page. The
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

      /* Colour — surfaces */
      --color-surface: #FFF;
      --color-bg-sidebar: #F2F2F2;
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

      /* Colour — borders */
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
         as component-local nudges (icon baseline shifts, the #title and
         #report-issue paddings, the resizer's width) with no common meaning
         to name, so they stay inline. */
      --space-xs: 4px;
      --space-sm: 10px;

      /* Component sizes */
      --icon-size-sm: 10px;
      --icon-size: 14px;
      --icon-size-lg: 24px;
      --preview-height: 600px;
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
           sidebar (#232327, the lightest and so the binding one), the
           surface, and the group header — and has to clear 3:1 against each
           while still carrying white text at 4.5:1. That window is narrow:
           at this hue no value clears both floors by more than ~7%, and this
           one sits at its centre (sidebar 3.25, white 4.82). Splitting a
           separate fill token would buy nothing, because the selected device
           card needs both floors satisfied at once. */
        --color-accent: #2170D6;
        --color-accent-text: #7FB0FF;
        --color-accent-soft: #274A73;
        --color-on-accent: #FFF;

        --color-text-primary: #E8E8EA;
        --color-text-secondary: #C9C9CE;
        --color-text-muted: #9A9AA2;
        --color-text-subtle: #9A9AA2;
        --color-text-placeholder: #8A8A92;

        /* Same 3:1 floor, measured against the dark sidebar (#232327): 5.61
           (skipped/unknown) to 6.74 (expected). */
        --status-passed: #4FBF6B;
        --status-failed: #FF6E6A;
        --status-skipped: #9A9AA2;
        --status-unknown: #9A9AA2;
        --status-expected: #D9A038;
        --status-mixed: #C89AF5;

        --color-surface: #161619;
        --color-bg-sidebar: #232327;
        --color-bg-group-header: #202024;

        /* The tree's own surfaces. The activities panel is *darker* than the
           page rather than lighter, which is the inversion of the light
           theme and is what makes an expanded test read as recessed under
           its row instead of floating above it — the same relationship the
           summary band has to its cards. */
        --color-row-hover: #25252A;
        --color-bg-activities: #1D1D21;
        --color-fail-tint: #3A2226;
        --color-tree-guide: #38383E;

        /* The summary header's own surfaces. The card is the same value as
           the sidebar, which is deliberate: it is the lightest ground in the
           dark theme, so every status token was already sized against it and
           the header inherits those measurements unchanged (5.61 skipped to
           6.74 expected). The band beneath the cards is darker than the page
           so the cards read as raised, the way Xcode's do. */
        --color-bg-summary: #19191C;
        --color-summary-card: #232327;
        --color-summary-card-alt: #2A2A2F;
        --color-summary-border: #3A3A40;
        --color-donut-track: #3A3A40;

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

    body.dragging {
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      -khtml-user-select: none;
      -moz-user-select: none;
      -ms-user-select: none;
      user-select: none;
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

    header {
      color: var(--color-text-primary);
      background-color: var(--color-surface);
      width: 100%;
      /* Same reasoning as .toolbar: 70px is ~4px of slack over the title
         band plus the Tests/Logs row, so any text scaling clipped it. The
         two rows never wrap on their own — the pills that do wrap live in
         .tests-header, not here. */
      min-height: 70px;
      /* A flex item shrinks by default, and #439's summary band made that
         visible: in a short window the header shrank below its content and
         `overflow: hidden` on the body clipped the digest. The band caps its
         own height at 50vh, so refusing to shrink cannot starve the tree. */
      flex: none;
    }

    #info-sections ul {
      padding-left: var(--space-xs);
    }

    #info-sections ul li {
      font-size: var(--font-size-sm);
      color: var(--color-text-secondary);
      line-height: 18px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    #info-sections ul.selected li {
      color: var(--color-on-accent);
    }

    #info-sections ul li h3 {
      font-size: var(--font-size-lg);
      margin: 0;
    }

    .device-info {
      margin: 0;
      padding: var(--space-sm) 0;
      cursor: pointer;
    }

    .device-info.selected {
      background-color: var(--color-accent);
    }

    .device-info li:nth-child(2) {
      margin-bottom: var(--space-sm);
    }

    .device-os,
    .device-identifier,
    .device-model {
      padding-left: 24px;
    }

    .device-info .device-result {
      margin-top: 2px;
      margin-right: 6px;
    }

    #title {
      border-bottom: 1px solid var(--color-border-strong);
      padding: 6px;
    }

    .toolbar {
      background-color: var(--color-surface);
      /* min-, not a fixed height: identical while the row fits on one line,
         but lets it grow instead of spilling over the next element once the
         pills wrap. Adding the viewport meta stopped phones from rendering
         this page zoomed out at desktop width, which is what had been hiding
         that overlap. The actual narrow-screen layout is PR 2's job. */
      min-height: 24px;
      border-bottom: 1px solid var(--color-border-light);
      padding: var(--space-xs) var(--space-sm);
    }

    #test-log-toolbar {
      text-align: center;
      border-bottom: 1px solid var(--color-border-strong);
    }

    #title h1 {
      padding-left: var(--space-sm);
      font-size: var(--font-size-title);
      float: left;
      margin: 0;
      font-weight: var(--font-weight-regular);
    }

    #title span {
      float: left;
    }

    ul.toolbar li {
      display: inline;
    }

    ul.toggle-toolbar li {
      display: inline;
      margin: 0px 2px;
      padding: 3px var(--space-sm);
      border-radius: var(--radius-sm);
      color: var(--color-text-muted);
      font-size: var(--font-size-xs);
      cursor: default;
    }

    ul.toggle-toolbar li:hover {
      background-color: var(--color-accent-soft);
      /* Primary, not --color-on-accent: the soft tint is a pale wash, and
         white on it was 1.55:1. */
      color: var(--color-text-primary);
    }

    ul.toggle-toolbar li.selected {
      background-color: var(--color-accent);
      color: var(--color-on-accent);
    }

    ul.toggle-toolbar.centered-toolbar li {
      color: var(--color-text-muted);
      font-size: var(--font-size-xs);
      cursor: default;
    }

    ul.toggle-toolbar.centered-toolbar li.selected {
      background-color: var(--color-surface);
      color: var(--color-accent-text) !important;
    }

    ul.toggle-toolbar.centered-toolbar li:hover {
      background-color: var(--color-surface);
      color: var(--color-text-muted);
    }

    /* The tree's column header. Two labels, at the two ends of the row the
       columns actually occupy, rather than the old "Status | Tests" pair
       stacked against the left edge — there is a duration column to name now,
       and naming it is the only thing that makes it read as a column. */
    .table-header {
      display: flex;
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

    #logs {
      display: none;
      flex: 1;
      flex-direction: column;
    }

    #logs-iframe {
      border: 0;
      flex: 1;
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

    /* `.left` lived here until A2. Every element that carried it was a tree
       icon clearing a float gutter, and the tree is flex now, so the class
       reached nothing in the rendered page — verified against both goldens.
       `.clear` stays: `#title` and `#container` still float. */
    .clear {
      clear: both;
    }

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
       inheriting the row's text colour. */
    .preview-icon {
      cursor: pointer;
      display: inline-block;
      flex: none;
      height: 11px;
      width: 14px;
      background-color: var(--color-accent-text);
      -webkit-mask-image: var(--icon-preview);
      mask-image: var(--icon-preview);
    }

    p.list-item.selected > .preview-icon,
    p.list-item.selected > .paperclip-icon {
      background-color: var(--color-on-accent);
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

    .run {
      display: none;
      flex: 1;
    }

    .run.active {
      display: flex;
    }

    .tests {
      display: flex;
      flex: 1;
      flex-direction: column;
      overflow-y: scroll;
    }

    /* The list takes focus so it can be scrolled from the keyboard (see the
       `run` template). `:focus-visible`, not `:focus`, so clicking a row does
       not draw a ring around the whole tree; `outline-offset` is negative
       because the outline of a scroll container is drawn at its padding edge
       and a positive offset would sit under the pane beside it. */
    .tests:focus-visible {
      outline: 2px solid var(--color-accent);
      outline-offset: -2px;
    }

    .tests-header, #logs-header {
      width: 100%;
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
       starts at the indent and its background would too. `--row-bleed` paints
       that background back out to the left edge with a horizontal shadow;
       `.tests` is a scroll container, so it clips there. A shadow is ink
       overflow rather than scrollable overflow, so nothing here widens the
       page — the 375px probe covers that.

       Only the three row kinds that sit *in* the tree override it. Activity
       and attachment rows deliberately do not: they live inside the
       activities panel, whose inset background and gutter rule are the thing
       that says "this belongs to the test above", and a row bleeding past
       them would erase exactly that. They keep the `:root` default of `0` and
       highlight in place. */
    .test-summary > p,
    .test-summary-group > p,
    .iteration > p {
      --row-bleed: -100vw;
    }

    .list-item:hover {
      background-color: var(--color-row-hover);
      box-shadow: var(--row-bleed) 0 0 var(--color-row-hover);
    }

    .test-summary-group > p {
      background-color: var(--color-bg-group-header);
      box-shadow: var(--row-bleed) 0 0 var(--color-bg-group-header);
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

    .screenshot {
      background-color: var(--color-surface);
      padding: var(--space-xs);
      height: var(--preview-height);
      position: absolute;
      top:0;
      bottom: 0;
      left: 0;
      right: 0;
      margin: auto;
      display:none;
      z-index: 1000;
    }

    .video {
      background-color: var(--color-surface);
      padding: var(--space-xs);
      height: var(--preview-height);
      position: absolute;
      top:0;
      bottom: 0;
      left: 0;
      right: 0;
      margin: auto;
      display:none;
      z-index: 1000;
    }

    .gif {
      background-color: var(--color-surface);
      padding: var(--space-xs);
      height: var(--preview-height);
      position: absolute;
      top:0;
      bottom: 0;
      left: 0;
      right: 0;
      margin: auto;
      display:none;
      z-index: 1000;
    }
  
    .file-attachment-link {
      display:none;
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

    #container {
      display: flex;
      flex: 1;
      min-height: 0;
    }

    .sidebar {
      position: relative;
      background-color: var(--color-bg-sidebar);
    }

    #left-sidebar {
      width: 200px;
      border-right: 1px solid var(--color-border-strong);
      display: flex;
      flex-direction: column;
    }

    #device-header {
      color: var(--color-text-muted);
      font-size: var(--font-size-md);
      font-weight: var(--font-weight-medium);
      margin: 16px 0 0px var(--space-sm);
      border-bottom: 1px solid var(--color-border-light);
    }

    #info-sections {
      overflow: auto;
      flex: 1;
    }

    #report-issue {
      padding-top: 6px;
      padding-bottom: var(--space-sm);
      width: 100%;
      background-color: var(--color-bg-sidebar);
      text-align: center;
      border-top: 1px solid var(--color-border-strong);
    }

    #report-issue a {
      color: var(--color-text-subtle);
      font-weight: var(--font-weight-regular);
      font-size: 0.8em;
    }

    #report-issue a:active {
      color: var(--color-text-subtle);
    }

    #main-content {
      position: relative;
      flex: 1;
      display: flex;
    }

    #right-sidebar {
      display: flex;
      flex-direction: column;
      width: 400px;
      border-left: 1px solid var(--color-border-strong);
    }

    .resizer {
      cursor: col-resize;
      position: absolute;
      width: 6px;
      height: 100%;
      z-index: 1;
    }

    #right-sidebar .resizer {
      left: 0;
      margin-left: -4px;
    }

    #left-sidebar .resizer {
      right: 0;
      margin-right: -4px;
    }

    #right-sidebar h2,
    #file-attachment {
      color: var(--color-text-placeholder);
      font-weight: var(--font-weight-regular);
      font-size: var(--font-size-xl);
      text-align: center;
      position: absolute;
      width: 100%;
      top: 49%;
    }

    .displayed-screenshot {
      width: 100%;
    }

    .displayed-video {
      width: 100%;
      display: none;
    }

    .displayed-gif {
      width: 100%;
    }

    .attachments {
      display: none;
    }

    #text-attachment {
      border: 0;
      width: 100%;
      flex: 1;
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
      box-shadow: var(--row-bleed) 0 0 var(--color-accent);
      color: var(--color-on-accent);
    }

    /* Summary header (#439, redesign A1).

       Everything from here to the media query is new, and nothing below the
       header was restyled: the tree, the panes and the filter pills are byte
       for byte what they were. A2 restyles the tree; A3 the filters.

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

    .device-bars {
      flex: 1 1 300px;
      min-width: 240px;
    }

    .device-bars-head {
      color: var(--color-text-muted);
      font-size: var(--font-size-xs);
      padding-bottom: 2px;
      border-bottom: 1px solid var(--color-summary-border);
    }

    .device-row {
      padding: 6px 0;
    }

    .device-row-name {
      display: block;
      font-size: var(--font-size-sm);
      overflow-wrap: anywhere;
    }

    .device-row-os {
      color: var(--color-text-muted);
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

    .device-row-tally {
      color: var(--color-text-muted);
      font-size: var(--font-size-xs);
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

       Everything above this point is the desktop layout, untouched: this
       query is the only place the three-pane shape is altered, so at 701px
       and wider the report lays out exactly as it did before.

       700px is where the three panes stop being three panes — a 200px device
       sidebar plus a 400px attachment pane leaves the tree, the only part
       anyone came for, under 100px. Below it the sidebar becomes a
       horizontal strip above the tree, and the attachment pane becomes a
       bottom sheet that joins the layout only while an attachment is
       actually selected. Nothing here changes the DOM, so the filter and
       collapse scripts — which select on `.test-summary` and
       `.test-summary-group` — behave identically in both layouts. */
    @media (max-width: 700px) {
      #container {
        flex-direction: column;
      }

      /* A flex item's automatic minimum size is its *content's* minimum, and
         the tree holds rows that do not break — assertion messages, exported
         filenames. Stacked vertically that minimum became the column's
         width, which pushed the whole tree, and the filter pills with it,
         off the side of a 375px screen. Nothing above the query needs this
         because there the panes are fixed widths.

         `min-height` for the same reason on the other axis, and it fixes a
         worse bug: below 700px `#container` is a *column*, so the tree is
         sized on the block axis by this same automatic minimum, and
         `min-height: auto` let `.tests` grow to the full height of every row
         it holds instead of scrolling inside its share. `body` has
         `overflow: hidden`, so everything past the first viewport was not
         merely unscrolled but unreachable — on a long run the last test in
         the report could not be brought on screen at all. Only the scroll
         container itself strictly needs it, but the automatic minimum
         propagates up a flex chain, so all three do.

         Pre-existing — the column layout arrived with the narrow-screen work
         in #459 — and made materially worse by A1: the summary band spends
         real height above the tree, so the clipped region grew by exactly
         what the band occupies. Found while shooting this PR's 375px
         screenshots; `visual/tests/behaviour.spec.ts` now scrolls to the last
         row at 375 so it cannot come back. */
      #main-content,
      .run,
      .tests {
        min-width: 0;
        min-height: 0;
      }

      /* `flex: none` because the strip is now a row in a column container:
         without it the tree's flex-grow squeezes the device list to nothing.
         `!important` twice below for a different reason — the resizer writes
         a pixel width onto the element's own style attribute, so a window
         narrowed after a drag would otherwise keep the dragged width. */
      #left-sidebar {
        width: auto !important;
        flex: none;
        flex-direction: row;
        align-items: center;
        overflow-x: auto;
        border-right: 0;
        border-bottom: 1px solid var(--color-border-strong);
      }

      /* Dragging the edge of a full-width strip, or of a bottom sheet,
         means nothing. */
      .resizer {
        display: none;
      }

      #device-header {
        margin: 0 var(--space-sm);
        border-bottom: 0;
        white-space: nowrap;
      }

      #info-sections {
        display: flex;
      }

      #info-sections ul li,
      #info-sections ul li h3 {
        display: inline;
        font-size: var(--font-size-sm);
      }

      .device-os,
      .device-model {
        padding-left: var(--space-sm);
      }

      /* The longest of the four fields and the least useful on a phone.
         Qualified by the ID above deliberately: a bare `.device-identifier`
         loses the cascade to `#info-sections ul li`'s `display: inline`
         a dozen lines up, and the field stays on screen. */
      #info-sections ul li.device-identifier {
        display: none;
      }

      .device-info {
        padding: 6px var(--space-sm);
        white-space: nowrap;
      }

      #report-issue {
        display: none;
      }

      /* The flex row already spends only what it draws, so there is no fixed
         gutter left to reclaim here — what A1 needed this rule for is gone.
         What is left is the indentation step: 16px per level is right at
         1440px and profligate on a 375px screen four levels deep, where the
         legacy backend's two wrapper levels alone would eat 32px before the
         first suite. */
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

      #right-sidebar {
        display: none;
        position: fixed;
        left: 0;
        right: 0;
        bottom: 0;
        width: auto !important;
        max-height: 50vh;
        overflow: auto;
        border-left: 0;
        border-top: 1px solid var(--color-border-strong);
        z-index: 50;
      }

      body.attachment-open #right-sidebar {
        display: flex;
      }

      /* So the sheet never sits on top of the last rows of the tree. */
      body.attachment-open .tests {
        padding-bottom: 50vh;
      }

      /* The placeholder and the file-download link are both centred
         absolutely by the desktop sheet; in a bottom sheet they flow. */
      #right-sidebar h2,
      #file-attachment {
        position: static;
        width: auto;
        margin: var(--space-sm);
      }

      .displayed-screenshot,
      .displayed-gif {
        max-height: 40vh;
        object-fit: contain;
      }

      /* Summary header, narrow (#439, A1). The three columns of the summary
         grid stack on their own — `flex-wrap` and the device bars' 300px
         basis already do that — so this only tightens the spacing and shrinks
         the ring, which at 108px would otherwise eat a third of a 375px row. */
      /* 40vh, not the desktop 50: the title band and the Tests/Logs row are a
         fixed cost, and on an 812px phone a half-viewport band left the tree
         with less than the summary above it. */
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

      .device-bars {
        flex-basis: 100%;
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
          <div class=\"clear\"></div>
        </div>
        [[RUN_SUMMARY]]
        <ul id=\"test-log-toolbar\" class=\"toolbar centered-toolbar toggle-toolbar\">
          <li class=\"selected\" onclick=\"showTests(this);\">Tests</li>
          <li onclick=\"showLogs(this);\">Logs</li>
        </ul>
      </header>
      <div id=\"container\">
        <nav id=\"left-sidebar\" class=\"sidebar\" aria-label=\"Devices\">
          <div class=\"resizer\"></div>
          <h2 id=\"device-header\">Devices</h2>
          <ul id=\"info-sections\">
            <li class=\"section\">
              [[DEVICES]]
            </li>
          </ul>
          <div id=\"report-issue\"><a href=\"https://github.com/TitouanVanBelle/XCTestHTMLReport/blob/master/CONTRIBUTING.md#reporting-issues\">Report an issue</a></div>
        </nav>

        <main id=\"main-content\">
          [[RUNS]]
        </main>

        <aside id=\"right-sidebar\" class=\"sidebar\" aria-label=\"Attachment preview\">
          <div class=\"resizer\"></div>
          <h2>No Selected Attachment</h2>
          <img src=\"\" class=\"displayed-screenshot\" id=\"screenshot\" alt=\"\" loading=\"lazy\"/>
          <img src=\"\" class=\"displayed-gif\" id=\"gif\" alt=\"\" loading=\"lazy\"/>
          <iframe id=\"text-attachment\" src=\"\" title=\"Selected attachment\" loading=\"lazy\"></iframe>
          <p id=\"file-attachment\"><a target=\"_blank\"></a></p>
          <video class=\"displayed-video\" controls src=\"\" id=\"video\" preload=\"none\"/>
        </aside>
        <div class=\"clear\"></div>
      </div>
    </div>

    <script type=\"text/javascript\">
    var resizers = document.querySelectorAll('.resizer'),
    leftSidebar = document.getElementById('left-sidebar'),
    rightSidebar = document.getElementById('right-sidebar'),
    sidebar, startX, startWidth, originalWidth,
    screenshot = document.getElementById('screenshot'),
    video = document.getElementById('video'),
    gif = document.getElementById('gif'),
    iframe = document.getElementById('text-attachment'),
    fileAttachment = document.getElementById('file-attachment');

    for (var i = 0; i < resizers.length; i++) {
        resizers[i].addEventListener('mousedown', initDrag, false);
    }

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
    }

    function selectListItem(listItem) {
      if (selectedListItem) {
        selectedListItem.classList.remove(\"selected\");
      }

      selectedListItem = listItem;
      selectedListItem.classList.add(\"selected\");

      var firstAttachment = selectedListItem.querySelector('.attachment .preview-icon');

      if (firstAttachment == null) {
        hideScreenshot();
        hideLog();
        hideVideo();
        hideGif();
        hideLinkAttachment();
        showAttachmentPlaceholder();
        return;
      }

      var path = firstAttachment.attributes[\"data\"].value;
      var extension = path.split('.').pop();
      var textExtension = [\"txt\", \"crash\", \"html\", \"log\"];
      const photoExtensions = [\"png\", \"jpeg\", \"heic\"];
      if (textExtension.indexOf(extension) != -1 || extension.startsWith(\"data:text/plain\")) {
        showText(path);
      } else if (extension == \"mp4\") {
        showVideo(path);
      } else if (photoExtensions.indexOf(extension) > 0 || extension.startsWith(\"data:image\")) {
        showScreenshot(path);
      } else if (extension == \"gif\") {
        showGif(path);
      } else {
        showLinkAttachment(path);
      }
    }

    function selectDevice(deviceId, el) {
      while (el && !el.classList.contains('device-info')) {
        el = el.parentElement;
      }

      document.querySelectorAll('.device-info.selected')[0].classList.remove(\"selected\");
      el.classList.add(\"selected\");

      document.querySelectorAll('.run.active')[0].classList.remove(\"active\");
      document.querySelectorAll('#device_' + deviceId)[0].classList.add(\"active\");
    }

    function keyDown(e) {
        e = e || window.event;

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
      var dropIcon = selectedListItem.querySelector('.drop-down-icon');
      if (dropIcon == null) {
        return;
      }

      if (dropIcon.classList.contains(\"dropped\")) {
        selectedListItem.querySelector('.drop-down-icon').onclick();
      }
    }

    function unfoldCurrentListItem() {
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

            var scrollView = document.querySelector('.run.active .tests');
            if (!divInsideOfDiv(item, scrollView)) {
              scrollToItem(item);
            }

            return;
          }
        }
      } else {
        selectListItem(items[0]);
      }
    }

    function scrollToItem(item) {
      var scrollView = document.querySelector('.run.active .tests'),
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


    function initDrag(e) {
      sidebar = e.target.parentElement;
      startX = e.clientX;
      startWidth = parseInt(document.defaultView.getComputedStyle(sidebar).width, 10);
      originalSidebarWidth = sidebar.clientWidth;
      document.documentElement.addEventListener('mousemove', doDrag, false);
      document.documentElement.addEventListener('mouseup', stopDrag, false);

      document.body.classList.add('dragging');
    }

    function doDrag(e) {
      var newSidebarWidth,
      distance = startX - e.clientX;

      if (sidebar == leftSidebar) {
        newSidebarWidth = Math.min(Math.max(originalSidebarWidth - distance, 200), 500);
      } else if (sidebar == rightSidebar) {
        newSidebarWidth = Math.min(Math.max(originalSidebarWidth + distance, 300), 800);
      }

      sidebar.style.width = newSidebarWidth + 'px';
    }

    function stopDrag(e) {
      document.documentElement.removeEventListener('mousemove', doDrag, false);
      document.documentElement.removeEventListener('mouseup', stopDrag, false);

      document.body.classList.remove('dragging')
    }

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

    // These two are already the report's \"an attachment is / is not being
    // shown\" hooks, so they are also where the narrow-screen bottom sheet
    // learns whether to be in the layout at all (#439). On desktop the class
    // is inert -- no rule outside the max-width query mentions it.
    function showAttachmentPlaceholder() {
      var placeholder = document.querySelector(\"#right-sidebar h2\");
      placeholder.style.display = \"block\";
      document.body.classList.remove('attachment-open');
    }

    function hideAttachmentPlaceholder() {
      var placeholder = document.querySelector(\"#right-sidebar h2\");
      placeholder.style.display = \"none\";
      document.body.classList.add('attachment-open');
    }

    function hideLog() {
      iframe.style.display = \"none\";
    }

    function showText(path) {
      hideAttachmentPlaceholder();
      hideScreenshot();
      hideVideo();
      hideGif();
      hideLinkAttachment();
      iframe.style.display = \"block\";
      iframe.src = path;
    }

    function hideScreenshot() {
      screenshot.style.display = \"none\";
    }

    function hideVideo() {
      video.style.display = \"none\";
    }

    function hideGif() {
      gif.style.display = \"none\";
    }

    function showScreenshot(filename) {
      hideAttachmentPlaceholder();
      hideLog();
      hideVideo();
      hideGif();
      hideLinkAttachment();
      var image = document.getElementById('screenshot-'+filename);
      screenshot.style.display = \"block\";
      screenshot.src = image.src;
      screenshot.alt = image.alt;
    }

    function showVideo(filename) {
      hideAttachmentPlaceholder();
      hideLog();
      hideScreenshot();
      hideGif();
      hideLinkAttachment();
      var vid = document.getElementById('video-'+filename);
      video.style.display = \"block\";
      video.src = vid.src;
      video.play();
    }

    function showGif(filename) {
    hideAttachmentPlaceholder();
    hideLog();
    hideVideo();
    hideScreenshot();
    hideLinkAttachment();
    var gf = document.getElementById('gif-'+filename);
    gif.style.display = \"block\";
    gif.src = gf.src;
    gif.alt = gf.alt;
    gif.play();
    }
    
    function hideLinkAttachment() {
      fileAttachment.style.display = \"none\";
    }
  
    function showLinkAttachment(filename) {
      hideAttachmentPlaceholder();
      hideLog();
      hideScreenshot();
      hideVideo();
      hideGif();
      const fileAttachmentPath = document.getElementById(`file-attachment-${filename}`)
      const link = document.querySelector(\"#file-attachment > a\")
      link.textContent = `Download ${filename}`
      link.href = fileAttachmentPath.href
      fileAttachment.style.display = \"block\";
    }

    function setDisplayToElementsWithSelector(sel, display) {
      [].forEach.call(document.querySelectorAll(sel), function (el) {
        el.style.display = display;
      });
    }

    function hideElementsWithSelector(sel) {
      setDisplayToElementsWithSelector(sel, 'none');
    }

    function showElementsWithSelector(sel) {
      setDisplayToElementsWithSelector(sel, 'block');
    }

    function selectedElement(el) {
      el.parentElement.querySelectorAll('.selected')[0].classList.remove('selected');
      el.classList.add('selected');
    }

    function showAllScenarios(el) {
      selectedElement(el);
      showElementsWithSelector('.run.active .test-summary.succeeded');
      showElementsWithSelector('.run.active .test-summary.skipped');
      showElementsWithSelector('.run.active .test-summary.failed');
      showElementsWithSelector('.run.active .test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function showSuccessfulScenariosOnly(el) {
      selectedElement(el);
      showElementsWithSelector('.run.active .test-summary.succeeded');
      hideElementsWithSelector('.run.active .test-summary.skipped');
      hideElementsWithSelector('.run.active .test-summary.failed');
      hideElementsWithSelector('.run.active .test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function showSkippedScenariosOnly(el) {
      selectedElement(el);
      hideElementsWithSelector('.run.active .test-summary.succeeded');
      showElementsWithSelector('.run.active .test-summary.skipped');
      hideElementsWithSelector('.run.active .test-summary.failed');
      hideElementsWithSelector('.run.active .test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function showFailedScenariosOnly(el) {
      selectedElement(el);
      hideElementsWithSelector('.run.active .test-summary.succeeded');
      hideElementsWithSelector('.run.active .test-summary.skipped');
      showElementsWithSelector('.run.active .test-summary.failed');
      hideElementsWithSelector('.run.active .test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }
  
    function showMixedScenariosOnly(el) {
      selectedElement(el);
      hideElementsWithSelector('.run.active .test-summary.succeeded');
      hideElementsWithSelector('.run.active .test-summary.skipped');
      hideElementsWithSelector('.run.active .test-summary.failed');
      showElementsWithSelector('.run.active .test-summary.mixed');
      hideSummaryGroupsIfNeeded();
    }

    function hideSummaryGroupsIfNeeded() {
      var testSummaryGroups = Array.prototype.slice.call(document.querySelectorAll('.run.active .test-summary-group'));
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

    // The summary header describes the *test* run — an outcome ring, a
    // failure digest, per-device bars — and none of it says anything about
    // the log the Logs tab shows. Xcode does the same thing: switching to a
    // different report gives that report the whole column. A body class
    // rather than a style written onto #run-summary, so the band's own rules
    // (including its two max-heights) stay in the stylesheet and A3 can move
    // the tabs without hunting for a display value in a script.
    function showLogs(el) {
      selectedElement(el);
      setDisplayToElementsWithSelector('#logs', 'flex');
      setDisplayToElementsWithSelector('.tests', 'none');
      document.body.classList.add('logs-active');
    }

    function showTests(el) {
      selectedElement(el);
      setDisplayToElementsWithSelector('#logs', 'none');
      setDisplayToElementsWithSelector('.tests', 'flex');
      document.body.classList.remove('logs-active');
    }

    document.querySelectorAll('.device-info')[0].classList.add(\"selected\");
    document.querySelectorAll('.run')[0].classList.add(\"active\");

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

      var testsTab = document.querySelector('#test-log-toolbar li');
      if (testsTab && !testsTab.classList.contains('selected')) {
        showTests(testsTab);
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

    // `.run` elements and `.device-info` cards are rendered from one list of
    // runs, in order, so the nth card selects the nth run. Going through
    // selectDevice rather than toggling the classes here keeps one definition
    // of what \"active\" means.
    function activateRunContaining(el) {
      var run = el.closest('.run');
      if (!run || run.classList.contains('active')) {
        return;
      }
      var runs = Array.prototype.slice.call(document.querySelectorAll('.run')),
          cards = document.querySelectorAll('.device-info'),
          index = runs.indexOf(run);
      if (index >= 0 && cards[index]) {
        selectDevice(run.id.replace('device_', ''), cards[index]);
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
            <div class=\"device-bars\">
              <p class=\"device-bars-head\">Devices &amp; Configurations</p>
              [[DEVICE_BARS]]
            </div>
          </div>
        </div>
        [[FAILURE_DIGEST]]
      </section>
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

  /// One device row: name, proportional bar, and the same breakdown in words.
  /// The bar is `aria-hidden` for the reason the ring is — the caption beside
  /// it is the accessible reading of the identical fact.
  static let summaryDeviceRow = """
  <div class=\"device-row\">
                <span class=\"device-row-name\">[[DEVICE_LABEL]]</span>
                <svg class=\"segbar\" viewBox=\"0 0 100 8\" preserveAspectRatio=\"none\" aria-hidden=\"true\" focusable=\"false\">[[SEGMENTS]]</svg>
                <span class=\"device-row-tally\">[[DEVICE_TALLY]]</span>
              </div>
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

  static let device = """
    <ul class=\"device-info\" onclick=\"selectDevice('[[DEVICE_IDENTIFIER]]', this);\">
    <li>[[DEVICE_RESULT]]<h3 class=\"device-name\">[[DEVICE_NAME]]</h3></li>
    <li class=\"device-os\">iOS [[DEVICE_OS]]</li>
    <li class=\"device-model\">Model: [[DEVICE_MODEL]]</li>
    <li class=\"device-identifier\">Identifier: [[DEVICE_IDENTIFIER]]</li>
  </ul>
  """

  /// One device's run.
  ///
  /// `tabindex="0"` on the scrolling test list is an accessibility fix, not a
  /// layout one: axe's `scrollable-region-focusable` (serious) requires that a
  /// region a sighted user can scroll is reachable by a keyboard user too, and
  /// a `div` with `overflow-y: scroll` and no focusable descendant is not. The
  /// tree has always been that region — the gate stayed green only because the
  /// synthetic fixture's rows happened to fall seven pixels short of
  /// overflowing it, so the rule never fired on the one page CI checks. Any
  /// real report has always tripped it. With the attribute the list takes
  /// focus and Page Up/Down, Home and End scroll it; the arrow keys keep going
  /// to the existing row navigation, which scrolls the same region by moving
  /// the selection.
  static let run = """
  <div class=\"run\" id=\"device_[[DEVICE_IDENTIFIER]]\">
    <div class=\"tests\" tabindex=\"0\">
      <div class=\"tests-header\">
        <ul class=\"toolbar toggle-toolbar\">
          <li onclick=\"showAllScenarios(this);\" class=\"selected\">All ([[N_OF_TESTS]])</li>
          <li onclick=\"showSuccessfulScenariosOnly(this);\">Passed ([[N_OF_PASSED_TESTS]])</li>
          <li onclick=\"showSkippedScenariosOnly(this);\">Skipped ([[N_OF_SKIPPED_TESTS]])</li>
          <li onclick=\"showFailedScenariosOnly(this);\">Failed ([[N_OF_FAILED_TESTS]])</li>
          <li onclick=\"showMixedScenariosOnly(this);\">Mixed ([[N_OF_MIXED_TESTS]])</li>
        </ul>
        <ul class=\"toolbar table-header\">
          <li>Test</li>
          <li>Duration</li>
        </ul>
      </div>
      [[TEST_SUMMARIES]]
    </div>
    <div id=\"logs\">
      <div id=\"logs-header\">
        <ul class=\"toolbar toggle-toolbar\">
          <li class=\"selected\">All Messages</li>
        </ul>
      </div>
      <iframe id=\"logs-iframe\" src=\"[[LOG_SOURCE]]\" title=\"Run log\" loading=\"lazy\"></iframe>
    </div>
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

  static let screenshot = """
  <p class=\"attachment list-item\">
    <span class=\"icon screenshot-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showScreenshot(this.getAttribute('data'))\"></span>
    <img class=\"screenshot\" src=\"[[SOURCE]]\" id=\"screenshot-[[FILENAME]]\" alt=\"[[NAME]]\" loading=\"lazy\"/>
  </p>
  """

  static let gif = """
  <p class="attachment list-item">
    <span class="icon screenshot-icon" style="margin-left: [[PADDING]]px"></span>
    <span class="row-name">[[NAME]]</span>
  <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showGif(this.getAttribute('data'))\"></span>
    <img class=\"gif\" src=\"[[SOURCE]]\" id=\"gif-[[FILENAME]]\" alt=\"[[NAME]]\" loading=\"lazy\"/>
  </p>
  """

  static let video = """
  <p class=\"attachment list-item\">
    <span class=\"icon video-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showVideo(this.getAttribute('data'))\"></span>
    <video class=\"video\" controls src=\"[[SOURCE]]\" id=\"video-[[FILENAME]]\" preload=\"none\"/>
  </p>
  """

  static let text = """
  <p class=\"attachment list-item\">
    <span class=\"icon text-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <span class=\"icon preview-icon\" data=\"[[SOURCE]]\" onclick=\"showText(this.getAttribute('data'))\"></span>
  </p>
  """

  static let link = """
  <p class=\"attachment list-item\">
    <span class=\"icon text-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    <span class=\"row-name\">[[NAME]]</span>
    <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showLinkAttachment(this.getAttribute('data'))\"></span>
    <a class=\"file-attachment-link\" href=\"[[SOURCE]]\" id=\"file-attachment-[[FILENAME]]\"></a>
  </p>
  """
}
