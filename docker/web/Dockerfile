FROM node:18 AS build

COPY web-client /app
workdir /app

RUN --mount=type=cache,target=/app/node_modules \
	npm ci && \
	npm run build:prod

FROM nginx:1.23 AS run

COPY --from=build /app/dist /var/www/html

COPY docker/web/nginx.conf /etc/nginx/conf.d/default.conf
