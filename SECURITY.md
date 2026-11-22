# Security Policy

## Reporting a vulnerability

Please report security problems privately, not in a public issue. On this
repository's **Security** tab, choose **Report a vulnerability**
([direct link](https://github.com/XCTestHTMLReport/XCTestHTMLReport/security/advisories/new)).
That opens a private report only the maintainers can see.

Include the `xchtmlreport --version` output, the command you ran, and the
smallest result bundle or input that shows the problem.

## What counts

`xchtmlreport` turns the contents of an `.xcresult` bundle into HTML that people
open in a browser, so the main concern is content from a bundle ending up in the
report as markup or script: test names, failure messages, device names,
attachment names, logs. Anything else that lets a crafted bundle do more than
produce a report, such as writing files outside the output directory, counts too.

If you are not sure whether something is a security problem, report it privately
anyway.

## Supported versions

Fixes go into the latest release.
