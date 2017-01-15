# Dockerizing Applications - DevOps Playground #9

## Requirements
1. Vagrant
2. Virtualbox

## Summary
"Dockerizing" an application can be described as enabling an application to run in a container based environment such as Docker or Kubernetes. Applications can be purpose built to run in a Docker environment or existing applications can be retrofitted.

In this meetup, we will 'Dockerize' a simple Gitbook website. We will begin by using Docker to Serve the book and then we will improve this to separate out our Build steps from our Deployment steps.

## 1 - Our Dockerfile

Every Dockerized application needs at least one Dockerfile, this will describe the steps necessary to create our container image.

```
FROM node:latest
MAINTAINER Your Name <your@email.com>

ADD ./mybook /mybook

CMD ["/bin/bash"]
```

The above Dockerfile does the following:
  1. Pulls the `node:latest` image
  2. Copies the gitbook to the container
  3. Tells the container to run bash on start

So next we need to build it:
* `sudo docker built -t 'mybook' .`

And then we can run it to check our files are there:
* `sudo docker run --rm -it 'mybook'`
* `ls -la /mybook`

When you're done, exit the container. No need to remove it, the `--rm` in the
run command did that for us! We also specified `-it`, meaning we're likely
to interact with the container via terminal.
This is a basic first container, however it doesn't really do much right now,
all we do is put our files onto the container. Nonetheless, this is a good first
step.

## 2 - Serving the book

The next step is to serve our Gitbook. The easiest way to do this is by using
Gitbook's built in webserver, which will dynamically reload pages as they change.
Handy for development!

```
FROM node:latest
MAINTAINER Your Name <your@email.com>

ADD ./mybook /mybook
RUN npm install -g gitbook
RUN npm install -g gitbook-cli
RUN gitbook install

WORKDIR /mybook
EXPOSE 4000

CMD ["/usr/local/bin/gitbook", "serve"]
```

So what's changed here? Firstly, we've added in a `RUN` directive to execute
`npm` and install Gitbook. We've also specified a `WORKDIR`, this is where everything
in the container takes place by default. To serve our book we also need to `EXPOSE`
a port to allow incomming connections. Finally, we need to serve our book and have
modified our `CMD` directive to reflect this.

Let's build our image again and then run it:
* `sudo docker built -t 'mybook' .`
* `sudo docker run --rm -p 4000:4000 'mybook'`
* Visit the book in your browser: http://localhost:4000

This is great progress, now that we have our book being served we can look to
improve the Dockerfile, because right now it is attrocious!

## 3 - Improving our Dockerfile

Our last Dockerfile flaunted best practise, this not only makes our images less
manageable but can also severely impact build time and the total size of the
final image.

We could run it through a Linter such as [FROM:LATEST](https://www.fromlatest.io/)
or use one in our IDE, however this Dockerfile isn't really big enough for that.

So let's list everything wrong with this image:
1. `FROM node:latest` - The `latest` tag is awful and should never be used in a
Dockerfile. How do we know what we're getting between builds?
2. `ADD` - As our source is not a URL or a tarball we should use COPY
([see here for further reference](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#/add-or-copy))
3. `RUN` - We have multiple run commands that perform similar tasks. These should
be grouped together to save on the number of layers created.
4. `CMD` - There are very few situations where simply using this directive is
the best choice. Instead we should be using `ENTRYPOINT` with a `CMD` directive
to pass default parameters.
5. The ordering of our `ADD` and `RUN` statements means that changing the book's source
will trigger the RUN statement's caches to be invalidated, and so they will run again.
(You can observe this by creating a new file inside `mybook` and rebuilding the image.
6. We don't clean up after our `npm install` actions and so are wasting space.
7. `gitbook serve` is fine for development, however we'd be better off building
the contents and serving them using something like nginx.

So let's take a look at our improved Dockerfile:
```
FROM node:argon-slim
MAINTAINER Your Name <your@email.com>

RUN npm install -g gitbook && npm install -g gitbook-cli && gitbook install \
&& rm -rf /tmp/*

COPY ./mybook /mybook
WORKDIR /mybook
EXPOSE 4000

ENTRYPOINT ["/usr/local/bin/gitbook"]
CMD ["serve"]
```
