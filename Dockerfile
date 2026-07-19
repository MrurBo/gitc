FROM alpine:3.20
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

ARG CHROMA_VERSION=2.27.0
RUN apk add --no-cache ca-certificates \
    && wget -O /tmp/chroma.tar.gz \
         "https://github.com/alecthomas/chroma/releases/download/v${CHROMA_VERSION}/chroma-${CHROMA_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/chroma.tar.gz -C /usr/local/bin chroma \
    && chmod +x /usr/local/bin/chroma \
    && rm /tmp/chroma.tar.gz

ARG APP_USER=nginx
RUN mkdir -p /run/nginx /var/www/cgi-bin /home/welp/gitc/repos \
    && chown -R ${APP_USER}:${APP_USER} /home/welp /var/www/cgi-bin
COPY nginx.conf /etc/nginx/http.d/default.conf
COPY src/gitc.zsh /var/www/cgi-bin/gitc.zsh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /var/www/cgi-bin/gitc.sh /entrypoint.sh \
    && chown ${APP_USER}:${APP_USER} /var/www/cgi-bin/gitc.zsh
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
