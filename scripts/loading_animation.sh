#!/bin/bash

# Function to display a loading animation
show_loading_animation() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\ '
  echo -n "Processing... "
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf "[%c]" "$spinstr"
    local spinstr=$temp${spinstr%???}
    sleep $delay
    printf "\b\b\b"
  done
  printf "   \b\b\b\n"
  echo "Done."
}

