#! /bin/bash
# This script provides utility functions for logging and displaying debug, info, warning, and error messages with colored output.
# The functions use ANSI escape codes to color the text for better visibility.
# The Greek letter lambda (λ) is used as a prefix to distinguish log messages.
# lambda (λ) symbol used as a prefix for all log messages
lambda=λ

###########################################
# do_log()
# Prints an informational message in the specified color.
# Arguments:
#   $1 - The message to display. If empty, reads from standard input.
# Output:
#   An informational message is printed in the specified color.
###########################################
do_log() {
  # Print the informational message in $COLOR color
  if [[ -z "$1" ]]; then
      while read -r l; do
          printf "${COLOR}${lambda} INFO %s\e[0m\n" "${l}"
      done
  else
      printf "${COLOR}${lambda} INFO %s\e[0m\n" "${1}"
  fi
}


###########################################
# debug()
# Prints a debug message in blue if the DEBUG variable is set.
# Arguments:
#   $1 - The debug message to display.
# Output:
#   A blue debug message is printed to STDERR if debugging is enabled.
###########################################
do_debug() {
    # Check if the DEBUG variable is non-empty
    [[ -n "$DEBUG" ]] && { COLOR="\033[0;34m"; do_log "$1"; }
}

###########################################
# error()
# Prints an error message in red and exits the script with a non-zero status.
# Arguments:
#   $1 - The error message to display.
# Output:
#   A red error message is printed to STDERR, and the script exits with status 1.
###########################################
do_error() {
    # Print the error message in red and exit
    COLOR="\033[0;31m"; do_log "$1" >&2
    exit 1 # Exit the script with a status code of 1 (indicating an error)
}

###########################################
# info()
# Prints an informational message in green.
# Arguments:
#   $1 - The info message to display.
# Output:
#   A green info message is printed to STDERR.
###########################################
do_info() {
    # Print the informational message in green
    COLOR="\033[0;32m"; do_log "$1"
}

###########################################
# warn()
# Prints a warning message in yellow.
# Arguments:
#   $1 - The warning message to display.
# Output:
#   A yellow warning message is printed to STDERR.
###########################################
do_warn() {
    # Print the warning message in yellow
    COLOR="\033[0;33m"; do_log "$1" >&2
}
