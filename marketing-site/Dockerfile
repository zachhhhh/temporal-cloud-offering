FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
ENV BUILD_ADAPTER=node
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app

COPY --from=builder /app/build ./build
COPY --from=builder /app/package*.json ./

# Only install production dependencies
RUN npm ci --omit=dev

ENV NODE_ENV=production
ENV PORT=3002
ENV ORIGIN=https://temporal.cloud

EXPOSE 3002
CMD ["node", "build"]
