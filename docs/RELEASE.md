# Release 1.0.0

The Xcode app target uses marketing version **1.0.0**, build **1**. The
[release notes](RELEASE_NOTES_1.0.0.md) describe the first release. This
checklist covers preparation; it is not a statement that a release has shipped.

- [x] Build both targets and run the local Mac and iPad simulator suites (see [verification](VERIFICATION.md)).
- [x] Capture and review current Mac and iPad simulator screenshots.
- [ ] Test on a physical iPad and the oldest supported OS versions.
- [ ] Finish manual keyboard focus and compact multitasking checks. Verify each
      system file picker and export on the release devices.
- [ ] Compare exported ASE/ACO, SVG, and tokens against target consumers.
- [ ] Verify transparent export and Vision subject isolation on supported
      hardware.
- [ ] Enable private security reporting on the public repository.
- [ ] Run the GitHub Actions checks after the source is pushed.
- [ ] Review the release notes and tag the reviewed commit as `v1.0.0`.

## Source distribution

From the repository root with [GitHub CLI](https://cli.github.com/manual/gh_repo_create)
installed:

```sh
git init -b main   # only needed in a directory without Git metadata
git add .
git commit -m "Prepare CoStudio 1.0.0"
gh auth login
gh repo create CoStudio --public --source=. --remote=origin --push
gh release create v1.0.0 --draft --title "CoStudio 1.0.0" \
  --notes-file docs/RELEASE_NOTES_1.0.0.md
```

Inspect the draft in GitHub before publishing. If distributing source only,
GitHub creates source archives from the tag. If the repository name already
exists, set its URL as `origin` and push the committed `main` branch instead.

## Binary distribution

- **Mac:** In Xcode, select a signing team and archive **Any Mac**. For direct
  downloads, distribute a Developer ID signed and notarized build. Test the
  resulting file on a separate Mac. A simulator or development build is not
  a distribution artifact.
- **iPad:** Select a team, set your own bundle identifier if required by your
  team, choose the generic iPadOS device destination, and archive. Use
  TestFlight or App Store Connect for distribution after validation.
