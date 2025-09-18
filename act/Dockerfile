FROM ghcr.io/catthehacker/ubuntu:act-24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libyaml-dev \
    zlib1g-dev \
    libgmp-dev \
    buildah \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Ruby from source
ENV RUBY_VERSION=3.4.5
RUN wget https://cache.ruby-lang.org/pub/ruby/3.4/ruby-$RUBY_VERSION.tar.gz && \
    tar -xzvf ruby-$RUBY_VERSION.tar.gz && \
    cd ruby-$RUBY_VERSION && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf ruby-$RUBY_VERSION ruby-$RUBY_VERSION.tar.gz

ENV HOME=/home
WORKDIR /app
COPY ./Gemfile Gemfile
RUN gem install bundler -v 2.6.9
RUN bundle install
