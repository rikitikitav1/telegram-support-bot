FROM debian:stretch	
	MAINTAINER knechaev@wallarm.com

	ENV DEBIAN_FRONTEND noninteractive

	RUN apt-get update && apt-get upgrade -y 
	RUN apt-get install -y apt-utils \
	build-essential \
	mysql-client \
	default-libmysqlclient-dev \
	ruby-full \
	ruby-dev \
	rubygems \
	supervisor

	RUN mkdir -p /opt/wallarm-support-bot
	COPY wlrm_support_bot/Gemfile /opt/wallarm-support-bot/Gemfile
	COPY wlrm_support_bot/Gemfile.lock /opt/wallarm-support-bot/Gemfile.lock
	
	WORKDIR /opt/wallarm-support-bot

	RUN gem install bundler
	RUN bundle install
	
	COPY wlrm_support_bot /opt/wallarm-support-bot
 
	#WORKDIR /opt/wallarm-support-bot
	CMD ["bundle", "exec", "ruby", "main.rb"]



	
	


	

