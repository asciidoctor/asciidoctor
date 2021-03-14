#!/bin/sh

for test in *-runner.sh
do
  ./$test
done

git diff *-sample.html
