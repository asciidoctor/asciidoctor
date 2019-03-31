## About to create a new Github Issue?

We appreciate that. But before you do, please learn our basic rules:

* This is not a support forum. If you have a question, please go to [The Cukes Google Group](http://groups.google.com/group/cukes).
* Do you have an idea for a new feature? Then don't expect it to be implemented unless you or someone else sends a [pull request](https://help.github.com/articles/using-pull-requests). You might be better to start a discussion on [the google group](http://groups.google.com/group/cukes).
* Reporting a bug? Please tell us:
  * which version of Cucumber you're using
  * which version of Ruby you're using.
  * How to reproduce it. Bugs with a failing test in a [pull request](https://help.github.com/articles/using-pull-requests) get fixed much quicker. Some bugs may never be fixed.
* Want to paste some code or output? Put \`\`\` on a line above and below your code/output. See [GFM](https://help.github.com/articles/github-flavored-markdown)'s *Fenced Code Blocks* for details.
* We love [pull requests](https://help.github.com/articles/using-pull-requests). But if you don't have a test to go with it we probably won't merge it.

# Contributing to Cucumber

The rest of this document is a guide for those maintaining Cucumber, and others who would like to submit patches.

## Talking with other devs

You can chat with the core team on https://gitter.im/cucumber/cucumber. We try to have office hours on Fridays.

## Note on Patches/Pull Requests

* Fork the project. Make a branch for your change.
* Make your feature addition or bug fix.
* Make sure your patch is well covered by tests. We don't accept changes to Cucumber that aren't tested.
* Please do not change the Rakefile, version, or history.
  (if you want to have your own version, that is fine but
  bump version in a commit by itself so we can ignore when we merge your change)
* Send us a pull request.

## Running tests

    gem install bundler
    bundle install
    bundle exec rake

    To get code coverage results, run `bundle exec rake cov`

## Release Process

* Bump the version number in `lib/cucumber/platform.rb`.
* Make sure `History.md` is updated with the upcoming version number, and has entries for all fixes.
* No need to add a `History.md` header at this point - this should be done when a new change is made, later.
* Make sure you have up-to-date and clean copy of cucumber/cucumber.github.com.git at the same level as cucumber repo.

Now release it

    bundle update
    bundle exec rake
    git commit -m "Release X.Y.Z"
    rake release

## Gaining Release Karma

To become a release manager, create a pull request adding your name to the list below, and include your Rubygems email address in the ticket. One of the existing Release managers will then add you.

Current release managers:
  * [Matt Wynne](https://rubygems.org/profiles/mattwynne)
  * [Aslak Hellesøy](https://rubygems.org/profiles/aslakhellesoy)
  * [Oleg Sukhodolsky](https://rubygems.org/profiles/os97673)
  * [Steve Tooke](https://rubygems.org/profiles/tooky)
  * [Björn Rasmusson](https://rubygems.org/profiles/brasmusson)

To grant release karma, issue the following commands:

    gem owner cucumber --add <NEW OWNER RUBYGEMS EMAIL>
    gem owner cucumber-core --add <NEW OWNER RUBYGEMS EMAIL>
