FROM jekyll/minimal

ENV APP_HOME /usr/src/app
ENV TZ=Asia/Tokyo
RUN mkdir -p ${APP_HOME}/_site
WORKDIR $APP_HOME

ADD Gemfile Gemfile
ADD Gemfile.lock Gemfile.lock

RUN apk update && \
    apk add --no-cache libxml2-dev curl-dev make gcc libc-dev g++ && \
    bundle install && \
    rm -rf /usr/local/bundle/cache/* /usr/local/share/.cache/* /var/cache/* /tmp/* && \
    apk del libxml2-dev curl-dev make gcc libc-dev g++

ADD _config.yml _config.yml
ADD ./_site ${APP_HOME}/_site

EXPOSE 4000

CMD ["jekyll","serve","--host 0.0.0.0","--port 4000", "--no-watch","--skip-initial-build"]
