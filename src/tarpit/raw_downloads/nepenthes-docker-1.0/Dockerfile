FROM alpine:3.22

# Stuff needed for further steps
RUN apk add build-base
RUN apk add curl

# Dependency for Lua libraries
RUN apk add openssl

# Lua core runtime
RUN apk add lua5.4 lua5.4-dev luarocks5.4 

# Lua dependencies for Nepenthes
RUN apk add lua5.4-cqueues lua5.4-ossl lua5.4-lpeg lua5.4-lzlib

# Tarpitting data
RUN apk add words

#
# Nepenthes install
#
RUN <<EOF
	mkdir -p /usr/nepenthes
	cd /usr
	curl -o ./latest.tar.gz -L https://zadzmo.org/downloads/nepenthes/latest
	tar -xvzf ./latest.tar.gz --strip-components 1 -C ./nepenthes
	rm latest.tar.gz
EOF

#
# Sadly this Lua C module isn't in apk. Only one missing to build the
# container without any calls to Luarocks at all, which would also
# drop a lot from the Docker image.
#
# (Yes, I know about Luaposix. Switching to this eliminated a lot of
# fiddly problems I was having, especially on NetBSD.)
#
RUN luarocks-5.4 install lunix

# Volume setup
VOLUME /vol/nepenthes
RUN <<EOF
	adduser -D nepenthes
	chown nepenthes /var/run
	mkdir -p /vol/nepenthes
	chown nepenthes /vol/nepenthes
EOF

COPY config.yaml /vol/nepenthes/config.yml

# And run the tarpit
USER nepenthes
EXPOSE 8893
WORKDIR /usr/nepenthes

ENV LUA_APP_LOCATION="/usr/nepenthes"
ENV LUA_APP_BOOTSTRAP="/usr/nepenthes/core/bootstrap.lua"
CMD ["sh", "/usr/nepenthes/nepenthes", "/vol/nepenthes/config.yml"]
