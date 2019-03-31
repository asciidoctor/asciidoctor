Release Process
===============

* Bump the version number in `lib/cucumber/core/version.rb`
* Update `HISTORY.md` is updated with the upcoming version number and entries
  for all changes recorded.
* Now release it

```
bundle update
bundle exec rake
git commit -m "Release X.Y.Z"
rake release
```
