FROM elixir:1.14 AS build

COPY app /app
WORKDIR /app

ENV MIX_ENV=prod
ENV HEX_HOME=/app/.hex
ENV MIX_HOME=/app/.mix
RUN --mount=type=cache,target=/app/deps \
	--mount=type=cache,target=/app/_build/prod/lib \
	--mount=type=cache,target=/app/.hex \
	--mount=type=cache,target=/app/.mix \
	mix local.hex --force && \
	mix local.rebar --force && \
	mix deps.get && \
	mix release

FROM debian:11 AS run

ENV LANG=en_US.UTF-8

RUN apt-get update && \
	apt-get install -y openssl locales && \
	# https://stackoverflow.com/a/43522172
	echo "$LANG UTF-8" > /etc/locale.gen && \
	locale-gen && \
	update-locale LANG="$LANG" && \
	useradd pillminder && \
	mkdir /var/lib/pillminder /etc/pillminder && \
	chown pillminder:pillminder /var/lib/pillminder /etc/pillminder



USER pillminder

COPY --from=build --chown=pillminder:pillminder /app/_build/prod/rel/prod /app
COPY docker/app/entrypoint.sh /entrypoint.sh

VOLUME /etc/pillminder
VOLUME /var/lib/pillminder

CMD ["/entrypoint.sh"]
