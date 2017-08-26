#!/bin/bash
target="$1"

bash_bin=`2>/dev/null which bash`
dash_bin=`2>/dev/null which dash`

[[ -z $bash_bin ]] && exit 0
[[ -z $dash_bin ]] && dash_bin="/bin/sh"

shebang=`head -n1 "$target"`

if [[ $shebang = "#!/bin/bash" ]]; then
  result="#!$bash_bin"
elif [[ $shebang = "#!/bin/dash" ]]; then
  result="#!$dash_bin"
elif [[ $shebang = "#!/bin/sh" ]]; then
  echo "Skipping shebang update for file: $target"
  exit 1
else
  echo "Unknown shebang \"$shebang\" detected: $target"
  exit 1
fi

[[ $shebang = $result ]] && exit 0

echo "Updating shebang to \"$result\" for file: $target"
sed -i '1s|.*|'"$result"'|' "$target"
