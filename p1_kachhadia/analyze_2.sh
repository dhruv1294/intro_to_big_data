#!/bin/bash

# analyze.sh - Clones a repo, diffs branches, and uses a containerized Ollama to summarize.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
REPO_URL="git@git.doit.wisc.edu:cdis/cs/courses/cs544/misc/calculator.git"
REPO_DIR="calculator"
PROMPT_FILE="prompt.txt"
CONTAINER_NAME="ollama-server" # The name of your running container

# --- Main Script ---
echo "--- Starting analysis script. ---"

# Check if the Ollama container is running
if ! docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: The Ollama container '${CONTAINER_NAME}' is not running."
    echo "Please start it with: docker run -d -p 11434:11434 --name ${CONTAINER_NAME} p1-ollama"
    exit 1
fi
echo "Ollama container '${CONTAINER_NAME}' is running."

# Clean up from previous runs
echo "Cleaning up old files..."
rm -rf "$REPO_DIR" "$PROMPT_FILE"

# Clone the repository
echo "Cloning repository from $REPO_URL..."
git clone --quiet "$REPO_URL"

# Navigate into the repository directory
cd "$REPO_DIR"

# Generate the prompt file
echo "Generating prompt file (../$PROMPT_FILE)..."
# 1. Use '>' to create the file with the initial instruction
echo "Summarize the following code diff:" > "../$PROMPT_FILE"
# 2. Use '>>' to append the git diff output to the file
git diff origin/main origin/fix >> "../$PROMPT_FILE"

echo "Prompt file created. Sending to Ollama container..."

# Use cat and a pipe to send the prompt to the Ollama instance inside the Docker container
cat "../$PROMPT_FILE" | docker exec -i "$CONTAINER_NAME" ollama run gemma3:1b

echo "--- Analysis complete. ---"

