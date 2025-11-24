#!/bin/bash

# this file can not be hot reloaded, the container must be re-created to implement changes

#putting this here as a note for myself: to enable hot reloading of python script
#- entrypoint is a looping script to check a txt file
#- if it finds a given command word in the file, execute that action
#- if it finds nothing, continue looping
#- write another named script to write to the check file depending on the argument

#############################

# Add echos to logfile
# Define the log file
Log_File="$LOG_FILE_NAME"

# Redirect stdout and stderr to both the console and the log file
exec &> >(tee -a "$Log_File") 2>&1

#############################

# color options
BLACK='\033[30m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[37m'
RESET='\033[0m'

LRED='\033[91m'
LGREEN='\033[92m'

#############################

# Global Flags
Bot_PID=2
Bot_File="$BOT_FILE_NAME"
Flag_File="$FLAG_FILE_NAME"
Log_File="$LOG_FILE_NAME"

#############################

# Function Returns
Bot_Status=2
Bot_Started=2
Bot_Stopped=2

#############################

main() {
    # start bot if auto launch flag is true (0)
    echo -e "${WHITE}launch flag is $AUTO_LAUNCH_BOT${RESET}"
    if [ "$AUTO_LAUNCH_BOT" == 0 ]; then
        echo -e "${GREEN}Automatically launching bot defined by python script '$Bot_File'${RESET}"
        python3.14 "$Bot_File" & #& symbol runs script in background
        Bot_PID="$!"
        echo "bot started"
    fi 

    # lifespan loop
    while true; do
        #echo -e "${WHITE}Beginning new command loop${RESET}" #debugging

        # when command is present for processing
        if [ -f "$Flag_File" ]; then
            # read in command
            commandBody=$(head -n 1 "$Flag_File")
            read -ra commandArray <<< "$commandBody"
            command=""
            verbose=1
            argLength=${#commandArray[@]}
            #echo "$commandArray"
            #echo "$argLength"

            if [ "$argLength" -gt 2 ] || [ "$argLength" -lt 1 ]; then
                command="ERROR"
            elif [ "$argLength" == 2 ]; then
                if [ ${commandArray[1]} != 0 ] && [ ${commandArray[1]} != 1 ]; then
                    echo -e "${YELLOW}WARNING: Bad command verbosity flag, valid arg values are 0, 1, or none at all. Recieved ${commandArray[0]}. Proceeding assuming verbosity.${RESET}"
                    verbose=0
                else
                    command=${commandArray[0]}
                    verbose=${commandArray[1]}
                fi
            elif [ "$argLength" == 1 ]; then
                command="$commandBody"
            fi

            if [ "$verbose" == 0 ]; then
                echo -e "${LGREEN}Command found: $commandBody${RESET}"
            fi

            # this should write back to host
            case "$command" in
                # exit lifespan, stop container
                "EXIT")
                    kill_bot_and_exit "$verbose"
                    ;;

                # stops and restarts the bot script
                "RESTART")
                    restart_bot "$verbose"
                    ;;
                
                # stops the bot script
                "STOP")
                    stop_bot "$verbose"
                    ;;
                
                # starts the bot script
                "START")
                    start_bot "$verbose"
                    ;;

                # returns current bot status
                "STATUS")
                    check_bot_status "$verbose"
                    ;;

                "ERROR")
                    echo -e "${RED}ERROR: Command should be of the format <Command> <Verbosity Flag>?. Received $commandBody. Ignoring instruction.${RESET}"
                    ;;

                # catches bad commands
                *)
                    echo -e "${RED}ERROR: Faulty instruction received. Command should be of the format <Command> <Verbosity Flag>?. Received $commandBody. Ignoring instruction.${RESET}"
                    ;;
            esac

            # remove command file after processing
            rm "$Flag_File"
            sleep 1 # TODO: remove in prod

        # when no command is present
        else
            # wait 1 second and check again
            sleep 1
        fi
    done
}

#############################

# all below functions will print to console if called with 1st arg as 0. Can be called silently with no first arg or first arg 1

kill_bot_and_exit() {
    local verbose="${1:-1}"
    if [ "$verbose" != 0 ] && [ "$verbose" != 1 ]; then
        echo -e "${YELLOW}WARNING: Bad call to kill_bot_and_exit, valid arg values are 0, 1, or none at all. Recieved {$verbose}. Proceeding assuming verbosity.${RESET}"
    fi

    local finalStatus=$(stop_bot $verbose)

    if [ "$verbose" == 0 ]; then
        echo -e "${GREEN}Bot defined by Python script '$Bot_File' confirmed stopped. Exiting container monentarily.${RESET}"
        sleep 1
    fi
    exit 0
}

# checks bot script status. Can either output status via text (param 0) or return bool (param 1)
check_bot_status() {
    local verbose="${1:-1}"

    if [ "$verbose" != 0 ] && [ "$verbose" != 1 ]; then
        echo -e "${YELLOW}WARNING: Bad call to check_bot_status, valid arg values are 0, 1, or none at all. Recieved {$verbose}. Proceeding assuming verbosity.${RESET}"
    fi

    if pgrep -f "$Bot_File" > /dev/null; then
        if [ "$verbose" == 0 ]; then
            echo -e "${CYAN}Bot defined by Python script '$Bot_File' is running.${RESET}"
        fi
        Bot_Status=0
    else
        if [ "$verbose" == 0 ]; then
            echo -e "${CYAN}Bot defined by Python script '$Bot_File' is not running.${RESET}"
        fi
        Bot_Status=1
    fi
}

# runs bot stop then bot start
restart_bot() {
    local verbose="${1:-1}"
    if [ "$verbose" != 0 ] && [ "$verbose" != 1 ]; then
        echo -e "${YELLOW}WARNING: Bad call to check_bot_status, valid arg values are 0, 1, or none at all. Recieved {$verbose}. Proceeding assuming verbosity.${RESET}"
    fi

    stop_bot "$verbose"
    start_bot "$verbose"

    if [ "$Bot_Started" == 1 ]; then
        echo -e "${RED}FATAL ERROR: restart_bot could not complete. Bot failed to shut down prior to restart.${RESET}"
        kill_bot_and_exit 0
    elif [ "$verbose" == 0 ]; then
        echo -e "${LGREEN}SUCCESS: Bot restarted${RESET}"
    fi
}

# stops bot process if it is running, otherwise prints error message
stop_bot() {
    local verbose="${1:-1}"
    if [ "$verbose" != 0 ] && [ "$verbose" != 1 ]; then
        echo -e "${YELLOW}WARNING: Bad call to stop_bot, valid arg values are 0, 1, or none at all. Recieved {$verbose}. Proceeding assuming verbosity.${RESET}"
    fi

    check_bot_status "$verbose"
    if [ "$Bot_Status" == 0 ]; then
        pkill -f "$Bot_File"
        if [ "$verbose" == 0 ]; then
            echo -e "${LGREEN}SUCCESS: Bot stopped${RESET}"
        fi
        Bot_Stopped=0
    else 
        if [ "$verbose" == 0 ]; then
            echo -e "${LRED}FAILURE: Bot $Bot_File was not running${RESET}"
        fi
        Bot_stopped=1
    fi
}

start_bot() {
    local verbose="${1:-1}"
    if [ "$verbose" != 0 ] && [ "$verbose" != 1 ]; then
        echo -e "${YELLOW}WARNING: Bad call to start_bot, valid arg values are 0, 1, or none at all. Recieved {$verbose}. Proceeding assuming verbosity.${RESET}"
    fi

    check_bot_status "$verbose"
    if [ "$Bot_Status" == 1 ]; then
        python3.14 "$Bot_File" &
        Bot_PID="$!"
        if [ "$verbose" == 0 ]; then
            echo -e "${LGREEN}SUCCESS: Bot started${RESET}"
        fi
        Bot_Started=0
    else 
        if [ "$verbose" == 0 ]; then
            echo -e "${LRED}FAILURE: Bot $Bot_File is already running.${RESET}"
        fi
        Bot_Started=1
    fi
}

#############################

main "$@"

#############################

