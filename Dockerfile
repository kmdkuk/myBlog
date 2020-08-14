FROM ruby:2.6.5-alpine as builder

ENV APP_HOME /usr/src/app
ENV TZ=Asia/Tokyo
RUN mkdir -p ${APP_HOME}/_site
WORKDIR $APP_HOME

COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

RUN apk update && \
    apk add --no-cache libxml2-dev curl-dev make gcc libc-dev g++ && \
    gem install bundler -v 1.17.2 && \
    bundle install -j$(getconf _NPROCESSORS_ONLN) && \
    rm -rf /usr/local/bundle/cache/* /usr/local/share/.cache/* /var/cache/* /tmp/* && \
    apk del libxml2-dev curl-dev make gcc libc-dev g++

COPY . ${APP_HOME}

CMD ["jekyll","build"]

FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /usr/src/app/_site /usr/share/nginx/html

EXPOSE 80

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
