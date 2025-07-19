# Ray.Di user's guide

### Hosting and Rendering

The documentations are rendered with  [Jekyll](http://jekyllrb.com) and hosted at http://ray-di.github.io/.

### Start Server with Docker

```
./bin/serve_docker.sh
```

### Start Server in local Ruby environment

* Requires Ruby 3.2.3 (Notice: It's [not or later](https://stackoverflow.com/questions/77851863/bundle-exec-jekyll-serve-not-working-locally))

#### Install
```
gem install jekyll bundler
bundle install
```

#### Run
```
./bin/serve_local.sh
```
