Please read [CONTRIBUTING](https://github.com/cucumber/gherkin/blob/master/CONTRIBUTING.md) first.
You should clone the [cucumber/gherkin](https://github.com/cucumber/gherkin) repo if you want
to contribute.

## Run tests

### Using make

Just run `make` from this directory.

Even if you prefer `make` - run `rake` occasionally, as it reports better warnings.

### Using rake

Just run `rake` from this directory.

Keep in mind that this will only run unit tests. The acceptance tests are only
run when you build with `make`.

## Make a release

    # Change version in `gherkin.gemspec` and commit
    bundle exec rake build release
