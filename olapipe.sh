#!/usr/bin/env bash

# ollamaPipe: Send a prompt to an Ollama server running on port 11434 and stream the response.

function usage() {
  echo "Usage: $0 -m|--message \"Prompt text\" [-llm|--model \"model_name\"] [-v|--verbose] [-c|--copy]"
  exit 1
}

# Defaults
prompt=""
model="deepseek-r1:1.5b"
verbose=false
copy_to_clipboard=false

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
    -c|--copy)
      copy_to_clipboard=true
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

# Create a temporary file to store output if copying to clipboard
if $copy_to_clipboard; then
  temp_output=$(mktemp)
fi

# Function to handle text output with proper newline handling
output_text() {
  local text="$1"
  local target="$2"  # Can be "stdout", "clipboard", or "both"
  
  # Process the text to properly handle newlines
  if [[ "$target" == "stdout" || "$target" == "both" ]]; then
    printf "%s" "$text"
  fi
  
  if [[ "$target" == "clipboard" || "$target" == "both" ]]; then
    printf "%s" "$text" >> "$temp_output"
  fi
}

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
      if $copy_to_clipboard; then
        output_text "${line}\n" "both"
      else
        output_text "${line}\n" "stdout"
      fi
    elif [[ "$line" =~ ^data:\ (.*) ]]; then
      json_part="${BASH_REMATCH[1]}"

      # Attempt to extract the chunk of text from .choices[0].text
      text_chunk=$(echo "$json_part" | jq -r '.choices[0].text // ""' 2>/dev/null)
      
      # Handle output target based on clipboard flag
      if $copy_to_clipboard; then
        output_text "$text_chunk" "both"
      else
        output_text "$text_chunk" "stdout"
      fi
      
      # If the chunk ends with a newline character, print it
      if [[ "$text_chunk" =~ \\n$ || "$text_chunk" =~ \n$ ]]; then
        echo
        if $copy_to_clipboard; then
          echo >> "$temp_output"
        fi
      fi
    else
      if $copy_to_clipboard; then
        output_text " " "both"
      else
        output_text " " "stdout"
      fi
    fi
done

# If you'd like a final newline in non-verbose mode:
if ! $verbose; then
  echo
  if $copy_to_clipboard; then
    echo >> "$temp_output"
  fi
fi

# Copy to clipboard if requested
if $copy_to_clipboard; then
  cat "$temp_output" | pbcopy
  rm "$temp_output"
  echo "Output copied to clipboard!"
fi