# syntax=docker/dockerfile:1

FROM ruby:3.4-alpine@sha256:c5a5064d190055633011c03aa800170cc36945ff3afb5f6c915329f92d6f1e00 AS runtime

WORKDIR /app

RUN apk upgrade --no-cache \
    && apk add --no-cache --virtual .resolv-build-deps build-base=0.5-r4 \
    && gem install resolv --version 0.7.2 --no-document \
    && apk del .resolv-build-deps \
    && rm -rf \
        /usr/local/lib/ruby/3.4.0/resolv.rb \
        /usr/local/lib/ruby/gems/3.4.0/gems/resolv-0.7.1 \
        /usr/local/lib/ruby/gems/3.4.0/specifications/default/resolv-0.7.1.gemspec \
    && ruby -rresolv -e 'abort unless Gem.loaded_specs.fetch("resolv").version.to_s == "0.7.2"'

RUN addgroup -S -g 10001 patches && adduser -S -u 10001 -G patches patches

COPY --chown=patches:patches --chmod=0555 cmd/brew-patches.rb /app/cmd/brew-patches
COPY --chown=patches:patches stacks /app/stacks

ARG BUILD_VERSION=local
ARG BUILD_REVISION=unknown

LABEL org.opencontainers.image.title="4evy patches" \
      org.opencontainers.image.description="Read-only patch stack browser" \
      org.opencontainers.image.source="https://github.com/4evy/patches" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.revision="${BUILD_REVISION}"

USER 10001:10001

ENTRYPOINT ["ruby", "/app/cmd/brew-patches"]
CMD ["list"]
