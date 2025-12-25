#!/bin/bash


# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
REPO_URL="https://git.doit.wisc.edu/cdis/cs/courses/cs544/misc/calculator.git"
REPO_DIR="calculator"
PROMPT_FILE="prompt.txt"
LOG_FILE="ollama.log"

# --- Main Script ---
echo "--- Starting analysis script. ---"

# Clean up from previous runs
echo "Cleaning up old files..."
rm -rf "$REPO_DIR" "$PROMPT_FILE" "$LOG_FILE"

# Start the Ollama server in the background, redirecting all output to a log file
echo "Starting Ollama server in the background (logging to $LOG_FILE)..."
ollama serve &> "$LOG_FILE" &
OLLAMA_PID=$!

# Set a trap to automatically kill the server process when the script exits
# This ensures no orphaned processes are left running.
trap 'echo "Stopping Ollama server (PID: $OLLAMA_PID)..."; kill $OLLAMA_PID 2>/dev/null || true' EXIT

# Wait for the Ollama server to become responsive
echo "Waiting for Ollama server to be ready..."
# Give the server a moment to start before polling
sleep 5
#while ! curl -s -f http://localhost:11434/ > /dev/null; do
#    echo -n "."
#    sleep 1
#done
echo " Ollama server is running."

# Clone the repository
echo "Cloning repository from $REPO_URL..."
git clone --quiet "$REPO_URL"

# Navigate into the repository directory and fetch remote branches
cd "$REPO_DIR"
echo "Fetching remote branches..."
git fetch --quiet origin fix

# Generate the prompt file
echo "Generating prompt file (../$PROMPT_FILE)..."
echo "Summarize the following code diff:" > "../$PROMPT_FILE"
git diff main..origin/fix >> "../$PROMPT_FILE"
echo "Prompt file created. Sending to Ollama..."

# Use cat and a pipe to send the prompt to Ollama for summarization
cat "../$PROMPT_FILE" | ollama run gemma3:1b

echo "--- Analysis complete. ---"

