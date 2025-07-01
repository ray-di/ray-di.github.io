FROM ruby:3.2

RUN apt-get update && apt-get install -y \
    build-essential \
    libffi-dev

RUN gem install bundler webrick

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy scripts
COPY bin/copy_markdown_files.sh /app/bin/
COPY bin/entrypoint.sh /app/bin/

EXPOSE 4000

# Make scripts executable
RUN chmod +x /app/bin/copy_markdown_files.sh /app/bin/entrypoint.sh

# Create a non-root user for security
RUN groupadd -r jekyll && useradd -r -g jekyll jekyll
RUN chown -R jekyll:jekyll /app
USER jekyll

CMD ["/app/bin/entrypoint.sh"]
