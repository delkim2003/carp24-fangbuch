FROM node:22-slim
WORKDIR /app
COPY dist/ ./dist/
COPY package.json ./
COPY package-lock.json ./
RUN npm ci --omit=dev
EXPOSE 4321
ENV HOST=0.0.0.0
ENV PORT=4321
CMD ["node", "dist/server/entry.mjs"]
