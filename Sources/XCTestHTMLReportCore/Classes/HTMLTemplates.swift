
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

      /* Colour — surfaces */
      --color-surface: #FFF;
      --color-bg-sidebar: #F2F2F2;
      --color-bg-group-header: #F6F6F6;

      /* Colour — borders */
      --color-border-strong: #BBB;
      --color-border-medium: #CCC;
      --color-border-light: #DDD;
      --color-border-faint: #E5E5E5;
      --color-preview-border: #021a40;

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

      /* Glyphs. Shapes, not colours — the colour is applied separately (see
         the icon block below), which is why these are shared by both themes
         and the dark block does not repeat them. Kept here so the sheet has
         exactly one place where the report's iconography is defined.

         Geometry note: every status glyph is the same rounded diamond, so
         the six states differ by what sits inside it and by shape — filled
         with a knock-out for the three settled outcomes, outlined for the
         three that are qualified. That reproduces the diamond the PNGs drew,
         which is the identity this refresh is keeping. */
      --icon-status-passed: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Cpath d='M9.06 1.66 14.34 6.94Q15.4 8 14.34 9.06L9.06 14.34Q8 15.4 6.94 14.34L1.66 9.06Q.6 8 1.66 6.94L6.94 1.66Q8 .6 9.06 1.66Z' fill='white'/%3E%3Cpath d='M4.7 8.2 6.9 10.5 11.3 5.6' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-failed: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Cpath d='M9.06 1.66 14.34 6.94Q15.4 8 14.34 9.06L9.06 14.34Q8 15.4 6.94 14.34L1.66 9.06Q.6 8 1.66 6.94L6.94 1.66Q8 .6 9.06 1.66Z' fill='white'/%3E%3Cpath d='M5.6 5.6 10.4 10.4M10.4 5.6 5.6 10.4' fill='none' stroke='black' stroke-width='2' stroke-linecap='round'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-skipped: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Cpath d='M9.06 1.66 14.34 6.94Q15.4 8 14.34 9.06L9.06 14.34Q8 15.4 6.94 14.34L1.66 9.06Q.6 8 1.66 6.94L6.94 1.66Q8 .6 9.06 1.66Z' fill='white'/%3E%3Cpath d='M5.4 9.9 10.6 6.1M6.1 6.1h4.5v4.5' fill='none' stroke='black' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-mixed: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Cpath d='M9.06 1.66 14.34 6.94Q15.4 8 14.34 9.06L9.06 14.34Q8 15.4 6.94 14.34L1.66 9.06Q.6 8 1.66 6.94L6.94 1.66Q8 .6 9.06 1.66Z' fill='white'/%3E%3Cpath d='M8 1.2V14.8' fill='none' stroke='black' stroke-width='1.4'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-status-unknown: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M9.06 1.66 14.34 6.94Q15.4 8 14.34 9.06L9.06 14.34Q8 15.4 6.94 14.34L1.66 9.06Q.6 8 1.66 6.94L6.94 1.66Q8 .6 9.06 1.66Z' fill='none' stroke='black' stroke-width='1.6'/%3E%3Cpath d='M6.5 6.4a1.6 1.6 0 1 1 1.6 1.9v.8' fill='none' stroke='black' stroke-width='1.3' stroke-linecap='round'/%3E%3Ccircle cx='8.1' cy='11.2' r='.8'/%3E%3C/svg%3E");
      --icon-status-expected: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M9.06 1.66 14.34 6.94Q15.4 8 14.34 9.06L9.06 14.34Q8 15.4 6.94 14.34L1.66 9.06Q.6 8 1.66 6.94L6.94 1.66Q8 .6 9.06 1.66Z' fill='none' stroke='black' stroke-width='1.6'/%3E%3Cpath d='M8 4.8v3.6' stroke='black' stroke-width='1.6' stroke-linecap='round'/%3E%3Ccircle cx='8' cy='11' r='.9'/%3E%3C/svg%3E");
      --icon-disclosure: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'%3E%3Cpath d='M3 1.4 8 5 3 8.6Z'/%3E%3C/svg%3E");
      --icon-disclosure-open: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'%3E%3Cpath d='M1.4 3 8.6 3 5 8Z'/%3E%3C/svg%3E");
      --icon-paperclip: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cpath d='M2.7 15.3c-.7 0-1.4-.3-1.9-.8-.9-.9-1.2-2.5 0-3.7l8.9-8.9c1.4-1.4 3.8-1.4 5.2 0s1.4 3.8 0 5.2l-7.4 7.4c-.2.2-.5.2-.7 0s-.2-.5 0-.7l7.4-7.4c1-1 1-2.7 0-3.7s-2.7-1-3.7 0l-8.9 8.9c-.8.8-.6 1.7 0 2.2.6.6 1.5.8 2.2 0l8.9-8.9c.2-.2.2-.5 0-.7s-.5-.2-.7 0l-7.4 7.4c-.2.2-.5.2-.7 0s-.2-.5 0-.7l7.4-7.4c.6-.6 1.6-.6 2.2 0s.6 1.6 0 2.2l-8.9 8.9c-.6.4-1.3.7-1.9.7z'/%3E%3C/svg%3E");
      --icon-preview: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 12'%3E%3Cpath d='M1 6s2.7-4 7-4 7 4 7 4-2.7 4-7 4-7-4-7-4z' fill='none' stroke='black' stroke-width='1.3'/%3E%3Ccircle cx='8' cy='6' r='1.9'/%3E%3C/svg%3E");
      --icon-document: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Cpath d='M3.2 1.4h6L13 5.2v9.4H3.2Z' fill='white'/%3E%3Cpath d='M5.2 7.4h5.6M5.2 9.6h5.6M5.2 11.8h3.6' stroke='black' stroke-width='1.1' stroke-linecap='round'/%3E%3Cpath d='M8.9 1.6v3.6h3.6' fill='none' stroke='black' stroke-width='1.1'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1.4' y='2.8' width='13.2' height='10.4' rx='1.4' fill='white'/%3E%3Cpath d='M2.6 12 6.3 7.6l2.5 2.6 2-2 2.6 3.8Z' fill='black'/%3E%3Ccircle cx='5.4' cy='6' r='1.3' fill='black'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-video: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1.4' y='3.2' width='13.2' height='9.6' rx='1.4' fill='white'/%3E%3Cpath d='M6.6 5.9 11 8l-4.4 2.1Z' fill='black'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
      --icon-test: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16'%3E%3Cmask id='a'%3E%3Crect x='1.6' y='1.6' width='12.8' height='12.8' rx='2.6' fill='white'/%3E%3Cpath d='M8.6 3.9v6.4a1.4 1.4 0 0 0 1.4 1.4h.6M6.1 6.6h4.3' fill='none' stroke='black' stroke-width='1.5' stroke-linecap='round'/%3E%3C/mask%3E%3Crect width='16' height='16' mask='url(%23a)'/%3E%3C/svg%3E");
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

        --color-surface: #161619;
        --color-bg-sidebar: #232327;
        --color-bg-group-header: #202024;

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

    .table-header {
      min-height: 18px;
      margin: 0;
      padding-top: 0;
    }

    .table-header li {
      font-size: var(--font-size-xs);
      color: var(--color-text-muted);
    }

    .table-header li+li {
      border-left: 1px solid var(--color-border-medium);
      padding-left: var(--space-xs);
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

    .left {
      float: left;
    }

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

    /* The one glyph that is not `currentColor`: the rounded blue tile is the
       project's own mark, so it keeps its colour instead of inheriting the
       row's — except on a selected row, where the accent fill would put blue
       on blue. Today's PNG has no such escape and does disappear there. */
    .test-icon {
      display: none;
      background-color: var(--color-accent);
      -webkit-mask-image: var(--icon-test);
      mask-image: var(--icon-test);
    }

    .list-item.selected .test-icon {
      background-color: var(--color-on-accent);
    }

    .test-summary p > .test-icon {
      display: block;
    }

    .test-summary.no-drop-down .drop-down-icon {
      display: none;
    }

    .test-summary.no-drop-down .test-icon {
      margin-left: 22px;
    }

    /* The gutter the status glyph sits in. `margin-left` lives here rather
       than on the per-status rules below so that one single-class rule can
       narrow it on small screens; the per-status rules carry three classes
       each, which no media query could outrank without `!important`. */
    .test-result-icon {
      float: left;
      display: none;
      margin: var(--space-xs);
      margin-left: 28px;
    }

    /* Which rows show a status glyph at all. Before #439 only the three
       states that had a PNG appeared here, so `mixed`, `unknown` and
       `expectedFailure` rows rendered an empty status cell — the audit's
       finding 4. All six states now have one, and each is a distinct shape,
       not just a distinct colour. Group headings are deliberately still
       absent: giving them icons is a layout change beyond this PR.

       `>`, not a descendant combinator, throughout the status rules. A
       retried test nests its iterations *inside* the row, and each carries
       its own `.test-result-icon`; matched loosely, the outer row's rule
       reaches them too, and since every one of these selectors has the same
       specificity the winner is whichever is written last. That was
       invisible while only three states had rules — a failed test's
       iterations are usually failed as well — and showed up the moment
       `mixed` existed: `testRetryOnFailure()`'s two iterations, one failed
       and one passed, both drew the split diamond of their parent. */
    .test-summary.succeeded > .test-result-icon,
    .test-summary.skipped > .test-result-icon,
    .test-summary.failed > .test-result-icon,
    .test-summary.mixed > .test-result-icon,
    .test-summary.unknown > .test-result-icon,
    .test-summary.expected-failure > .test-result-icon,
    .iteration.succeeded > .test-result-icon,
    .iteration.skipped > .test-result-icon,
    .iteration.failed > .test-result-icon,
    .iteration.mixed > .test-result-icon,
    .iteration.unknown > .test-result-icon,
    .iteration.expected-failure > .test-result-icon {
      display: block;
    }

    .test-summary.succeeded > .test-result-icon,
    .iteration.succeeded > .test-result-icon,
    .success {
      background-color: var(--status-passed);
      -webkit-mask-image: var(--icon-status-passed);
      mask-image: var(--icon-status-passed);
    }

    .test-summary.skipped > .test-result-icon,
    .iteration.skipped > .test-result-icon,
    .skip {
      background-color: var(--status-skipped);
      -webkit-mask-image: var(--icon-status-skipped);
      mask-image: var(--icon-status-skipped);
    }

    .test-summary.failed > .test-result-icon,
    .iteration.failed > .test-result-icon,
    .failure {
      background-color: var(--status-failed);
      -webkit-mask-image: var(--icon-status-failed);
      mask-image: var(--icon-status-failed);
    }

    /* Mixed is the one glyph that carries two colours, because "some passed,
       some failed" is what it means. The mask is a plain diamond split by a
       thin cut, and the two halves are a hard-stop gradient — so both halves
       are tokens and follow the theme, which a two-colour image could not. */
    .test-summary.mixed > .test-result-icon,
    .iteration.mixed > .test-result-icon {
      background-color: transparent;
      background-image: linear-gradient(
        90deg,
        var(--status-passed) 0 50%,
        var(--status-failed) 50% 100%
      );
      -webkit-mask-image: var(--icon-status-mixed);
      mask-image: var(--icon-status-mixed);
    }

    .test-summary.unknown > .test-result-icon,
    .iteration.unknown > .test-result-icon {
      background-color: var(--status-unknown);
      -webkit-mask-image: var(--icon-status-unknown);
      mask-image: var(--icon-status-unknown);
    }

    .test-summary.expected-failure > .test-result-icon,
    .iteration.expected-failure > .test-result-icon {
      background-color: var(--status-expected);
      -webkit-mask-image: var(--icon-status-expected);
      mask-image: var(--icon-status-expected);
    }

    .drop-down-icon {
      cursor: pointer;
      height: var(--icon-size-sm);
      width: var(--icon-size-sm);
      margin-top: 2px;
      -webkit-mask-image: var(--icon-disclosure);
      mask-image: var(--icon-disclosure);
    }

    .drop-down-icon.dropped {
      -webkit-mask-image: var(--icon-disclosure-open);
      mask-image: var(--icon-disclosure-open);
    }

    .preview-icon {
      cursor: pointer;
      display: inline-block;
      height: 11px;
      width: 14px;
      -webkit-mask-image: var(--icon-preview);
      mask-image: var(--icon-preview);
    }

    .activities {
      display: none;
    }

    .activity.activity-assertion-failure > p {
      color: var(--status-failed);
    }

    .sub-activities {
      display: none;
    }

    .padding {
      float: left;
      width: 1px;
      height:1px;
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

    .tests-header, #logs-header {
      width: 100%;
    }

    .tests > .summary {
      width: 100%;
    }
  
    .iteration {
      margin-left: var(--space-sm);
    }

    .test-summary p, .test-summary-group p, .iteration p, .activity p {
      font-size: var(--font-size-sm);
      padding: var(--space-xs) var(--space-xs) var(--space-xs) 52px;
      border-bottom: 1px solid var(--color-border-faint);
    }

    .test-summary-group > p {
      background-color: var(--color-bg-group-header);
      font-weight: var(--font-weight-medium);
    }

    .test-summary-group > p > .drop-down-icon {
      display: none;
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

    .screenshot-flow {
        border: 1px solid var(--color-preview-border);
        background-color: var(--color-surface);
        height: 200px;
    }

    .screenshot-tail {
        border: 1px solid var(--color-preview-border);
        background-color: var(--color-surface);
        height: 350px;
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

    .list-item.selected {
      background-color: var(--color-accent);
    }

    .list-item.selected {
      color: var(--color-on-accent);
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
         because there the panes are fixed widths. */
      #main-content,
      .run,
      .tests {
        min-width: 0;
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

      /* Reclaim the 16px the status gutter spends. At 375px that is the
         difference between a test name fitting on one line and wrapping. */
      .test-summary p, .test-summary-group p, .iteration p, .activity p {
        padding-left: 36px;
        overflow-wrap: break-word;
      }

      .test-result-icon {
        margin-left: 12px;
      }

      .test-summary.no-drop-down .test-icon {
        margin-left: 6px;
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

    function showLogs(el) {
      selectedElement(el);
      setDisplayToElementsWithSelector('#logs', 'flex');
      setDisplayToElementsWithSelector('.tests', 'none');
    }

    function showTests(el) {
      selectedElement(el);
      setDisplayToElementsWithSelector('#logs', 'none');
      setDisplayToElementsWithSelector('.tests', 'flex');
    }

    document.querySelectorAll('.device-info')[0].classList.add(\"selected\");
    document.querySelectorAll('.run')[0].classList.add(\"active\");

    </script>
  </body>
  </html>
  """

  static let device = """
    <ul class=\"device-info\" onclick=\"selectDevice('[[DEVICE_IDENTIFIER]]', this);\">
    <li>[[DEVICE_RESULT]]<h3 class=\"device-name\">[[DEVICE_NAME]]</h3></li>
    <li class=\"device-os\">iOS [[DEVICE_OS]]</li>
    <li class=\"device-model\">Model: [[DEVICE_MODEL]]</li>
    <li class=\"device-identifier\">Identifier: [[DEVICE_IDENTIFIER]]</li>
  </ul>
  """

  static let run = """
  <div class=\"run\" id=\"device_[[DEVICE_IDENTIFIER]]\">
    <div class=\"tests\">
      <div class=\"tests-header\">
        <ul class=\"toolbar toggle-toolbar\">
          <li onclick=\"showAllScenarios(this);\" class=\"selected\">All ([[N_OF_TESTS]])</li>
          <li onclick=\"showSuccessfulScenariosOnly(this);\">Passed ([[N_OF_PASSED_TESTS]])</li>
          <li onclick=\"showSkippedScenariosOnly(this);\">Skipped ([[N_OF_SKIPPED_TESTS]])</li>
          <li onclick=\"showFailedScenariosOnly(this);\">Failed ([[N_OF_FAILED_TESTS]])</li>
          <li onclick=\"showMixedScenariosOnly(this);\">Mixed ([[N_OF_MIXED_TESTS]])</li>
        </ul>
        <ul class=\"toolbar table-header\">
          <li>Status</li>
          <li>Tests</li>
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
    
  static let testCase = """
    [[SCREENSHOT_TAIL]]
    <div class=\"[[ITEM_CLASS]] [[ICON_CLASS]]\">
        <span class=\"icon left test-result-icon\"></span>
        <p class=\"list-item\">
            <span class=\"icon left drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon left test-icon\"></span>
            [[TITLE]] ([[DURATION]])
        </p>
        <div id=\"activities-[[UUID]]\" class=\"activities\">
            [[SCREENSHOT_FLOW]]
            [[ACTIVITIES]]
        </div>
    </div>
  """
    
  static let testCaseWithIterations = """
    <div class=\"[[ITEM_CLASS]] [[ICON_CLASS]]\">
        <span class=\"icon left test-result-icon\"></span>
        <p class=\"list-item\">
            <span class=\"icon left drop-down-icon dropped\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon left test-icon\"></span>
            [[TITLE]] [[RESULT_STRING]] ([[DURATION]])
        </p>
        <div id=\"iterations-[[UUID]]\" class=\"iterations\" style=\"display: block\">
            [[ITERATIONS]]
        </div>
    </div>
  """
    
  static let testGroup = """
    <div class=\"[[ITEM_CLASS]] [[ICON_CLASS]]\">
        <span class=\"icon left test-result-icon\"></span>
        <p>
            <span class=\"icon left drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon left test-icon\"></span>
            [[TITLE]] ([[DURATION]])
        </p>
        [[SUB_TESTS]]
    </div>
  """

  static let iteration = """
    <div class=\"iteration [[ICON_CLASS]]\">
        <span class=\"icon left test-result-icon\"></span>
        <p class=\"list-item\">
            <span class=\"icon left drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
            <span class=\"icon left test-icon\"></span>
            [[TITLE]] ([[DURATION]])
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
      <span class=\"icon left drop-down-icon\" onclick=\"toggle(this, '[[UUID]]')\"></span>
      [[TITLE]]
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
    <span class=\"icon left screenshot-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    [[NAME]]
    <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showScreenshot(this.getAttribute('data'))\"></span>
    <img class=\"screenshot\" src=\"[[SOURCE]]\" id=\"screenshot-[[FILENAME]]\" alt=\"[[NAME]]\" loading=\"lazy\"/>
  </p>
  """

  static let gif = """
  <p class="attachment list-item">
    <span class="icon left screenshot-icon" style="margin-left: [[PADDING]]px"></span>
    [[NAME]]
  <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showGif(this.getAttribute('data'))\"></span>
    <img class=\"gif\" src=\"[[SOURCE]]\" id=\"gif-[[FILENAME]]\" alt=\"[[NAME]]\" loading=\"lazy\"/>
  </p>
  """

  static let video = """
  <p class=\"attachment list-item\">
    <span class=\"icon left video-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    [[NAME]]
    <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showVideo(this.getAttribute('data'))\"></span>
    <video class=\"video\" controls src=\"[[SOURCE]]\" id=\"video-[[FILENAME]]\" preload=\"none\"/>
  </p>
  """

  static let text = """
  <p class=\"attachment list-item\">
    <span class=\"icon left text-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    [[NAME]]
    <span class=\"icon preview-icon\" data=\"[[SOURCE]]\" onclick=\"showText(this.getAttribute('data'))\"></span>
  </p>
  """

  static let link = """
  <p class=\"attachment list-item\">
    <span class=\"icon left text-icon\" style=\"margin-left: [[PADDING]]px\"></span>
    [[NAME]]
    <span class=\"icon preview-icon\" data=\"[[FILENAME]]\" onclick=\"showLinkAttachment(this.getAttribute('data'))\"></span>
    <a class=\"file-attachment-link\" href=\"[[SOURCE]]\" id=\"file-attachment-[[FILENAME]]\"></a>
  </p>
  """
}
