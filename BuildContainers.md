# Build Containers

The following was originally in our main page, however went too far off topic.
However, I feel it worth discussing here for those interested:

Putting together a container that can _build_ our code for us completely decouples
our code from the environment being used to build it. One host can now have
every version of Java, Go, Maven or whatever on hand to build your application.
No worrying about whether the code will compile in Java 8 or not, you can just
use a different base image (e.g. `FROM java:7`). You don't even need to use
a different repository in your registry, as you will see for the Java repository
each tag is a different Java version (`java:7, java:8, java:8-u101`).

Now put this in the context of a CI/CD tool such as Jenkins. Gone are the
2-3 Jenkins instances with different versions of Java, Maven and whatever else
installed. All we need is a Jenkins host that has the docker-engine installed
and Bob's your uncle, all the build environments you need right at your finger-tips!
