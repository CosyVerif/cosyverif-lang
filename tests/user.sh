#! /bin/bash

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <server-alias> <cosy command> <options>"
  echo "for instance: $0 myserver /home/cosy/bin/cosy --alias=myalias"
  exit
fi

server="$1"
shift
cosy="$1"
shift
options=$*

bin_dir=$(dirname "${cosy}")

passwords=$(mktemp 2>/dev/null || mktemp -t cosy-user)
echo "password" >> "${passwords}"
echo "password" >> "${passwords}"

token=$("${bin_dir}/lua" -e " \
local file = io.open '${HOME}/.cosy/${server}/server.data' \
if file then
  local data = file:read '*all' \
  data       = loadstring ('return ' .. data) () \
  print (data.token)
end")
if [ "${token}" = "" ]; then
  echo "No administration token found"
  exit 1
fi

#echo "Stopping daemon:"
#"${cosy}" daemon:stop --force
#echo "Stopping server:"
#"${cosy}" server:stop  --force
#echo "Starting server:"
#"${cosy}" server:start --force --clean
echo "Printing available methods:"
"${cosy}" ${options} --help
echo "Server information:"
"${cosy}" ${options} server:information
echo "Terms of Service:"
"${cosy}" ${options} server:tos
echo "Creating user alinard:"
"${cosy}" ${options} user:create --administration ${token} "alban.linard@gmail.com" alinard < "${passwords}"
echo "Failing at creating user alban:"
"${cosy}" ${options} user:create --administration ${token} "alban.linard@gmail.com" alban < "${passwords}"
echo "Creating user alban:"
"${cosy}" ${options} user:create --administration ${token} "jiahua.xu16@gmail.com" alban < "${passwords}"
echo "Authenticating user alinard:"
"${cosy}" ${options} user:authenticate alinard < "${passwords}"
echo "Authenticating user alban:"
"${cosy}" ${options} user:authenticate alban < "${passwords}"
echo "Updating user alban:"
"${cosy}" ${options} user:update --name="Alban Linard" --email="alban.linard@lsv.ens-cachan.fr"
echo "Sending validation again:"
"${cosy}" ${options} user:send-validation
echo "Showing user alban:"
"${cosy}" ${options} user:information alban
echo "Deleting user alban:"
"${cosy}" ${options} user:delete
echo "Failing at authenticating user alban:"
"${cosy}" ${options} user:authenticate alban < "${passwords}"
echo "Authenticating user alinard:"
"${cosy}" ${options} user:authenticate alinard < "${passwords}"
echo "Creating project"
"${cosy}" ${options} project:create dd
for type in formalism model service execution scenario
do
  echo "Creating ${type} in project"
  "${cosy}" ${options} ${type}:create instance-${type} alinard/dd
done
echo "Iterating over users"
"${cosy}" ${options} server:filter 'return function (coroutine, store)
    for user in store / "data" * ".*" do
      coroutine.yield (user)
    end
  end'
echo "Iterating over projects"
"${cosy}" ${options} server:filter 'return function (coroutine, store)
    for project in store / "data" * ".*" * ".*" do
      coroutine.yield (project)
    end
  end'
echo "Deleting project"
"${cosy}" ${options} project:delete alinard/dd
echo "Deleting user alinard:"
"${cosy}" ${options} user:delete

rm "${passwords}"
