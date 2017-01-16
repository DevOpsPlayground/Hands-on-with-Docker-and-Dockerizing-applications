# Dockerizing Applications - DevOps Playground #9

## Requirements
1. [Vagrant](https://www.vagrantup.com)
2. [Virtualbox](https://www.virtualbox.org/)

## Summary
"Dockerizing" an application can be described as enabling an application to run in a container based environment such as Docker or Kubernetes. Applications can be purpose built to run in a Docker environment or existing applications can be retrofitted.

In this meetup, we will 'Dockerize' a simple Gitbook website. We will begin by using Docker to Serve the book and then we will improve this to separate out our Build steps from our Deployment steps.

## 0 - Setting up

To get started, install the requirements listed at the top. Once you have them,
clone or download this repository, `cd` into it and type `vagrant up`. This might
take a few minutes the first time around.

Once the VM is ready, type `vagrant ssh` into your terminal and you will be
logged into the VM.

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
be grouped together to save on the number of layers (\*see below) created.

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

We've actioned most of the above complaints here. We've merged the `RUN` directives
into one and tidied up the `/tmp` folder after. We also now make use of the
`ENTRYPOINT` directive, which is generally best practise. Finally we've also
made sure our statements are in a more sane order, going from least entropy
(changes infrequently) to most entropy (changes often) from top to bottom.

_\* What's a layer? Think of it like a Git Commit, it contains a list of changes
that can be used to build an image. Images can share these layers, like branches
can share a common commit._

## 4 - Why serve when we can build?

As mentioned in the last section, currently this container is using a pretty
slow and wasteful method of serving the book to us. Let's fix that by using
gitbook to build our book for us into static HTML, which we can then serve
in any HTTP server.

```
FROM node:argon-slim
MAINTAINER Your Name <your@email.com>

RUN npm install -g gitbook && npm install -g gitbook-cli && gitbook install \
&& rm -rf /tmp/* && mkdir /mybook

VOLUME /mybook
WORKDIR /mybook

ENTRYPOINT ["/usr/local/bin/gitbook"]
CMD ["build"]
```

As you might see, not a huge amount seems to have changed. That said, the effect
is that this container will no longer serve the site, nor will it have a copy
of the files inside it.We have added `&& mkdir /mybook` to the end of the `RUN`
block, just to ensure it exists.

We no longer `COPY` the source files in, now we have a `VOLUME` directive.
This tells Docker that the contents of this folder is going to be stored outside
of the container, meaning that data inside of it will persist between `docker run`
commands. The purpose of this is so that we keep our source out of the container
and do not need to rebuild this every time our code changes. It also means this
container could be used to build multiple books from different projects!

(For more on this, please look [here](./BuildContainers.md))

So, let's build the image:
* `sudo docker build -t 'builders/gitbook' .`

And then let's build our book:
* `sudo docker run --rm -v ${PWD}/mybook:/mybook 'builders/gitbook'`
* `-v` tells Docker to mount the specified directory into the container

And finally, let's inspect the output:
* `ls -la ./mybook/_book`

You should (hopefully) see the markdown has been compiled into static HTML!
This is perfect, we can now put this inside an nginx container to serve our
HTML for us.

## 5 - Let's nginx-ify this

Imagine thousands of users look at this book on a dailt basis, we probably
want some robust load balancing. nginx is a good choice for hosting our site,
and while load-balancing is out of scope for this meetup, we can certainly get
nginx up and running in the most basic sense.

We have two options, we can either keep the code separate from the container
as with our builder above, or we can bake it in. Which option we take really
depends on how concerned we are with the portability of the container.

If we bake it in, the container can run anywhere easily but needs to be built
every time we make a change (as well as compiling our HTML). If we keep the
source out of the container, it needs to aleady be on whatever host we use
to run the container.

### Option 1 - Keep them separate

This is the easiest option to demo, all we need to do is run an nginx container,
bind the HTTP port to the host and mount the source code inside the container.

Let's try:
* `sudo docker run -d -p 80:80 -v ${PWD}/mybook/_book/*:/usr/share/nginx/html:ro 'nginx:latest'`
* `-d` tells Docker to run this container as a daemon in the background
* Check the site out by visiting `http://localhost`

This method is useful if our source changes very regularly and is being ran
from the same host, particularly in instances such as local development.

Before moving on, make sure to tidy up your old containers:
* `sudo docker rm -f $(sudo docker ps -aq)`
* Beware that this will remove all containers, else just remove the nginx container

### Option 2 - Bake it baby!

The more 'Docker' method here is to bake the code in, we want our container to be
built and ran anywhere without hassle, configuration or downloading multiple sources.

To do this, we need another Dockerfile. Call this one `Dockerfile.nginx`:
```
FROM nginx:1.11.8-alpine
MAINTAINER Your Name <your@name.com>

COPY mybook/_book/* /usr/share/nginx/html/
```

This is nice and simple, we don't need to do anything extra here as the original
container already exposes ports and sets up an entrypoint. All we have to do
is add in our code!

Let's build:
* `sudo docker build -t 'mynginx/mybook' -f Dockerfile.nginx .`
* This will save the source code inside it, so we don't need to provide it elsewhere

Let's run:
* `sudo docker run -d -p 80:80 'mynginx/mybook'`
* As before, let's check it out on `http://localhost`

## Conclusion

It doesn't really take much to 'Dockerize' an application, the bigger effort is
making sure that you make full use of the capabilities Docker provides you. Most
applications should just need to have their binaries/source placed in a container
with minimal heavy lifting needed. Otherwise, as ever Google is your friend -
it's almost certain someone has already done what you're looking to do and probably
has a container for that!
