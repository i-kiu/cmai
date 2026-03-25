#!/bin/bash

CONFIG_DIR="$HOME/.config/git-commit-ai"
CONFIG_FILE="$CONFIG_DIR/config"
MODEL_FILE="$CONFIG_DIR/model"
BASE_URL_FILE="$CONFIG_DIR/base_url"
PROVIDER_FILE="$CONFIG_DIR/provider"
COMMIT_STYLE_FILE="$CONFIG_DIR/commit_style"

# Debug mode flag
DEBUG=false
# Push flag
PUSH=false
# Message only flag
MESSAGE_ONLY=false
# Branch name flag
BRANCH_NAME_ONLY=false
# Unstaged flag
UNSTAGED=false
# Skip interactive commit confirmation (non-interactive / scripting)
SKIP_PROMPT=false

# When building the diff text used for the AI prompt/comment:
# ignore blank-line-only changes by default.
IGNORE_BLANK_LINES=true

# Commit message styles (default: TYPO3)
COMMIT_STYLE_TYPO3="typo3"
COMMIT_STYLE_CONVENTIONAL="conventional"
# Default providers and URLs
PROVIDER_OPENROUTER="openrouter"
PROVIDER_OLLAMA="ollama"
PROVIDER_LMSTUDIO="lmstudio"
PROVIDER_CUSTOM="custom"

OPENROUTER_URL="https://openrouter.ai/api/v1"
OLLAMA_URL="http://localhost:11434/api"
LMSTUDIO_URL="http://localhost:1234/v1"

# Default models for providers
OLLAMA_MODEL="codellama"
OPENROUTER_MODEL="google/gemini-flash-1.5-8b"
LMSTUDIO_MODEL="default"

# Debug function
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
        if [ ! -z "$2" ]; then
            echo "DEBUG: Content >>>"
            echo "$2"
            echo "DEBUG: <<<"
        fi
    fi
}

# Function to save API key
save_api_key() {
    mkdir -p "$CONFIG_DIR"
    # Remove any quotes or extra arguments from the API key
    API_KEY=$(echo "$1" | cut -d' ' -f1)
    echo "$API_KEY" >"$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    debug_log "API key saved to config file"
}

# Function to get API key
get_api_key() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo ""
    fi
}

# Function to save model
save_model() {
    echo "$1" >"$MODEL_FILE"
    chmod 600 "$MODEL_FILE"
    debug_log "Model saved to config file"
}

# Function to get model
get_model() {
    if [ -f "$MODEL_FILE" ]; then
        cat "$MODEL_FILE"
    else
        echo "" # Return empty string to let provider-specific default be used
    fi
}

# Function to save base URL
save_base_url() {
    echo "$1" >"$BASE_URL_FILE"
    chmod 600 "$BASE_URL_FILE"
    debug_log "Base URL saved to config file"
}

# Function to save provider
save_provider() {
    echo "$1" >"$PROVIDER_FILE"
    chmod 600 "$PROVIDER_FILE"
    debug_log "Provider saved to config file"
}

# Function to get provider
get_provider() {
    if [ -f "$PROVIDER_FILE" ]; then
        cat "$PROVIDER_FILE"
    else
        echo "$PROVIDER_OPENROUTER"
    fi
}

# Function to get base URL
get_base_url() {
    if [ -f "$BASE_URL_FILE" ]; then
        cat "$BASE_URL_FILE"
    else
        echo "$OPENROUTER_URL" # Default base URL
    fi
}

# Function to save commit message style (typo3 | conventional)
save_commit_style() {
    echo "$1" >"$COMMIT_STYLE_FILE"
    chmod 600 "$COMMIT_STYLE_FILE"
    debug_log "Commit style saved to config file"
}

# Function to get commit message style (default: typo3)
get_commit_style() {
    if [ -f "$COMMIT_STYLE_FILE" ]; then
        tr '[:upper:]' '[:lower:]' <"$COMMIT_STYLE_FILE" | tr -d '[:space:]'
    else
        echo "$COMMIT_STYLE_TYPO3"
    fi
}

normalize_commit_style() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" in
    typo3 | typo) echo "$COMMIT_STYLE_TYPO3" ;;
    conventional | standard) echo "$COMMIT_STYLE_CONVENTIONAL" ;;
    *) echo "$COMMIT_STYLE_TYPO3" ;;
    esac
}

# Function to print config
print_config() {
    echo "Current configuration:"
    echo "  Provider:    $(get_provider)"
    echo "  Base URL:    $(get_base_url)"
    echo "  Model:       $(get_model)"
    echo "  Commit style: $(normalize_commit_style "$(get_commit_style)")"
    API_KEY=$(get_api_key)
    if [ -z "$API_KEY" ]; then
        echo "  API Key:   Not set"
    else
        echo "  API Key:   ****"
    fi
}



# Load saved provider and base URL or use defaults
PROVIDER=$(get_provider)
BASE_URL=$(get_base_url)

# If no saved provider, use defaults
if [ -z "$PROVIDER" ]; then
    PROVIDER="$PROVIDER_OPENROUTER"
    BASE_URL="$OPENROUTER_URL"
fi

COMMIT_STYLE=$(normalize_commit_style "$(get_commit_style)")

# Get saved model or use default based on provider
MODEL=$(get_model)
if [ -z "$MODEL" ]; then
    case "$PROVIDER" in
    "$PROVIDER_OLLAMA")
        MODEL="$OLLAMA_MODEL"
        ;;
    "$PROVIDER_OPENROUTER")
        MODEL="$OPENROUTER_MODEL"
        ;;
    "$PROVIDER_LMSTUDIO")
        MODEL="$LMSTUDIO_MODEL"
        ;;
    esac
fi

# Get saved base URL or use default
BASE_URL=$(get_base_url)

debug_log "Script started"
debug_log "Config directory: $CONFIG_DIR"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
debug_log "Config directory created/checked"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --debug)
        DEBUG=true
        shift
        ;;
    --use-ollama)
        PROVIDER="$PROVIDER_OLLAMA"
        BASE_URL="$OLLAMA_URL"
        MODEL="$OLLAMA_MODEL"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        save_model "$MODEL"
        shift
        ;;
    --use-openrouter)
        PROVIDER="$PROVIDER_OPENROUTER"
        BASE_URL="$OPENROUTER_URL"
        MODEL="$OPENROUTER_MODEL"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        save_model "$MODEL"
        shift
        ;;
    --use-lmstudio)
        PROVIDER="$PROVIDER_LMSTUDIO"
        BASE_URL="$LMSTUDIO_URL"
        MODEL="$LMSTUDIO_MODEL"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        save_model "$MODEL"
        shift
        ;;
    --use-custom)
        if [ -z "$2" ]; then
            echo "Error: --use-custom requires a base URL"
            exit 1
        fi
        PROVIDER="$PROVIDER_CUSTOM"
        BASE_URL="$2"
        save_provider "$PROVIDER"
        save_base_url "$BASE_URL"
        shift 2
        ;;
    --push | -p)
        PUSH=true
        shift
        ;;
    --message-only)
        MESSAGE_ONLY=true
        shift
        ;;
    --branch-name-only)
        BRANCH_NAME_ONLY=true
        shift
        ;;
    --unstaged)
        UNSTAGED=true
        shift
        ;;
    --include-blank-lines)
        IGNORE_BLANK_LINES=false
        shift
        ;;
    --yes | -y)
        SKIP_PROMPT=true
        shift
        ;;
    --style)
        if [[ -n "$2" && "$2" != -* ]]; then
            COMMIT_STYLE=$(normalize_commit_style "$2")
            save_commit_style "$COMMIT_STYLE"
            debug_log "Commit style set to: $COMMIT_STYLE"
            shift 2
        else
            echo "Error: --style requires typo3 or conventional"
            exit 1
        fi
        ;;
    --print-config)
        print_config
        exit 0
        ;;
    -h | --help)
        echo "Usage: cmai [options] [api_key]"
        echo ""
        echo "Options:"
        echo "  --debug               Enable debug mode"
        echo "  --push, -p            Push changes after commit"
        echo "  --message-only        Generate message only, no git add/commit/push"
        echo "  --branch-name-only    Generate branch name only, no git add/commit/push"
        echo "  --unstaged            Use unstaged changes for diff"
        echo "  --include-blank-lines Include blank-line-only changes in diff"
        echo "  --style <name>        Commit format: typo3 (default) or conventional (saved)"
        echo "  --yes, -y             Commit without confirmation prompt"
        echo "  --model <model>       Use specific model (default: google/gemini-flash-1.5-8b)"
        echo "  --use-ollama          Use Ollama as provider (saves for future use)"
        echo "  --use-openrouter      Use OpenRouter as provider (saves for future use)"
        echo "  --use-lmstudio        Use LMStudio as provider (saves for future use)"
        echo "  --use-custom <url>    Use custom provider with base URL (saves for future use)"
        echo "  --print-config        Print the current config"
        echo "  -h, --help            Show this help message"
        echo ""
        echo "Examples:"
        echo "  cmai --api-key your_api_key          # First time setup with API key"
        echo "  cmai --use-ollama                    # Switch to Ollama provider"
        echo "  cmai --use-openrouter                # Switch back to OpenRouter"
        echo "  cmai --use-lmstudio                  # Switch to LMStudio provider"
        echo "  cmai --use-custom http://my-api.com  # Use custom provider"
        echo "  cmai --message-only                  # Generate message only, no commit"
        exit 0
        ;;
    --model)
        # Check if next argument exists and doesn't start with -
        if [[ -n "$2" && "$2" != -* ]]; then
            # Remove any quotes from model name and save it
            MODEL=$(echo "$2" | tr -d '"')
            save_model "$MODEL"
            debug_log "New model saved: $MODEL"
            shift 2
        else
            echo "Error: --model requires a valid model name"
            exit 1
        fi
        ;;
    --base-url)
        # Check if next argument exists and doesn't start with -
        if [[ -n "$2" && "$2" != -* ]]; then
            BASE_URL="$2"
            save_base_url "$BASE_URL"
            debug_log "New base URL saved: $BASE_URL"
            shift 2
        else
            echo "Error: --base-url requires a valid URL"
            exit 1
        fi
        ;;
    --api-key)
        # Check if next argument exists and doesn't start with -
        if [[ -n "$2" && "$2" != -* ]]; then
            save_api_key "$2"
            debug_log "New API key saved"
            shift 2
        else
            echo "Error: --api-key requires a valid API key"
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown argument $1"
        exit 1
        ;;
    esac
done

COMMIT_STYLE=$(normalize_commit_style "$(get_commit_style)")

# Get API key from config
API_KEY=$(get_api_key)
debug_log "API key retrieved from config"

if [ -z "$API_KEY" ] && [ "$PROVIDER" = "$PROVIDER_OPENROUTER" ]; then
    echo "No API key found. Please provide the OpenRouter API key using --api-key flag"
    echo "Usage: cmai [--debug] [--push|-p] [--use-ollama] [--model <model_name>] [--base-url <url>] [--api-key <key>]"
    exit 1
fi

# Set default model based on provider
if [ "$PROVIDER" = "$PROVIDER_OLLAMA" ]; then
    [ -z "$MODEL" ] && MODEL="$OLLAMA_MODEL"
    # Check if Ollama is running
    if ! pgrep ollama >/dev/null; then
        echo "Error: Ollama server not running. Please start Ollama first:"
        echo "ollama serve"
        exit 1
    fi
    # Check if model exists using ollama ls
    if ! ollama ls | awk '{print $1}' | grep -q "^${MODEL}$"; then
        echo "Error: Model '$MODEL' not found in Ollama. Please pull it first:"
        echo "ollama pull $MODEL"
        exit 1
    fi
fi

# Only stage changes and check for changes if not using message-only, branch-name mode, or unstaged mode
if [ "$MESSAGE_ONLY" = false ] && [ "$BRANCH_NAME_ONLY" = false ] && [ "$UNSTAGED" = false ]; then
    # Stage all changes
    debug_log "Staging all changes"
    git add .
fi

# Use a single, readable format for all providers (jq will handle JSON escaping)
DIFF_RANGE="--cached"
[ "$UNSTAGED" = true ] && DIFF_RANGE=""

NAME_STATUS_RAW=$(git diff $DIFF_RANGE --name-status)
# Get git diff for context
DIFF_CONTENT_RAW=$(git diff $DIFF_RANGE)

if [ "$IGNORE_BLANK_LINES" = true ]; then
    # Only keep file sections where there is at least one addition/deletion line
    # that is NOT just an empty/whitespace-only line.
    # This makes DIFF_CONTENT behave like `git diff --ignore-blank-lines` for prompts:
    # if a file change is "blank-line-only", it disappears from the prompt entirely.
    DIFF_CONTENT=$(printf '%s\n' "$DIFF_CONTENT_RAW" | awk '
        function is_blank_add_del(line) {
            return (line ~ /^[+-][[:space:]]*$/)
        }
        function is_nonblank_add_del(line) {
            # Ignore file headers like "--- a/file" and "+++ b/file"
            if (line ~ /^\+\+/) return 0
            if (line ~ /^--/) return 0
            if (line !~ /^[+-]/) return 0
            return !is_blank_add_del(line)
        }
        /^diff --git /{
            if (cur != "" && has_nonblank == 1) {
                printf "%s", content
            }
            cur = $3
            sub(/^a\//, "", cur)
            has_nonblank = 0
            content = $0 "\n"
            next
        }
        {
            if (is_nonblank_add_del($0)) has_nonblank = 1
            content = content $0 "\n"
        }
        END{
            if (cur != "" && has_nonblank == 1) {
                printf "%s", content
            }
        }
    ')

    if [ -n "$DIFF_CONTENT" ]; then
        # Build a keep-list from DIFF_CONTENT so CHANGES matches the files we kept.
        KEEP_LIST=$(printf '%s\n' "$DIFF_CONTENT" | awk '/^diff --git /{f=$3; sub(/^a\//,"",f); if(!seen[f]++){print f}}')
        CHANGES=$(printf '%s\n' "$NAME_STATUS_RAW" | awk -v keep_list="$KEEP_LIST" '
            BEGIN{
                n=split(keep_list,a,"\n");
                for (i=1; i<=n; i++) if (a[i]!="") keep[a[i]]=1;
            }
            {
                status=$1;
                file=$NF; # last field is the "new" filename for rename/copy
                gsub(/\r$/, "", file);
                if (file in keep) print status " " file;
            }')
    else
        CHANGES=""
    fi
else
    CHANGES=$(printf '%s\n' "$NAME_STATUS_RAW" | tr '\t' ' ' | sed 's/  */ /g')
    DIFF_CONTENT="$DIFF_CONTENT_RAW"
fi
debug_log "Git changes detected in range $DIFF_RANGE : $CHANGES"
debug_log "Git diff content: $DIFF_CONTENT"

if [ -z "$CHANGES" ]; then
    if [ "$UNSTAGED" = true ]; then
        echo "No relevant changes found (after filtering blank-line-only changes)."
    else
        echo "No relevant staged changes found (after filtering blank-line-only changes). Please stage your changes using 'git add' first or use --unstaged flag."
    fi
    exit 1
fi

# Set model based on provider if not explicitly specified
if [ -z "$MODEL" ]; then
    case "$PROVIDER" in
    "$PROVIDER_OLLAMA")
        MODEL="$OLLAMA_MODEL"
        ;;
    "$PROVIDER_OPENROUTER")
        MODEL="$OPENROUTER_MODEL"
        ;;
    "$PROVIDER_LMSTUDIO")
        MODEL="$LMSTUDIO_MODEL"
        ;;
    esac
fi

# Assemble the user prompt with raw content; jq will handle JSON escaping
# Note: use `read <<EOF` instead of `$(cat <<EOF)` so lines like `1)` or `type(scope):`
# do not close the command-substitution `)`.
if [ "$BRANCH_NAME_ONLY" = true ]; then
    IFS= read -r -d '' USER_CONTENT <<EOF || true
Generate a git branch name for these changes:

## File changes:
<file_changes>
$CHANGES
</file_changes>

## Diff:
<diff>
$DIFF_CONTENT
</diff>

## Format:
<type>/<short-description>

Important:
- Type must be one of: feat, fix, docs, style, refactor, perf, test, chore
- Short description: lowercase, hyphen-separated, max 50 chars
- Example: fix/api-error-handling or feat/new-login-page
- Do not wrap your response in triple backticks
- Response should be the branch name only, no explanations.
EOF
elif [ "$COMMIT_STYLE" = "$COMMIT_STYLE_TYPO3" ]; then
    IFS= read -r -d '' USER_CONTENT <<EOF || true
Generate a commit message for these changes. The subject line uses TYPO3-style tags
(inspired by https://docs.typo3.org/m/typo3/guide-contributionworkflow/main/en-us/Appendix/CommitMessage.html ),
but do NOT add Forge/Gerrit metadata: no "Resolves:", "Related:", "Releases:", or "Change-Id" lines.

## File changes:
<file_changes>
$CHANGES
</file_changes>

## Diff:
<diff>
$DIFF_CONTENT
</diff>

## Subject line (TYPO3-style tag + summary) — keep rules 1–3 below

1) Start the first line with exactly one keyword in square brackets: [BUGFIX], [FEATURE], [DOCS], or [TASK].
   If the change is breaking for users/admins/extension authors, prefix the whole line with [!!!]
   before the keyword, e.g. [!!!][FEATURE] ...
   Use [SECURITY] only for genuine security fixes.

2) After the keyword, one space, then a short summary in imperative mood (command form: "Fix …", not "Fixed …"),
   describing what the change does. Capitalize the first letter of the summary.
   Aim for about 50 characters on the subject; never more than 72 characters for the full first line.
   Avoid starting the subject with EXT:extensionname (redundant with the diff).

3) If you add a body: there must be one blank line between subject and body.

## Body and overall quality — follow "The seven rules of a great Git commit message":
https://chris.beams.io/git-commit#seven-rules

Summarize: separate subject from body with a blank line; keep subject ~50 chars (72 max); capitalize the subject;
do not end the subject with a period; imperative mood in the subject; wrap the body at about 72 characters;
use the body to explain what and why (not implementation detail — the diff shows how).

Optional bullets in the body may use "* " (asterisk, space). Do not add issue-tracker or Gerrit footer lines
unless the user diff explicitly contains ticket numbers you should quote (default: omit all such footers).

Important:
- Do not wrap your response in triple backticks or markdown fences.
- Output must be the full commit message only, no preamble or explanation.
EOF
else
    IFS= read -r -d '' USER_CONTENT <<EOF || true
Generate a Conventional Commit message for these changes:

## File changes:
<file_changes>
$CHANGES
</file_changes>

## Diff:
<diff>
$DIFF_CONTENT
</diff>

## Format:
<type>(<scope>): <subject>

<body>

Important:
- Type must be one of: feat, fix, docs, style, refactor, perf, test, chore
- Subject: max 70 characters, imperative mood, no period
- Body: list changes to explain what and why, not how
- Scope: max 3 words
- For minor changes: use 'fix' instead of 'feat'
- Do not wrap your response in triple backticks
- Response should be the commit message only, no explanations.
EOF
fi

# Define system prompt
if [ "$BRANCH_NAME_ONLY" = true ]; then
    SYSTEM_PROMPT="You are a git branch name generator. Create concise, standard git branch names."
elif [ "$COMMIT_STYLE" = "$COMMIT_STYLE_TYPO3" ]; then
    SYSTEM_PROMPT="You are a commit message assistant. Use a TYPO3-style tagged subject ([BUGFIX]/[FEATURE]/[DOCS]/[TASK], optional [!!!] or [SECURITY]) and shape the message like https://chris.beams.io/git-commit#seven-rules . Never add Resolves/Related/Releases/Change-Id or other Gerrit/Forge footers unless the diff explicitly supplies ticket IDs to cite."
else
    SYSTEM_PROMPT="You are a git commit message generator. Create conventional commit messages."
fi

# Make the API request
case "$PROVIDER" in
"$PROVIDER_OLLAMA")
    debug_log "Making API request to Ollama"
    ENDPOINT="api/generate"
    HEADERS=(-H "Content-Type: application/json")
    BASE_URL="http://localhost:11434"
    REQUEST_BODY=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$USER_CONTENT" \
        '{model:$model, prompt:$prompt, stream:false}')
    ;;
"$PROVIDER_LMSTUDIO")
    debug_log "Making API request to LMStudio"
    ENDPOINT="chat/completions"
    HEADERS=(-H "Content-Type: application/json")
    REQUEST_BODY=$(jq -n \
        --arg model "$MODEL" \
        --arg content "$USER_CONTENT" \
        --arg system_prompt "$SYSTEM_PROMPT" \
        '{
           model: $model,
           stream: false,
           messages: [
             {role:"system", content:$system_prompt},
             {role:"user",   content:$content}
           ]
         }')
    debug_log "LMStudio request body:" "$REQUEST_BODY"
    ;;
"$PROVIDER_OPENROUTER")
    debug_log "Making API request to OpenRouter"
    ENDPOINT="chat/completions"
    HEADERS=(
        "HTTP-Referer: https://github.com/mrgoonie/cmai"
        "Authorization: Bearer $API_KEY"
        "Content-Type: application/json"
        "X-Title: cmai - AI Commit Message Generator"
    )
    REQUEST_BODY=$(jq -n \
        --arg model "$MODEL" \
        --arg content "$USER_CONTENT" \
        --arg system_prompt "$SYSTEM_PROMPT" \
        '{
           model: $model,
           stream: false,
           messages: [
             {role:"system", content:$system_prompt},
             {role:"user",   content:$content}
           ]
         }')
    ;;
"$PROVIDER_CUSTOM")
    debug_log "Making API request to custom provider"
    ENDPOINT="chat/completions"
    HEADERS=(-H "Content-Type: application/json")
    [ -n "$API_KEY" ] && HEADERS+=(-H "Authorization: Bearer ${API_KEY}")
    REQUEST_BODY=$(jq -n \
        --arg model "$MODEL" \
        --arg content "$USER_CONTENT" \
        --arg system_prompt "$SYSTEM_PROMPT" \
        '{
           stream: false,
           model: $model,
           messages: [
             {role:"system", content:$system_prompt},
             {role:"user",   content:$content}
           ]
         }')
    ;;
esac

# Debug
debug_log "Using provider: $PROVIDER"
debug_log "Provider endpoint: $ENDPOINT"
debug_log "Request headers: ${HEADERS[*]}"
debug_log "Request model: ${MODEL}"
debug_log "Request body: $REQUEST_BODY"

# Convert headers array to proper curl format
CURL_HEADERS=()
for header in "${HEADERS[@]}"; do
    CURL_HEADERS+=(-H "$header")
done

RESPONSE=$(curl -s -X POST "$BASE_URL/$ENDPOINT" \
    "${CURL_HEADERS[@]}" \
    -d "$REQUEST_BODY")
debug_log "API response received" "$RESPONSE"

# Extract and clean the commit message
case "$PROVIDER" in
"$PROVIDER_OLLAMA")
    # For Ollama, extract content from non-streaming response
    if echo "$RESPONSE" | grep -q "404 page not found"; then
        echo "Error: Ollama API endpoint not found. Make sure Ollama is running and try again."
        echo "Run: ollama serve"
        exit 1
    fi
    if echo "$RESPONSE" | jq -e 'type == "object" and (.error | type) != "null"' >/dev/null 2>&1; then
        ERROR=$(echo "$RESPONSE" | jq -r '.error')
        echo "Error from Ollama: $ERROR"
        exit 1
    fi
    RESULT_MESSAGE=$(echo "$RESPONSE" | jq -r '.response // empty')
    if [ -z "$RESULT_MESSAGE" ]; then
        echo "Error: Failed to get response from Ollama. Response: $RESPONSE"
        exit 1
    fi
    ;;
"$PROVIDER_LMSTUDIO")
    # For LMStudio, extract content from response
    debug_log "LMStudio raw response:" "$RESPONSE"

    # Check if response is HTML error page
    if echo "$RESPONSE" | grep -q "<!DOCTYPE html>"; then
        echo "Error: LMStudio API returned HTML error. Make sure LMStudio is running and the API is accessible."
        echo "Response: $RESPONSE"
        exit 1
    fi

    # Check for JSON error - only if there's an actual error field with content
    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        ERROR=$(echo "$RESPONSE" | jq -r '.error.message // .error' 2>/dev/null)
        echo "Error from LMStudio: $ERROR"
        exit 1
    fi

    # Try to extract content with proper error handling
    RESULT_MESSAGE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$RESULT_MESSAGE" ] || [ "$RESULT_MESSAGE" = "null" ]; then
        echo "Error: Failed to parse LMStudio response. Response format may be unexpected."
        echo "Response: $RESPONSE"
        exit 1
    fi
    ;;
"$PROVIDER_OPENROUTER" | "$PROVIDER_CUSTOM")
    # For OpenRouter and custom providers
    RESULT_MESSAGE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

    # If jq fails or returns null, fallback to grep method
    if [ -z "$RESULT_MESSAGE" ] || [ "$RESULT_MESSAGE" = "null" ]; then
        RESULT_MESSAGE=$(echo "$RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
    fi
    ;;
esac

# Clean the message:
# 1. Preserve the structure of the commit message
# 2. Clean up escape sequences
RESULT_MESSAGE=$(echo "$RESULT_MESSAGE" |
    sed 's/\\n/\n/g' |
    sed 's/\\r//g' |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
    sed 's/\\[[:alpha:]]//g')

debug_log "Extracted commit message" "$RESULT_MESSAGE"

if [ -z "$RESULT_MESSAGE" ]; then
    echo "Failed to generate commit message. API response:"
    echo "$RESPONSE"
    exit 1
fi

if [ "$MESSAGE_ONLY" = true ] || [ "$BRANCH_NAME_ONLY" = true ]; then
    echo "$RESULT_MESSAGE"
    exit 0
fi

echo ""
echo "Vorschlag für die Commit-Nachricht:"
echo "────────────────────────────────────"
echo "$RESULT_MESSAGE"
echo "────────────────────────────────────"
echo ""

if [ "$SKIP_PROMPT" = false ]; then
    if [ ! -t 0 ]; then
        echo "Kein interaktives Terminal. Zum Committen ohne Rückfrage: --yes (-y). Nur Ausgabe: --message-only."
        exit 0
    fi
    read -r -p "Mit dieser Nachricht committen? [j/N] " reply || true
    case "$reply" in
    j | J | y | Y) ;;
    *)
        echo "Abgebrochen."
        exit 0
        ;;
    esac
fi

# If we were in unstaged mode, we need to stage changes before committing
if [ "$UNSTAGED" = true ]; then
    debug_log "Staging all changes before commit"
    git add .
fi

COMMIT_MSG_FILE=$(mktemp)
trap 'rm -f "$COMMIT_MSG_FILE"' EXIT

printf '%s\n' "$RESULT_MESSAGE" >"$COMMIT_MSG_FILE"

debug_log "Executing git commit"
git commit -F "$COMMIT_MSG_FILE"

if [ $? -ne 0 ]; then
    echo "Failed to commit changes"
    exit 1
fi

# Push to origin if flag is set
if [ "$PUSH" = true ]; then
    debug_log "Pushing to origin"
    git push origin

    if [ $? -ne 0 ]; then
        echo "Failed to push changes"
        exit 1
    fi
    echo "Push nach origin erfolgreich."
fi

echo "Commit erfolgreich. Nachricht:"
echo "$RESULT_MESSAGE"
debug_log "Script completed successfully"
