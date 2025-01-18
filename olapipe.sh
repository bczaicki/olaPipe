#!/usr/bin/env bash

# ollamaPipe: Send a prompt to an Ollama server running on port 11434 and stream the response.

function usage() {
  echo "Usage: $0 -m|--message \"Prompt text\" [-llm|--model \"model_name\"] [-v|--verbose]"
  exit 1
}

# Defaults
prompt=""
model="llama3.2:latest"
verbose=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      prompt="$2"
      shift 2
      ;;
    -llm|--model)
      model="$2"
      shift 2
      ;;
    -v|--verbose)
      verbose=true
      shift
      ;;
    *)
      # Unknown option or missing argument
      usage
      ;;
  esac
done

# Ensure a prompt was provided
if [[ -z "${prompt}" ]]; then
  usage
fi

# ---------------------------------------------------------------------
# 1) Make the request with "stream": true so Ollama sends partial chunks
# 2) Use '-N' so curl doesn't buffer the response
# 3) Use '-s' to silence the progress bar
# 4) Read line by line from the streamed output
# ---------------------------------------------------------------------
curl -sN http://localhost:11434/v1/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"${prompt}\",
    \"model\": \"${model}\",
    \"stream\": true
  }" | while read -r line; do

    # Each line is a partial JSON object. For example:
    #   {"choices":[{"text":"Hello"}]}
    #
    # If you're in verbose mode, just print the raw chunk.
    # Otherwise, try to extract the .choices[0].text portion.
    if $verbose; then
      echo "${line}"
    elif [[ "$line" =~ ^data:\ (.*) ]]; then
      json_part="${BASH_REMATCH[1]}"

      # Attempt to extract the chunk of text from .choices[0].text
      text_chunk=$(echo "$json_part" | jq -r '.choices[0].text // ""' 2>/dev/null)
      # Print without a newline so text flows continuously
      printf "%s" "$text_chunk"
    else
      printf "%s" " "
    fi
done

echo # Print a newline at the end
      

# If you'd like a final newline in non-verbose mode:
if ! $verbose; then
  echo 
fi

