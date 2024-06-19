FROM node:14.18.2-bullseye-slim

WORKDIR /usr/src/app

COPY package.json tsconfig.json /usr/src/app/
COPY src /usr/src/app/src

RUN npm install

RUN npm run build

EXPOSE 3000

CMD [ "npm", "start" ]
