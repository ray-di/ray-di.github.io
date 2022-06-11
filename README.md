# Ray.Di user's guide

### Hosting and Rendering

The documentations are rendered with  [Jekyll](http://jekyllrb.com) and hosted at http://ray-di.github.io/.

### Install jekyll via docker

```
docker pull jekyll/jekyll:pages
```

### Start local testing server

```
git clone git@github.com:ray-di/ray-di.github.io.git
cd ray-di.github.io
./bin/serve.sh
```

### Troubleshooting

If the following error occurs, you can substitute `docker compose up`.

```
ruby 3.1.1p18 (2022-02-18 revision 53f5fc4236) [x86_64-linux-musl]
Configuration file: /srv/jekyll/_config.yml
            Source: /srv/jekyll
       Destination: /srv/jekyll/_site
 Incremental build: disabled. Enable with --incremental
      Generating... 
                    done in 3.192 seconds.
 Auto-regeneration: enabled for '/srv/jekyll'
<internal:/usr/local/lib/ruby/site_ruby/3.1.0/rubygems/core_ext/kernel_require.rb>:85:in `require': cannot load such file -- webrick (LoadError)
	from <internal:/usr/local/lib/ruby/site_ruby/3.1.0/rubygems/core_ext/kernel_require.rb>:85:in `require'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve/servlet.rb:3:in `<top (required)>'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve.rb:184:in `require_relative'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve.rb:184:in `setup'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve.rb:102:in `process'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve.rb:93:in `block in start'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve.rb:93:in `each'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve.rb:93:in `start'
	from /usr/gem/gems/jekyll-3.9.2/lib/jekyll/commands/serve.rb:75:in `block (2 levels) in init_with_program'
	from /usr/gem/gems/mercenary-0.3.6/lib/mercenary/command.rb:220:in `block in execute'
	from /usr/gem/gems/mercenary-0.3.6/lib/mercenary/command.rb:220:in `each'
	from /usr/gem/gems/mercenary-0.3.6/lib/mercenary/command.rb:220:in `execute'
	from /usr/gem/gems/mercenary-0.3.6/lib/mercenary/program.rb:42:in `go'
	from /usr/gem/gems/mercenary-0.3.6/lib/mercenary.rb:19:in `program'
	from /usr/gem/gems/jekyll-3.9.2/exe/jekyll:15:in `<top (required)>'
	from /usr/gem/bin/jekyll:25:in `load'
	from /usr/gem/bin/jekyll:25:in `<main>'
```

Open http://localhost:4000/
