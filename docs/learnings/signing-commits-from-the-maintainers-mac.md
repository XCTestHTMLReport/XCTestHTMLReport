# Signing and pushing from the maintainer's Mac

The global git config there signs commits through 1Password
(`gpg.ssh.program` is `op-ssh-sign`), and fetches and pushes over SSH through
the same agent. When an agent runs, 1Password is usually locked, so a plain
`git commit` or `git push` hangs on an unlock prompt nobody will answer.

Agents do not wait for it, never commit unsigned, and never change git config.
They sign with the agent key, inline, on every commit:

```bash
git -c gpg.format=ssh -c user.signingkey=~/.ssh/git-agent-signing.pub \
    -c gpg.ssh.program=ssh-keygen -c commit.gpgsign=true commit ...
```

and fetch and push over HTTPS with `gh`'s token, leaving the remote alone:

```bash
git fetch https://github.com/XCTestHTMLReport/XCTestHTMLReport.git main
git push https://github.com/XCTestHTMLReport/XCTestHTMLReport.git HEAD:<branch>
```

Then confirm GitHub verified the pushed commit:

```bash
gh api repos/XCTestHTMLReport/XCTestHTMLReport/commits/<sha> --jq .commit.verification
```

This applies only on that machine; contributors sign however they like.
