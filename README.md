RakeGem
=======

# DESCRIPTION

Ever wanted to manage your RubyGem in a sane way without having to resort to
external dependencies like Jeweler or Hoe? Ever thought that Rake and a hand
crafted gemspec should be enough to deal with these problems? If so, then
RakeGem is here to make your life awesome!

RakeGem is not a library. It is just a few simple file templates that you can
copy into your project and easily customize to match your specific needs. It
ships with a few Rake tasks to help you keep your gemspec up-to-date, build
a gem, and release your library and gem to the world.

RakeGem assumes you are using Git. This makes the Rake tasks easy to write. If
you are using something else, you should be able to get RakeGem up and running
with your system without too much editing.

The RakeGem tasks were inspired by the
[Sinatra](http://github.com/sinatra/sinatra) project.

# INSTALLATION

Take a look at `Rakefile` and `NAME.gemspec`. For new projects, you can start
with these files and edit a few lines to make them fit into your library. If
you have an existing project, you'll probably want to take the RakeGem
versions and copy any custom stuff from your existing Rakefile and gemspec
into them. As long as you're careful, the rake tasks should keep working.

# ASSUMPTIONS

RakeGem makes a few assumptions. You will either need to satisfy these
assumptions or modify the rake tasks to work with your setup.

You should have a file named `lib/NAME.rb` (where NAME is the name of your
library) that contains a version line. It should look something like this:

    module NAME
      VERSION = '0.1.0'
    end

It is important that you use the constant `VERSION` and that it appear on a
line by itself.

# UPDATING THE VERSION

In order to make a new release, you'll want to update the version. With
RakeGem, you only need to do that in the `lib/NAME.rb` file. Everything else
will use this find the canonical version of the library.

# TASKS

RakeGem provides three rake tasks:

`rake gemspec` will update your gemspec with the latest version (taken from
the `lib/NAME.rb` file) and file list (as reported by `git ls-files`).

`rake build` will update your gemspec, build your gemspec into a gem, and
place it in the `pkg` directory.

`rake release` will update your gemspec, build your gem, make a commit with
the message `Release 0.1.0` (with the correct version, obviously), tag the
commit with `v0.1.0` (again with the correct version), and push the `master`
branch and new tag to `origin`.

Keep in mind that these are just simple Rake tasks and you can edit them
however you please. Don't want to auto-commit or auto-push? Just delete those
lines. You can bend RakeGem to your own needs. That's the whole point!