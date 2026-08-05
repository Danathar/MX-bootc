# Contributing

Please keep changes focused: one improvement-plan task per pull request, with the reason for the change and its rollback boundary in the description.

Before opening a pull request, run `just check` and `just lint`. For image changes, run the smallest applicable local build (`just build` or `just build-qcow2`) and include the result. Changes to boot behavior should include the relevant boot smoke-test output when CI has run it.

When reporting a runtime problem, include:

- `bootc status --json` (or `bootc status` if JSON is unavailable)
- `bootc version`
- `systemctl --failed`
- `journalctl -b -p warning..alert --no-pager`
- hardware details relevant to the failure

Do not include secrets, private keys, or unredacted user data in issues or pull requests.
