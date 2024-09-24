#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

[[ -n "$DEBUG" ]] && set -ex

# Determine the script directory
script_dir=$(dirname "$(realpath "$0")")

# Source the logging library
source "$script_dir/lib/logging.sh"

# Function to display usage information
usage() {
    cat <<EOF
Usage: $0 --name <state_machine_name> [--filter <key=value>]... [--timeout <seconds>] [--wait-interval <seconds>]

Options:
  --name             Name of the Step Function state machine (required)
  --filter           Filter criteria in key=value format. Can be specified multiple times.
                     (e.g., --filter subdomain=example.com --filter email=user@example.com)
  --timeout          Timeout in seconds (default: 7200)
  --wait-interval    Polling interval in seconds (default: 15)
  --help             Display this help message

Examples:
  # Using filters for subdomain and email
  $0 --name MyStateMachine --filter subdomain=example.com --filter email=user@example.com --timeout 300 --wait-interval 10

  # Using default timeout and wait interval
  $0 --name MyStateMachine --filter subdomain=example.com --filter email=user@example.com
EOF
    exit 1
}

# Default values
TIMEOUT=7200          # Default timeout: 2 hours
WAIT_INTERVAL=15      # Default polling interval: 15 seconds

# Arrays to hold filter keys and values
FILTER_KEYS=()
FILTER_VALUES=()

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --name)
            STATE_MACHINE_NAME="$2"
            shift 2
            ;;
        --filter)
            if [[ "$2" =~ ^[^=]+=[^=]+$ ]]; then
                KEY="${2%%=*}"
                VALUE="${2#*=}"
                FILTER_KEYS+=("$KEY")
                FILTER_VALUES+=("$VALUE")
                shift 2
            else
                echo "Error: --filter argument must be in key=value format." >&2
                usage
            fi
            ;;
        --timeout)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                TIMEOUT="$2"
                shift 2
            else
                echo "Error: --timeout must be a positive integer." >&2
                usage
            fi
            ;;
        --wait-interval)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                WAIT_INTERVAL="$2"
                shift 2
            else
                echo "Error: --wait-interval must be a positive integer." >&2
                usage
            fi
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown parameter '$1'" >&2
            usage
            ;;
    esac
done

# Check for required arguments
if [[ -z "$STATE_MACHINE_NAME" ]]; then
    do_warn "Error: --name is required."
    usage
fi

if [[ "${#FILTER_KEYS[@]}" -eq 0 ]]; then
    do_warn "Error: At least one --filter is required to specify matching criteria."
    usage
fi

# Function to construct a jq filter string
construct_jq_filter() {
    local jq_filter=""
    for i in "${!FILTER_KEYS[@]}"; do
        key="${FILTER_KEYS[$i]}"
        value="${FILTER_VALUES[$i]}"
        # Escape double quotes and backslashes in value
        escaped_value=$(echo "$value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        jq_filter+=".${key}==\"${escaped_value}\""
        if [[ $i -lt $((${#FILTER_KEYS[@]} - 1)) ]]; then
            jq_filter+=" and "
        fi
    done
    do_debug "Constructed jq filter: $jq_filter" >&2
    echo "$jq_filter"
}

# Retrieve the State Machine ARN by name
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines \
    --query "stateMachines[?name=='$STATE_MACHINE_NAME'].stateMachineArn" \
    --output text)

if [[ -z "$STATE_MACHINE_ARN" ]]; then
    do_error "Error: State Machine with name '$STATE_MACHINE_NAME' not found."
    exit 1
fi

do_info "Found State Machine ARN: $STATE_MACHINE_ARN"

# Function to find the execution ARN based on filters
find_execution_arn() {
    local jq_filter
    jq_filter=$(construct_jq_filter)
    local executions
    executions=$(aws stepfunctions list-executions \
        --state-machine-arn "$STATE_MACHINE_ARN" \
        --status-filter "RUNNING" \
        --output json)

    # Initialize execution ARN as empty
    local matched_execution_arn=""

    # Iterate over each execution
    echo "$executions" | jq -c '.executions[]' | while read -r execution; do
        execution_arn=$(echo "$execution" | jq -r '.executionArn')
        do_debug "Checking Execution ARN: $execution_arn" >&2

        # Retrieve input for the execution
        input=$(aws stepfunctions describe-execution \
            --execution-arn "$execution_arn" \
            --query "input" \
            --output text)

        # Check if input is valid JSON
        if ! echo "$input" | jq empty > /dev/null 2>&1; then
            do_warn "Warning: Invalid JSON input for execution ARN: $execution_arn"
            continue
        fi

        # Apply the jq filter to the input
        if echo "$input" | jq "$jq_filter" > /dev/null 2>&1; then
            # If filter matches, set the matched execution ARN and break
            matched_execution_arn="$execution_arn"
            do_info "Matched Execution ARN: $matched_execution_arn" >&2
            echo "$matched_execution_arn"
            break
        fi
    done

    echo "$matched_execution_arn"
}

# Function to wait for the execution ARN
wait_execution_arn() {
    local elapsed=0
    while [[ $elapsed -lt $TIMEOUT ]]; do
        EXECUTION_ARN=$(find_execution_arn)
        if [[ -n "$EXECUTION_ARN" ]]; then
            echo "$EXECUTION_ARN"
            return 0
        fi
        do_info "No matching execution found yet. Retrying in $WAIT_INTERVAL seconds..." >&2
        sleep "$WAIT_INTERVAL"
        elapsed=$((elapsed + WAIT_INTERVAL))
    done
    echo ""
    return 1
}

# Attempt to find the running execution ARN with waiting
do_info "Searching for running executions matching the provided filters..."
EXECUTION_ARN=$(wait_execution_arn)

if [[ -z "$EXECUTION_ARN" ]]; then
    do_error "No running execution found matching the specified filters after waiting."
    exit 1
fi

do_info "Found Execution ARN: $EXECUTION_ARN"

# Record the start time
START_TIME=$(date +%s)

# Function to check the status of the execution
check_status() {
    aws stepfunctions describe-execution \
        --execution-arn "$EXECUTION_ARN" \
        --query "status" \
        --output text
}

# Function to get the failure reason
get_failure_reason() {
    aws stepfunctions describe-execution \
        --execution-arn "$EXECUTION_ARN" \
        --query "cause" \
        --output text
}

# Function to retrieve and print the execution details
print_execution_details() {
    aws stepfunctions describe-execution \
        --execution-arn "$EXECUTION_ARN" \
        --output json | jq -M '.'  # Pretty-print using jq without colors
}

# Function to retrieve and print the execution history
print_execution_history() {
    aws stepfunctions get-execution-history \
        --execution-arn "$EXECUTION_ARN" \
        --max-items 100 \
        --reverse-order \
        --output json | jq -M '.'  # Pretty-print using jq without colors
}

# Start polling
do_info "Waiting for the Step Function execution to complete..."
while true; do
    STATUS=$(check_status)
    do_info "Current execution status: $STATUS"

    case "$STATUS" in
        SUCCEEDED)
            do_info "Execution has succeeded."
            do_info "Execution Details:"
            print_execution_details
            exit 0
            ;;
        FAILED)
            FAILURE_REASON=$(get_failure_reason)
            do_error "Execution has failed. Reason: $FAILURE_REASON"
            do_info "Execution Details:"
            print_execution_details
            exit 1
            ;;
        TIMED_OUT)
            do_error "Execution has timed out."
            do_info "Execution Details:"
            print_execution_details
            exit 1
            ;;
        ABORTED)
            do_error "Execution has been aborted."
            do_info "Execution Details:"
            print_execution_details
            exit 1
            ;;
        RUNNING|STARTING|PAUSED)
            do_info "Current execution details:"
            print_execution_details
            # Uncomment the next line if you want to see execution history
            # print_execution_history
            ;;
        *)
            do_error "Unknown status '$STATUS'. Exiting."
            do_info "Execution Details:"
            print_execution_details
            exit 1
            ;;
    esac

    # Check for timeout
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    if [[ "$ELAPSED_TIME" -ge "$TIMEOUT" ]]; then
        do_error "Timeout of $TIMEOUT seconds reached. Exiting."
        do_info "Execution Details:"
        print_execution_details
        exit 1
    fi

    # Wait for the specified interval before polling again
    sleep "$WAIT_INTERVAL"
done
