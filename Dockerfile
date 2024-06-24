FROM node:14.18.2-bullseye-slim

RUN mkdir /cogentapp
COPY . /cogentapp


WORKDIR /cogentapp


RUN npm install

RUN npm run build

EXPOSE 3000

CMD [ "npm", "start" ]
