FROM node:24-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

ARG NEXT_PUBLIC_BACKEND_URL
ENV NEXT_PUBLIC_BACKEND_URL=$NEXT_PUBLIC_BACKEND_URL

COPY . .

RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]