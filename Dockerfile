FROM alpine:3.20

# nginx        - web server
# fcgiwrap     - FastCGI wrapper that execs CGI scripts
# spawn-fcgi   - binds a socket and forks fcgiwrap behind it
# zsh          - shebang interpreter for gitc.sh
# git          - used by gitc.sh (git rev-parse, etc.)
RUN apk add --no-cache \
        nginx \
        fcgiwrap \
        spawn-fcgi \
        zsh \
        git \
        git-daemon

RUN apk add --no-cache --virtual .build-deps build-base cmake git \
    && git clone --depth 1 https://github.com/github/cmark-gfm.git /tmp/cmark-gfm \
    && cd /tmp/cmark-gfm \
    && mkdir build && cd build \
    && cmake -DCMARK_TESTS=OFF -DCMARK_STATIC=OFF .. \
    && make -j"$(nproc)" \
    && make install \
    && cd / && rm -rf /tmp/cmark-gfm \
    && apk del .build-deps

# nginx runs as this user by default on Alpine; fcgiwrap needs to run
# as the same user so file permissions line up
ARG APP_USER=nginx

RUN mkdir -p /run/nginx /var/www/cgi-bin /home/welp/gitc/repos \
    && chown -R ${APP_USER}:${APP_USER} /home/welp /var/www/cgi-bin

COPY nginx.conf /etc/nginx/http.d/default.conf
COPY src/gitc.sh /var/www/cgi-bin/gitc.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /var/www/cgi-bin/gitc.sh /entrypoint.sh \
    && chown ${APP_USER}:${APP_USER} /var/www/cgi-bin/gitc.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
