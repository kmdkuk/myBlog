FROM jekyll/jekyll

ENV APP_HOME /usr/src/app
RUN mkdir -p ${APP_HOME}/_site
WORKDIR $APP_HOME

ADD Gemfile Gemfile
ADD Gemfile.lock Gemfile.lock

RUN bundle install

ADD _config.yml _config.yml
ADD ./_site ${APP_HOME}/_site
