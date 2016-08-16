# Docker build Tasks

A VSTS build task that helps you build and release Docker containers. It is [free and open source](https://github.com/Lambda3/vsts-build-task-docker).

This build task offers special treatment to SSH connected services, such as the Azure Container Services.

## How to use it

The build task works best if you follow a simple convention. You should:

* Build the Dockerfile
* Push it to Docker Hub (optionally)
* Compose it

We do not offer a run command.

Ideally, you should have work done during the build, where you build your project and your Dockerfile, and then push it to the Docker Hub. The pushed image is your main artifact.

Then, you will have a release prepared. It will only use the pushed image, from the Docker Hub, to compose new services, maybe with several images.

## The environment

The `environment` will affect the Dockerfile that is used during build. If you select `Debug`, the build task will search for `Dockerfile`, otherwise it will search for `Dockerfile.<environment>`.

For the compose action, the same rule applies, it will use `docker-compose.yml` for `Debug`, and `docker-compose.<environment>.yml` for any other environment.

The default is always Debug.

## Building the image

You will need to supply the following arguments:

* An image name (required);
* A build context (optional, defaults to the root directory);
* A working directory (optional);
* An environment (optional).

Building this image will create an artifact named `docker` that will contain your Docker files, Docker compose files, and the image version. They can be used later during compose.

## Pushing the image

You only need to inform the image name. Remember to use an name that you own on the Docker hub.

The build agent is expected to be logged on the Docker Hub. For more info on the build agent see bellow on the "Build Agent" section.

## Composing the agent

You will need to supply the following arguments:

* The compose directory (required). Here you will use the saved artifact from the build phase.
* Project name (optional), otherwise the directory name is used. You want to set this, otherwise the project will end up being named `docker`.
* SSH info (optional). If you use any, you have to supply all of them.
    * Server name: FQDN or IP;
    * port;
    * user;
    * key.

You most likely want to supply the SSH information, otherwise the containers will be created on the build server.

This is specially usefull for use with the Azure Container Service.

The SSH key should be a private key, joined in one line, and, where the line break would be, add a textual `\n`. Remember to add the SSH Key to a [secure variable](https://www.visualstudio.com/en-us/docs/release/author-release-definition/more-release-definition#release-definition-variables) on the release settings. On the SSH key settings, place it within quotes, like this: `"$(SSH_KEY)"`.

## Debugging errors

If you set the variable `system.debug` to `true` you will get a lot of additional debug info.

## Reporting issues

Check out the [Github issues](https://github.com/Lambda3/vsts-build-task-docker/issues) directly.

## Build agent

You can use any build agent that is logged on the Docker Hub. We suggest you run the agent as a container using [giggio/vsts-agent](https://hub.docker.com/r/giggio/vsts-agent/) as a base image for the agent.
