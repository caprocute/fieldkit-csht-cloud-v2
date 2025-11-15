# Release Procedure

1. Open `pubspec.yaml` and locate `version:` field.
2. Increment version and build-number, for example: `3.0.2+13` becomes `3.0.3+14`. All app stores require a unique build number for each binary uploaded. So if a problem occurs after uploading a binary, it'll be necessary to update this number again. See below.
3. Save changes to `pubspec.yaml`
4. Create a new release branch: `git checkout -b release/3.0.3`. 
5. Commit changes to `pubspec.yaml`: `git commit -av -m "rel: Releasing 3.0.3"`
6. Merge release branch into `main` branch:

```
git checkout main
git merge --no-ff release/3.0.3
````

7. Push main branch: `git push`
8. At this point you can wait for the CI system to build a binary and upload them to the store.
9. If the binaries are accepted, you can merge the release branch into `develop` as well:

```
git checkout develop
git merge --no-ff release/3.0.3
```

10. If the binary is rejected or needs extra work, it's acceptable to commit to the release branch, or commit to `develop` and merge those changes into the release branch. It's also important to remember to increment the build number, though. It isn't necessary to update the version.
