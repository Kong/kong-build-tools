ARG RESTY_IMAGE_BASE="kong"
ARG RESTY_IMAGE_TAG="xenial"

FROM kong:openresty-${RESTY_IMAGE_TAG}

WORKDIR /kong

RUN apt-get update \
  && apt-get install -y --no-install-recommends libssl-dev

COPY entrypoint.sh /entrypoint.sh

CMD ["/entrypoint.sh"]

FROM ubuntu:xenial

COPY --from=0 /tmp/build /tmp/build

RUN apt-get update \
  && apt-get install -y --no-install-recommends ruby ruby-dev rubygems lsb-release libffi-dev build-essential

RUN gem install --no-ri --no-rdoc fpm

COPY fpm-entrypoint.sh /fpm-entrypoint.sh

CMD ["/fpm-entrypoint.sh"]