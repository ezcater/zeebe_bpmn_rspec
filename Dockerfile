FROM ruby:2.6.6
RUN mkdir /usr/src/gem
WORKDIR /usr/src/gem
ADD . /usr/src/gem
