#!/bin/sh

docker run --rm --platform linux/amd64 --volume="$PWD:/srv/jekyll" -it -p 4000:4000 jekyll/jekyll:pages jekyll serve
