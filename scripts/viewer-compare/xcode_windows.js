// Lists Xcode's on-screen windows as JSON, including the CGWindowID that
// `screencapture -l` needs. AppleScript cannot see a CGWindowID at all — the
// System Events window object exposes position and size but no window number —
// so this reaches CGWindowListCopyWindowInfo through JXA's ObjC bridge.
//
// JXA rather than a Swift helper on purpose: osascript is already a dependency
// of the Xcode side, while a .swift file in this repository would be linted by
// SwiftFormat and SwiftLint in CI for no benefit.
//
// Usage: osascript -l JavaScript xcode_windows.js [ownerName]
// Prints a JSON array of {id, x, y, width, height, title, layer}, ordered
// front to back, restricted to layer 0 (normal document windows — this filters
// out Xcode's tooltips, popovers and sheets, which would otherwise be picked
// up as "the new window" right after a bundle opens).

ObjC.import('CoreGraphics');
ObjC.import('Foundation');

function run(argv) {
    const owner = argv.length > 0 ? argv[0] : 'Xcode';

    // kCGWindowListOptionOnScreenOnly (1) | kCGWindowListExcludeDesktopElements (16).
    // The named constants come back undefined through the JXA bridge, so the
    // literal values are used with the names recorded here.
    const ref = $.CGWindowListCopyWindowInfo(1 | 16, 0);
    const list = ObjC.castRefToObject(ref);

    const windows = [];
    for (let i = 0; i < list.count; i++) {
        const w = ObjC.deepUnwrap(list.objectAtIndex(i));
        if (w.kCGWindowOwnerName !== owner) continue;
        if (w.kCGWindowLayer !== 0) continue;
        const b = w.kCGWindowBounds;
        windows.push({
            id: w.kCGWindowNumber,
            x: b.X,
            y: b.Y,
            width: b.Width,
            height: b.Height,
            title: w.kCGWindowName || '',
            layer: w.kCGWindowLayer,
        });
    }
    return JSON.stringify(windows);
}
