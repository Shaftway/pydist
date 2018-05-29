#!/bin/bash

# ================================================================
# ==  Functions for handling each command / option / whatever.  ==
# ================================================================

# Remaining command line arguments are forwarded to each function. If the
# function consumes one or more arguments it should set SHIFTS to the number of
# arguments that were consumed. If the script should exit, set EXIT_STATUS to
# the exit code.

function help {
  # TODO: Write help.
  echo "See https://github.com/Shaftway/pydist for details."
  EXIT_STATUS=0
}

function add {
  # Adds files. Args: <root> <path> <pattern> <destination>
  log "  Adding files: $1 / $2 / $3 --> $4"
  (
    cd "$1"
    mkdir -p "$WORKING_DIR/$4";
    find "$2" -not -type d -name "$3" -exec cp --parents \{\} "$WORKING_DIR/$4" \;
  )
  SHIFTS=4
}

function code {
  # Adds code. Args: <root> <path> <destination>
  add "$1" "$2" "*.py" "$3"
  SHIFTS=3
}

function data {
  # Adds data files. Args: <root> <path> <destination>
  add "$1" "$2" "*" "$3"
  SHIFTS=3
}

function remove {
  # Removes staged files. Args: <path> <pattern>
  log "  Removing files: $1 / $2";
  find "$WORKING_DIR/$1" -name "$2" -exec rm -rf \{\} \; 2> /dev/null
  SHIFTS=2
}

function option {
  log "  Option: $1";

  if [[ "$1" == "python" ]]; then
    log "    Using Python '$2'";
    USE_PYTHON="$2";
    SHIFTS=2;

  elif [[ "$1" == "main" ]]; then
    log "    Setting '$2' as entry point";
    MAIN="$2";
    SHIFTS=2;

  else
    echo -e "Unexpected option: '$1'";
    fail;
  fi
}

function debug {
  # Writes out debugging information.
  echo "Staging directory: $WORKING_DIR";
  find "$WORKING_DIR";
  EXIT_STATUS=0
}

function execute {
  log "  Executing: $USE_PYTHON $WORKING_DIR/$MAIN $@"
  log "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
  "$USE_PYTHON" "$WORKING_DIR/$MAIN" "$@"
  log "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
  EXIT_STATUS=$?
}

function extract {
  log "  Extracting files to $1";
  cp -R "$WORKING_DIR" "$1";
  EXIT_STATUS=0
}

function read_input_file {
  # TODO: Read input file.
  log "  Reading from $1"
}

function write_output_file {
  log "  Writing to $1"
  write_output > "$1";
  chmod u+x "$1";
  EXIT_STATUS=0;
}

function write_output {
  # TODO: Write output file.
  echo "#!/bin/bash"
  echo "echo \"Not implemented yet\";";
}

# ========================
# ==  Helper functions  ==
# ========================

function fail {
  # Writes out help text and exits with a code of "1".
  help;
  EXIT_STATUS=1
}

function log {
  # If $VERBOSE is "true", writes arguments to stderr.
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "$@";
  fi
}

# ================================
# ==  All temporary variables.  ==
# ================================

WORKING_DIR=`mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir'`;
ASSUME_INPUT=true
EXIT_STATUS=''
VERBOSE=false
USE_PYTHON=python
MAIN=.

# =======================================================
# ==  Set up a hook to delete the working dir on exit  ==
# =======================================================

if [ -z "${WORKING_DIR}" ]; then
  echo -e "Staging directory couldn't be created.";
  exit 1;
fi

function cleanup {
  rm -rf "${WORKING_DIR}";
}

trap cleanup EXIT;

# ==========================================
# ==  Handle the command line arguments.  ==
# ==========================================

# If the first argument is verbose, consume it.
if [[ "$1" == "--verbose" ]]; then
  VERBOSE=true;
  shift;
fi


# Loop over all arguments and do what needs to be done.
while (( "$#" )); do
  NEXT_COMMAND="$1"
  SHIFTS=0
  log "Command: $NEXT_COMMAND";
  shift;

  if [[ "$NEXT_COMMAND" == "--help" ]]; then
    help;

  elif [[ "$NEXT_COMMAND" == "--debug" ]]; then
    debug;

  elif [[ "$NEXT_COMMAND" == "--execute" ]]; then
    execute "$@";

  elif [[ "$NEXT_COMMAND" == "--extract" ]]; then
    extract "$@";

  elif [[ "$NEXT_COMMAND" == "--add" ]]; then
    add "$@";

  elif [[ "$NEXT_COMMAND" == "--code" ]]; then
    code "$@";

  elif [[ "$NEXT_COMMAND" == "--data" ]]; then
    data "$@";

  elif [[ "$NEXT_COMMAND" == "--remove" ]]; then
    remove "$@";

  elif [[ "$NEXT_COMMAND" == "--option" ]]; then
    option "$@";

  # TODO: Handle more arguments here.

  elif [[ "$ASSUME_INPUT" == "true" ]]; then
    read_input_file "$NEXT_COMMAND";

  elif [[ "$#" -gt 0 ]]; then
    echo -e "Unexpected argument: $1";
    fail;

  else
    write_output_file "$NEXT_COMMAND"
  fi

  # Exit if EXIT_STATUS is not blank.
  if [ -n "$EXIT_STATUS" ]; then
    log "Finished, exiting with code '${EXIT_STATUS}'";
    exit $EXIT_STATUS;
  fi

  # Shift arguments that have been used.
  for ((n=0; n<SHIFTS; n++)); do shift; done

  # After the first arg assume that an unrecognized argument is the output file.
  ASSUME_INPUT=false
done

# If we haven't exited already, write the distributable to stdout.
write_output;
exit 0;

