#!/bin/bash

# terminate all sandboxer processes
# if invoked by non-root user, then terminate running sandboxer instances only on this user

set -e

show_usage() {
  >&2 echo "usage: sandboxer-stop-all.sh [term timeout, seconds] [kill timeout, seconds]"
  exit 1
}

assert_number() {
  [[ $@ =~ ^[0-9]+([.][0-9]+)?$ ]] || show_usage
  return 0
}

# read term and kill timeouts
term_timeout="$1"
kill_timeout="$2"

assert_number "$term_timeout"
assert_number "$kill_timeout"

# detect current user
uid=`id -u`

# pid list
pid_list=()
pid_list_cnt=0

clear_pid_list() {
  pid_list=()
  pid_list_cnt=0
}

add_pid() {
  pid_list[$pid_list_cnt]="$1"
  pid_list_cnt=$((pid_list_cnt+1))
}

check_pid_list() {
  for ((list_cnt=0;list_cnt<pid_list_cnt;++list_cnt))
  do
    [[ -f /proc/${pid_list[$list_cnt]}/stat ]] && return 0
  done
  return 1
}

wait_for_termination() {
  local timeout="$1"
  local timepass="0"
  local step="0.05"
  while [[ `echo "$timepass<$timeout" | bc -q` = 1 ]]
  do
    [[ `echo "$timepass>=0.5" | bc -q` = 1 ]] && step="0.1"
    [[ `echo "$timepass>=1.0" | bc -q` = 1 ]] && step="0.25"
    [[ `echo "$timepass>=2.0" | bc -q` = 1 ]] && step="0.5"
    [[ `echo "$timepass>=5.0" | bc -q` = 1 ]] && step="1"
    sleep $step
    timepass=`echo "$timepass+$step" | bc -q`
    check_pid_list || break
  done
  [[ `echo "$timepass<$timeout" | bc -q` = 1 ]] && echo "all sandboxes terminated" && exit 0
  return 0
}

# find master executor processes
if [[ $uid != 0 ]]; then
  while read -r pid rest; do add_pid "$pid"; done < <(ps -ww -u $uid --no-headers -o pid:1,cmd:1 | grep -E "^[0-9]+\s/executor/executor\s0.*$")
else
  while read -r pid rest; do add_pid "$pid"; done < <(ps -wwe --no-headers -o pid:1,cmd:1 | grep -E "^[0-9]+\s/executor/executor\s0.*$")
fi

[[ $pid_list_cnt = 0 ]] && echo "no active sandboxes was found, nothing to stop" && exit 0

# send termination signals
echo "performing grace shutdown for running sandboxes"
for ((list_cnt=0;list_cnt<pid_list_cnt;++list_cnt))
do
  kill -SIGTERM ${pid_list[$list_cnt]} || true
done

# wait for executor processes termination
wait_for_termination "$term_timeout"

# send sigusr1 signal
echo "grace_shutdown failed, trying to force-stop running sandboxes"
for ((list_cnt=0;list_cnt<pid_list_cnt;++list_cnt))
do
  kill -SIGUSR1 ${pid_list[$list_cnt]} || true
done

# wait for executor processes termination
wait_for_termination "$kill_timeout"

# print error
echo "failed to terminate all running sandboxes!" && exit 1
