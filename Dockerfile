FROM ruby:3.2

RUN apt-get update && apt-get install -y \
    build-essential \
    libffi-dev

RUN gem install bundler webrick

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the markdown copy script
COPY bin/copy_markdown_files.sh /app/bin/

EXPOSE 4000

# Create an entrypoint script
RUN echo '#!/bin/bash\n\
bundle exec jekyll build\n\
./bin/copy_markdown_files.sh\n\
bundle exec jekyll serve --host 0.0.0.0 --watch' > /app/entrypoint.sh && \
chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]