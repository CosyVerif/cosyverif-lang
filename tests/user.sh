#! /bin/bash
if [ -z "$1" ]; then
  echo "usage: $0 path_to_cosy_script"
  echo "ex: $0 /home/cosy/bin/cosy"
  exit
else
  cosy="$1"
fi

passwords=$(mktemp)
echo "password" >> "${passwords}"
echo "password" >> "${passwords}"

token=$(luajit -e " \
local file = io.open '${HOME}/.cosy/server.data' \
if file then
  local data = file:read '*all' \
  data       = loadstring ('return ' .. data) () \
  print (data.token)
end")

#echo "Stopping daemon:"
#"${cosy}" daemon:stop --force
#echo "Stopping server:"
#"${cosy}" server:stop  --force
#echo "Starting server:"
#"${cosy}" server:start --force --clean
echo "Printing available methods:"
"${cosy}" --server=http://127.0.0.1:8080/
echo "Server information:"
"${cosy}" server:information
echo "Terms of Service:"
"${cosy}" server:tos
echo "Creating user alinard:"
"${cosy}" user:create --administration ${token} "alban.linard@gmail.com" alinard < "${passwords}"
echo "Failing at creating user alban:"
"${cosy}" user:create --administration ${token} "alban.linard@gmail.com" alban < "${passwords}"
echo "Creating user alban:"
"${cosy}" user:create --administration ${token} "jiahua.xu16@gmail.com" alban < "${passwords}"
echo "Authenticating user alinard:"
"${cosy}" user:authenticate alinard < "${passwords}"
echo "Authenticating user alban:"
"${cosy}" user:authenticate alban < "${passwords}"
echo "Updating user alban:"
"${cosy}" user:update --name="Alban Linard" --email="alban.linard@lsv.ens-cachan.fr"
echo "Sending validation again:"
"${cosy}" user:send-validation
echo "Showing user alban:"
"${cosy}" user:information alban
echo "Deleting user alban:"
"${cosy}" user:delete
echo "Failing at authenticating user alban:"
"${cosy}" user:authenticate alban < "${passwords}"
echo "Authenticating user alinard:"
"${cosy}" user:authenticate alinard < "${passwords}"
echo "Creating project"
"${cosy}" project:create dd
for type in formalism model service execution scenario
do
  echo "Creating ${type} in project"
  "${cosy}" ${type}:create instance-${type} alinard/dd
done
echo "Iterating over users"
"${cosy}" server:filter 'return function (store)
    for user in store / "data" * ".*" do
      coroutine.yield (user)
    end
  end'
echo "Iterating over projects"
"${cosy}" server:filter 'return function (store)
    for project in store / "data" * ".*" * ".*" do
      coroutine.yield (project)
    end
  end'
echo "Deleting project"
"${cosy}" project:delete alinard/dd
echo "Deleting user alinard:"
"${cosy}" user:delete

rm "${passwords}"
