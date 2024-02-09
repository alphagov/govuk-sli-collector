ARG ruby_version=3.3
FROM ghcr.io/alphagov/govuk-ruby-builder:$ruby_version

COPY Gemfile* .ruby-version ./
RUN bundle install
COPY . .
USER app

CMD ["./collect"]
