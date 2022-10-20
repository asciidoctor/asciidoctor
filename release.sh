#!/bin/bash

# required packages (for ubuntu:kinetic): curl git jq ruby

if [ -z "$RELEASE_RUBYGEMS_API_KEY" ]; then
  echo No API key specified for publishing to rubygems.org. Stopping release.
  exit 1
fi
export RELEASE_BRANCH=${GITHUB_REF_NAME:-main}
if [ ! -v RELEASE_USER ]; then
  export RELEASE_USER=$GITHUB_ACTOR
fi
RELEASE_GIT_NAME=$(curl -s https://api.github.com/users/$RELEASE_USER | jq -r .name)
RELEASE_GIT_EMAIL=$RELEASE_USER@users.noreply.github.com
GEMSPEC=$(ls -1 *.gemspec | head -1)
RELEASE_GEM_NAME=$(ruby -e "print (Gem::Specification.load '$GEMSPEC').name")
# RELEASE_VERSION must be an exact version number; if not set, defaults to next patch release
if [ -z "$RELEASE_VERSION" ]; then
  export RELEASE_VERSION=$(ruby -e "print (Gem::Specification.load '$GEMSPEC').version.then { _1.prerelease? ? _1.release.to_s : (_1.segments.tap {|s| s[-1] += 1 }.join ?.) }")
fi
export RELEASE_GEM_VERSION=${RELEASE_VERSION/-/.}

# configure git to push changes
git config --local user.name "$RELEASE_GIT_NAME"
git config --local user.email "$RELEASE_GIT_EMAIL"

# configure gem command for publishing
mkdir -p $HOME/.gem
echo -e "---\n:rubygems_api_key: $RELEASE_RUBYGEMS_API_KEY" > $HOME/.gem/credentials
chmod 600 $HOME/.gem/credentials

# release!
(
  set -e
  ruby tasks/version.rb
  git commit -a -m "release $RELEASE_VERSION"
  git tag -m "version $RELEASE_VERSION" v$RELEASE_VERSION
  mkdir -p pkg
  gem build $GEMSPEC -o pkg/$RELEASE_GEM_NAME-$RELEASE_GEM_VERSION.gem
  git push origin $(git describe --tags --exact-match)
  gem push pkg/$RELEASE_GEM_NAME-$RELEASE_GEM_VERSION.gem
  ruby tasks/release-notes.rb
  gh release create v$RELEASE_VERSION -t v$RELEASE_VERSION -F pkg/release-notes.md -d
  ruby tasks/postversion.rb
  git commit -a -m 'prepare branch for development [no ci]'
  git push origin $RELEASE_BRANCH
)
exit_code=$?

# nuke gem credentials
rm -rf $HOME/.gem

git status -s -b

exit $exit_code
