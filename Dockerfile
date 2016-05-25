FROM greedy:latest

ADD src/ /usr/src/greedy/src

RUN ls src/
RUN npm test
