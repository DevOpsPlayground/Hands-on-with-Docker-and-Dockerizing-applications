FROM node:argon-slim
MAINTAINER Your Name <your@email.com>

RUN npm install -g gitbook && npm install -g gitbook-cli && gitbook install \
&& rm -rf /tmp/*

COPY ./mybook /mybook
WORKDIR /mybook
EXPOSE 4000

ENTRYPOINT ["/usr/local/bin/gitbook"]
CMD ["serve"]
