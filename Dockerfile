FROM ruby:alpine AS builder
MAINTAINER knechaev@wallarm.com

COPY wlrm_support_bot /opt/wlrm_support_bot
RUN apk -U add make g++ mysql-dev \
  && cd /opt/wlrm_support_bot \
  && bundle install

FROM ruby:alpine
RUN apk add --no-cache mariadb-client-libs
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY wlrm_support_bot /opt/wlrm_support_bot
WORKDIR /opt/wlrm_support_bot
CMD ["bundle", "exec", "ruby", "main.rb"]

	
	


	

