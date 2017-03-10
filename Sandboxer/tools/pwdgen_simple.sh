#!/bin/bash

#group and passwd files generator for sandbox
tgt_name="$1"
src_uid="$2"
tgt_uid="$3"
src_gid="$4"
tgt_gid="$5"
tgt_home="$6"
passwd_out="$7"
group_out="$8"

check_errors () {
  local status="$?"
  local msg="$@"
  if [[ $status != 0 ]]; then
    echo "pwdgen_simple.sh: operation finished with error code $status"
    [[ ! -z $msg ]] && echo "$msg"
    exit "$status"
  fi
}

nobody_uid=`id -u nobody`
[[ ! -z $nobody_uid ]] || check_errors "failed to detect uid for 'nobody' user"

nobody_gid=`id -g nobody`
[[ ! -z $nobody_gid ]] || check_errors "failed to detect gid for 'nobody' user"

[[ $tgt_name != root ]] || check_errors "target user name 'root' is not allowed"
[[ $tgt_name != nobody ]] || check_errors "target user name 'nobody' is not allowed"

[[ $src_uid != 0 ]] || check_errors "it is not allowed to start this script as uid 0 user"
[[ $src_uid != $nobody_uid ]] || check_errors "it is not allowed to start this script as 'nobody' user"

[[ $tgt_uid != 0 ]] || check_errors "target uid 0 is not allowed"
[[ $tgt_uid != $nobody_uid ]] || check_errors "target uid $nobody_uid is not allowed"

[[ $src_gid != 0 ]] || check_errors "it is not allowed to start this script as gid 0 user"
[[ $src_gid != $nobody_gid ]] || check_errors "target gid $nobody_gid is not allowed"

[[ $tgt_gid != 0 ]] || check_errors "target gid 0 is not allowed"
[[ $tgt_gid != $nobody_gid ]] || check_errors "target gid $nobody_gid is not allowed"

[[ $tgt_home != /root ]] || check_errors "target home dir '/root' is not allowed"

#cache for processed gids and uids
declare -A g_cache

cache_add() {
  [[ ! -z ${g_cache[$1]} ]] && return 1
  g_cache[$1]=1
  return 0
}

echo -n "" > "$passwd_out"
check_errors
echo -n "" > "$group_out"
check_errors

false_bin=`2>/dev/null which "false"`
[[ ! -z $false_bin ]] || check_errors "'false' binary detection failed"

login_shell=`getent passwd $USER | cut -d':' -f7`

#group and passwd records for target user and it's main group
cache_add "$tgt_gid"
echo "$tgt_name:x:$tgt_uid:$tgt_gid:$tgt_name:$tgt_home:$login_shell" >> "$passwd_out"
check_errors
echo "$tgt_name:x:$tgt_gid:" >> "$group_out"
check_errors

#group and passwd records for root
cache_add "0"
echo "root:x:0:0:root:/root:$false_bin" >> "$passwd_out"
check_errors
echo "root:x:0:" >> "$group_out"
check_errors

#group and passwd records for nobody
cache_add "$nobody_gid"
nobody_gid_name=`2>/dev/null getent group $nobody_gid | cut -f1 -d":"`
echo "nobody:x:$nobody_uid:$nobody_gid:nobody:/empty:$false_bin" >> "$passwd_out"
check_errors
echo "$nobody_gid_name:x:$nobody_gid:" >> "$group_out"
check_errors

#try to manually add "nobody" group if it exist and not already added
nobody_gr_name=`2>/dev/null getent group nobody | cut -f1 -d":"`
if [[ ! -z $nobody_gr_name ]]; then
  nobody_gr_gid=`2>/dev/null getent group nobody | cut -f3 -d":"`
  cache_add "$nobody_gr_gid" && echo "$nobody_gr_name:x:$nobody_gr_gid:" >> "$group_out"
fi

#try to manually add "nogroup" group if it exist and not already added
nogroup_gr_name=`2>/dev/null getent group nogroup | cut -f1 -d":"`
if [[ ! -z $nogroup_gr_name ]]; then
  nogroup_gr_gid=`2>/dev/null getent group nogroup | cut -f3 -d":"`
  cache_add "$nogroup_gr_gid" && echo "$nogroup_gr_name:x:$nogroup_gr_gid:" >> "$group_out"
fi

exit 0
