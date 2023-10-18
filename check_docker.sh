#!/bin/bash
# author: itsapassion.wordpress.com
# url: https://itsapassion.wordpress.com/category/nagios/



#===============================================================================================================================
# - script in bash / Nagios / NRPE client
# - script checks:
#						all containers state <running | starting| stopped | other>
#						all containers health <healthy | not healthy | unknown>    (if set up in docker)
#						specific container for its statistics usage: CPU | MEMORY | NETWORK | DISK | UPTIME
#
#===============================================================================================================================



# startup parameters
if [ $# -eq 0 ]; then
  echo "Usage: ./check_docker.sh [--container_stats=<container_name>] [--containers_state] [--containers_health] "
  exit 1
fi


# startup variables
container_name=""
parameter=""
output=""
state=3




# [--container_stats=<container_name>]
for arg in "$@"; do
  case $arg in
    --container_stats=*)
      container_name="${arg#*=}"
      ;;
    *)
      parameter="$arg"
      ;;
  esac
done




# ALL containers state
if [ "$parameter" == "--containers_state" ]; then

        # all containers and states
        container_info=$(docker ps -a --format "{{.ID}}:{{.State}}")

        # counters
        running=0
        stopped=0
        starting=0
        other=0

        # iterate
        while IFS=: read -r container_id container_state; do

        container_state=$(echo "$container_state" | awk '{$1=$1};1')

        case $container_state in
                "running")
                ((running++))
                ;;
                "exited" | "created" | "dead")
                ((stopped++))
                ;;
                "restarting" | "starting")
                ((starting++))
                ;;
                *)
                ((other++))
                ;;
        esac
        done <<< "$container_info"

        output="Containers - Running: $running Stopped: $stopped Starting: $starting Other: $other | Running=$running Stopped=$stopped Starting=$starting Other=$other"

        if [ $stopped -gt 0 ]; then
                output="ERROR: $output"
                state=2
                elif [ $starting -gt 0 ] || [ $other -gt 0 ] || [ $running -eq 0 ]; then
                output="WARNING: $output"
                state=1
                else
                output="OK: $output"
                state=0

        fi

        echo $output
        exit $state
fi




# ALL containers health
if [ "$parameter" == "--containers_health" ]; then

        # all containers and states
        containers=$(docker ps --format "{{.Names}}")


        not_healthy=0
        healthy=0
        unknown=0

        desc_not_healthy=""
        desc_healthy=""
        desc_unknown=""

        for container in $containers; do
        health_status=$(docker inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}No health checks{{end}}" $container)

        if [ -z "$health_status" ]; then
                output+="$container health not set up, "
                desc_unknown+="$container, "
                ((unknown++))
        elif [ "$health_status" == "healthy" ]; then
                output+="$container healthy, "
                desc_healthy+="$container, "
                ((healthy++))
        else
                output+="$container not healthy, "
                desc_not_healthy+="$container, "
                ((not_healthy++))
        fi
        done


        output="not healthy: $not_healthy,  healthy: $healthy,  unknown: $unknown <br><br>
                summary:<br>not healthy: $desc_not_healthy<br> healthy: $desc_healthy<br> unknown: $desc_unknown
                 | Healthy=$healthy Not_healthy=$not_healthy Unknown=$unknown"

        if [ $not_healthy -gt 0 ]; then
                output="ERROR: $output"
                state=2
        elif [ $unknown -gt 0 ]; then
                output="WARNING: $output"
                state=1
        elif [ $not_healthy -eq 0 ] && [ $healthy -gt 0 ] && [ $unknown -eq 0 ]; then
                output="OK: $output"
                state=0
        elif [ $unknown -gt 0 ]; then
                output="UNKNOWN: $output"
                state=3
        else
                output="UNKNOWN: $output"
                state=3
        fi


        echo $output
        exit $state
fi









# Specific containers stats
if [ -n "$container_name" ]; then


        if [[ -z $container_name ]]; then
                echo "Please provide the --container parameter with the container name or ID."
                exit 1
        fi

        # Get the CPU usage percentage of the container
        CPU_USAGE=$(docker stats --no-stream $container_name --format "{{.CPUPerc}}")

        # Get the memory usage of the container
        MEMORY_USAGE=$(docker stats --no-stream $container_name --format "{{.MemPerc}}")

        # Get the network input and output of the container
        NETWORK_IN=$(docker stats --no-stream $container_name --format "{{.NetIO}}" | awk -F '/' '{print $1}' | tr -d ' ')
        NETWORK_OUT=$(docker stats --no-stream $container_name --format "{{.NetIO}}" | awk -F '/' '{print $2}' | tr -d ' ')

        # Get the disk read and write of the container
        DISK_READ=$(docker stats --no-stream $container_name --format "{{.BlockIO}}" | awk -F '/' '{print $1}' | tr -d ' ')
        DISK_WRITE=$(docker stats --no-stream $container_name --format "{{.BlockIO}}" | awk -F '/' '{print $2}' | tr -d ' ')


        #uptime
        start_time=$(docker inspect --format='{{.State.StartedAt}}' "$container_name")
        seconds_since_start=$(( $(date +%s) - $(date -d "$start_time" +%s) ))

        if [ "$seconds_since_start" -lt 3600 ]; then
                uptime="$(( seconds_since_start / 60 )) min"
        elif [ "$seconds_since_start" -lt 86400 ]; then
                uptime="$(( seconds_since_start / 3600 )) hr"
        else
                uptime="$(( seconds_since_start / 86400 )) days"
        fi


        # Print the performance metrics in PNP4Nagios format
        echo "CPU:$CPU_USAGE Mem:$MEMORY_USAGE Net_IN:$NETWORK_IN Net_OUT:$NETWORK_OUT Disk_R:$DISK_READ Disk_W:$DISK_WRITE Uptime=$uptime | CPU=$CPU_USAGE Mem=$MEMORY_USAGE"

fi

