FROM ruby:2.1.5-slim

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y postgresql-9.4 supervisor redis-server git ssh vim curl nodejs libcurl4-openssl-dev libpq-dev build-essential libxml2-dev libxslt1-dev nginx
RUN mkdir -p /var/log/supervisor
RUN echo "alias ll='ls -alh'" >> /etc/bash.bashrc

# setup nginx
#RUN echo "\ndaemon off;" >> /etc/nginx/nginx.conf && chown -R www-data:www-data /var/lib/nginx

ENV RAILS_ENV production
ENV APP_PATH /var/www/errbit

COPY ./ $APP_PATH/current/

WORKDIR $APP_PATH
RUN useradd -s /bin/bash -m errbit

RUN chown -R errbit:errbit $APP_PATH

# allow user errbit
RUN sed -i '88i host all root 127.0.0.1/32 trust' /etc/postgresql/9.4/main/pg_hba.conf
RUN sed -i '88i host all errbit 127.0.0.1/32 trust' /etc/postgresql/9.4/main/pg_hba.conf

USER root
COPY config/supervisord/supervisord.conf /etc/supervisor/conf.d/errbit.conf
RUN sed -i '406i maxmemory 512mb' /etc/redis/redis.conf

USER postgres
RUN /etc/init.d/postgresql start &&\
  /usr/lib/postgresql/9.4/bin/createuser -s -d -r -e errbit &&\
  /usr/lib/postgresql/9.4/bin/createdb -O errbit errbit_production

WORKDIR $APP_PATH/current
USER errbit
RUN bundle install --without development:test --deployment
RUN echo "Errbit::Application.config.secret_token = '$(bundle exec rake secret)'" > $APP_PATH/current/config/initializers/__secret_token.rb
RUN mkdir $APP_PATH/current/tmp
RUN mkdir $APP_PATH/current/log

USER root
WORKDIR $APP_PATH/current
RUN /etc/init.d/postgresql start && su errbit -c 'bin/rake db:migrate db:seed assets:precompile RAILS_ENV=production'

# finalize
# Add VOLUMEs to allow backup of config, logs and databases
VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql", "/var/lib/redis"]
RUN rm -rf /var/lib/apt/lists/*

CMD ["/usr/bin/supervisord"]

# docker run -d --net host --name errbit errbit
