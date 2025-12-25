# AI Usage in Part 2

### Q1. What prompt did you use to generate the initial Dockerfile? (1 point)

```
Can you help me write a Dockerfile named "Dockerfile.ollama" that can be built like this:

docker build -f Dockerfile.ollama -t p1-ollama .

It should start from the latest LTS version of Ubuntu. Inside the image, you should have ollama installed, with the "gemma3:1b" model already pulled.

Can you also explain how to install, run, and prompt ollama.
```

### Q2. What contents for the Dockerfile did in initially suggest? (2 points)

```
# Use the latest Ubuntu LTS as the base image
FROM ubuntu:22.04

# Set environment variables to non-interactive to prevent prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install curl and ca-certificates
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama using the official installation script
RUN curl -fsSL https://ollama.com/install.sh | sh

# Pull the gemma3:1b model into the image during the build process
# This makes the model immediately available when a container is started.
RUN ollama pull gemma3:1b

# Expose the default port Ollama listens on
EXPOSE 11434

# Set up a healthcheck to verify the Ollama server is running
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:11434/ || exit 1

# The default command to run when the container starts. This starts the Ollama server.
CMD ["ollama", "serve"]


```

### Q3. Was there anything in the recommended file that was unusual, new to you, or not taught in class? (3 points)

* I found two new commands that were new to me:
  * ```EXPOSE 11434``` 
    This command exposes the default port that Ollama listens on and we could specifically expose the required ports from the dockerfile itself for security purposes which was kind of interesting to know.
  * ```HEALTHCHECK --interval=5m --timeout=3s CMD curl -f http://localhost:11434/ || exit 1```
    I did not know that we can actually have a health check functionality that checks if the server is running fine or not at every specified interval. ```docker ps``` will show the status of this command as healthy or unhealthy based on the command execution, which was again kind of nice to know! 
    

### Q4. For the example you gave above, how did you verify what Gemini suggested is correct? (4 points)

I ran the below docker build command to verify the dockerfile, if it goes fine then the dockerfile would be syntactically correct at least.
```
docker build -f Dockerfile.ollama -t p1-ollama .
```
This command was mentioned in the P1 readme file as well, however in my first prompt to Gemini, I even asked on the guide to install, run and prompt Ollama, so it gave me below guide file as well:
```
How to Use Your Ollama Docker Image
This guide will walk you through building the Docker image, running the container, and interacting with the gemma3:1b model.

1. Build the Docker Image
First, you need to build the image from the Dockerfile.ollama file. Navigate to the directory containing the Dockerfile in your terminal and run the following command:

docker build -f Dockerfile.ollama -t p1-ollama .

docker build: The command to build a Docker image.

-f Dockerfile.ollama: Specifies the name of the Dockerfile to use.

-t p1-ollama: Assigns a "tag" or name (p1-ollama) to your image for easy reference.

.: Represents the build context, which is the current directory.

2. Run the Ollama Container
Once the image is built, you can run it as a container. This command will start the Ollama server in the background.

docker run -d -p 11434:11434 --name ollama-server p1-ollama

docker run: The command to start a new container.

-d: Detached mode. Runs the container in the background.

-p 11434:11434: Port mapping. It maps port 11434 on your host machine to port 11434 inside the container, allowing you to communicate with the Ollama server.

--name ollama-server: Assigns a convenient name to your running container.

p1-ollama: The name of the image to create the container from.

You can check if the container is running with docker ps.

3. Prompt the Model
There are two primary ways to interact with the model running inside the container.

Method A: Interactive Command Line
You can "enter" the container and chat with the model directly.

Execute the run command:

docker exec -it ollama-server ollama run gemma3:1b

docker exec: Executes a command in a running container.

-it: Allocates an interactive terminal.

Start prompting: You will see a prompt like >>>. You can now type your questions and press Enter.

>>> Why is the sky blue?

The sky appears blue to us because of a phenomenon called Rayleigh scattering...

Exit: Type /bye to exit the session.

Method B: Using the REST API (with curl)
Ollama also provides a REST API. You can send requests to it from your host machine's terminal using a tool like curl.

curl http://localhost:11434/api/generate -d '{
  "model": "gemma3:1b",
  "prompt": "Why is the sky blue?",
  "stream": false
}'

This command sends a request to the Ollama API endpoint and will return a JSON object with the model's complete response.

4. Stop and Clean Up
When you are finished, you can stop and remove the container to free up resources.

# Stop the container
docker stop ollama-server

# Remove the container
docker rm ollama-server
```

This guide looked convincing enough to carry forward with the testing.

However, the docker build command failed on the first run itself! Steps to fix and followup prompts are answered in Q5.

### Q5. What is something that you had to fix or simplify about Gemini's original output? (4 points)

When I ran the docker build command on the initial dockerfile suggested by Gemini, it gave me below error:
```
=> ERROR [4/4] RUN ollama pull gemma3:1b                                                                                                                                                              0.2s 

------                                                                                                                                                                                                      

 > [4/4] RUN ollama pull gemma3:1b:                                                                                                                                                                         

0.182 Error: ollama server not responding - could not connect to ollama server, run 'ollama serve' to start it                                                                                              

------                                                                                                                                                                                                      

Dockerfile.ollama:18                                                                                                                                                                                        

--------------------

  16 |     # Pull the gemma3:1b model into the image during the build process

  17 |     # This makes the model immediately available when a container is started.

  18 | >>> RUN ollama pull gemma3:1b

  19 |     

  20 |     # Expose the default port Ollama listens on

--------------------

ERROR: failed to build: failed to solve: process "/bin/sh -c ollama pull gemma3:1b" did not complete successfully: exit code: 1
```

I pasted this same error in the Gemini prompt, and it updated the docker file for me with the fix for this and it gave me below explanation for the same:
```
The error ollama server not responding happens because the ollama pull command needs the Ollama server to be running, but each RUN command in a Dockerfile executes in a separate shell, so the server isn't active when the pull command is executed.

To fix this, we need to start the server, wait for it to become responsive, and then run the pull command, all within a single RUN instruction.
```

It updated the RUN command in my dockerfile with below:
```
# Pull the gemma3:1b model into the image during the build process.
# We must start the server in the background, wait for it to be ready,
# and then run the pull command, all in the same RUN layer.
RUN nohup ollama serve & \
    && while ! curl -s -f http://localhost:11434/ > /dev/null; do echo "Waiting for Ollama server..."; sleep 1; done \
    && ollama pull gemma3:1b
```
I ran docker build command again, and it failed once again but this time it failed with a shell syntax error:
```
 => ERROR [4/4] RUN nohup ollama serve &     && while ! curl -s -f http://localhost:11434/ > /dev/null; do echo "Waiting for Ollama server..."; sleep 1; done     && ollama pull gemma3:1b             0.2s

------                                                                                                                                                                                                      

 > [4/4] RUN nohup ollama serve &     && while ! curl -s -f http://localhost:11434/ > /dev/null; do echo "Waiting for Ollama server..."; sleep 1; done     && ollama pull gemma3:1b:

0.133 /bin/sh: 1: Syntax error: "&&" unexpected

------

Dockerfile.ollama:19

--------------------

  18 |     # and then run the pull command, all in the same RUN layer.

  19 | >>> RUN nohup ollama serve & \

  20 | >>>     && while ! curl -s -f http://localhost:11434/ > /dev/null; do echo "Waiting for Ollama server..."; sleep 1; done \

  21 | >>>     && ollama pull gemma3:1b

  22 |     

--------------------

ERROR: failed to build: failed to solve: process "/bin/sh -c nohup ollama serve &     && while ! curl -s -f http://localhost:11434/ > /dev/null; do echo \"Waiting for Ollama server...\"; sleep 1; done     && ollama pull gemma3:1b" did not complete successfully: exit code: 2
```

I again pasted this error to Gemini and it corrected the RUN command with the correct syntax now:
```
# Pull the gemma3:1b model into the image during the build process.
# We start the server in the background (&). The shell then immediately
# proceeds to the 'while' loop which waits for the server to be responsive
# before the 'ollama pull' command is executed.
RUN nohup ollama serve & \
    while ! curl -s -f http://localhost:11434/ > /dev/null; do echo "Waiting for Ollama server..."; sleep 1; done \
    && ollama pull gemma3:1b
```

Post this fix, the docker build command ran successfully and the image was built and appearing in my ```docker images``` output successfully

### Q6. After building the image, how did you verify the resulting Docker image works as intended? (6 points)

I followed the guide given by Gemini to check if the resulting docker image was working as expected:
I ran below command to run the container:
```
docker run -d -p 11434:11434 --name ollama-server p1-ollama
```
Post this I was able to see the container running in my ```docker ps``` command output.

Then, I went ahead with method A (Interactive Command Line) to prompt the model inside the container

```
docker exec -it ollama-server ollama run gemma3:1b
```
After running this command I was able to see an interactive shell popping up starting with ```>>>``` and I just entered a generic science question ```Why is the sky blue?``` and it started answering it.

This meant that the ollama server was running perfectly in my docker container and this is how I verified it. I have shared below output:
```
(venv) kachhadia@cs544-kachhadia:~/p1_kachhadia$ docker exec -it ollama-server ollama run gemma3:1b
>>> Why is the sky blue?
The sky is blue due to a phenomenon called **Rayleigh scattering**. Here's a breakdown of how it works:

**1. Sunlight Contains All Colors:**

* Sunlight appears white to us, but it’s actually made up of all the colors of the rainbow – red, orange, yellow, green, blue, indigo, and violet.

**2. Entering the Earth's Atmosphere:**

* As sunlight enters the Earth’s atmosphere, it bumps into tiny air molecules (mostly nitrogen and oxygen).

**3. Rayleigh Scattering:**

* **Rayleigh scattering** is the process where light is scattered by particles much smaller than its wavelength.  This is why the atmosphere scatters blue light more effectively than other colors.
* **Shorter wavelengths scatter more:**  Blue and violet light have shorter wavelengths than other colors.  They're easily bounced around in the air molecules.

**4. Why Mostly Blue, Not Violet?**

* Violet light is scattered even *more* than blue light. However, our eyes are more sensitive to blue light. Also, the sun emits slightly less violet light than blue light.
*  Therefore, we primarily see the scattered blue light that reaches our eyes.

**Think of it like this:** Imagine throwing a handful of small marbles (blue light) and a handful of larger rocks (red light) at a bumpy surface. The marbles will bounce around more easily and 
scatter in all directions.


**What about sunsets?**

When the sun is low on the horizon, sunlight has to travel through *much* more of the atmosphere to reach our eyes. This longer path means that almost all of the blue light is scattered away, 
leaving the longer wavelengths of orange and red to dominate the sky's colors.


---

**Resources for Further Learning:**

* **NASA - Rayleigh Scattering:** [https://science.nasa.gov/news/2014/1213/red-scattered-by-the-atmosphere/](https://science.nasa.gov/news/2014/1213/red-scattered-by-the-atmosphere/)
* **National Geographic - Why is the sky blue?:** [https://www.nationalgeographic.com/science/2017/07/why-is-the-sky-blue](https://www.nationalgeographic.com/science/2017/07/why-is-the-sky-blue)

Do you want to delve deeper into any specific aspect of this phenomenon, such as:

*   The role of clouds?
*   The science behind why sunsets are orange?

>>> 
Use Ctrl + d or /bye to exit.
>>> /bye
```
This full part seemed pretty interesting and got to learn a lot of things from this!

