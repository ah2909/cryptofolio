FROM node:24.22.2-alpine3.24@sha256:8a32c8cf649a49915a66e81e7a609223c708d0adabf288ee3f4077d765542f85 AS base
# npm 12.2.1 still bundles an affected Undici release.
RUN npm install --global npm@12.2.1 \
    && npm install --prefix /tmp/npm-security --no-package-lock --ignore-scripts --no-audit --no-fund undici@6.29.1 \
    && rm -rf /usr/local/lib/node_modules/npm/node_modules/undici \
    && cp -a /tmp/npm-security/node_modules/undici /usr/local/lib/node_modules/npm/node_modules/undici \
    && rm -rf /tmp/npm-security \
    && npm cache clean --force
WORKDIR /usr/src/app
COPY ./src/websocket/package*.json ./

FROM base AS dependencies
RUN npm ci --omit=dev && npm cache clean --force

FROM base AS development
RUN npm ci
COPY ./src/websocket/ .
EXPOSE 3003
CMD ["npm", "run", "dev"]

FROM base AS production
ENV NODE_ENV=production
COPY --from=dependencies /usr/src/app/node_modules ./node_modules
COPY ./src/websocket/ .
USER node
EXPOSE 3003
CMD ["node", "--max-old-space-size=384", "server.js"]
