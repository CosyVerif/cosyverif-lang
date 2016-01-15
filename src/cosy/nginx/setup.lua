return [==[
#! /usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'

tempwd=$(mktemp -d 2>/dev/null || mktemp -d -t cosy-setup)
log="${tempwd}/setup.log"

for i in "$@"
do
  case ${i} in
    -f=*|--package-uri=*)
      package_uri="${i#*=}"
      package_uri=${package_uri%/}
      shift # past argument=value
    ;;
    -p=*|--prefix=*)
      prefix="${i#*=}"
      prefix=${prefix%/}
      shift # past argument=value
    ;;
    -h|--help)
      echo "Usage: "
      echo "  install [--prefix=PREFIX] [--package-uri=<URI>]"
      exit 1
    ;;
    *)
      echo "Usage: "
      echo "  install [--prefix=PREFIX] [--package-uri=<URI>]"
      exit 1
    ;;
  esac
done

prefix=${prefix:-"/usr/local/"}

function fix_string ()
{
  echo "$1" \
    | sed -e 's/^[[:space:]]+/ /' \
    | sed -e 's/^[[:space:]]*//' \
    | sed -e 's/[[:space:]]*$//' \
    | tr '/' '-' \
    | tr '[:upper:]' '[:lower:]'
}

function get ()
{
  url="$1"
  target="$2"
  if command -v curl >> "${log}" 2>&1; then
    curl --location --output "${target}" "${url}" \
        >> "${log}" 2>&1
    return
  elif command -v wget >> "${log}" 2>&1; then
    wget --output-document="${target}" "${url}" \
        >> "${log}" 2>&1
    return
  else
    echo -e "${red}Error: neither curl nor wget is available.${nc}"
    exit 1;
  fi
}

cd "${tempwd}" || exit 1

if [ -z "${package_uri}" ]; then
  os=$(fix_string "$(uname -s)")
  arch=$(fix_string "$(uname -m)")
  get "https://api.github.com/repos/cosyverif/library/releases/latest" \
      "latest-release.json"
  version=$(grep "tag_name" "latest-release.json" | tr '",' ' ' | tr -d ' \t' | cut -d ":" -f 2)
  package_uri="https://github.com/CosyVerif/library/releases/download/${version}/cosy-client-${os}-${arch}.sh"
fi

echo -e "Temporary directory: ${green}${tempwd}${nc}"
echo -e "Log file           : ${green}${log}${nc}"
echo -e "Prefix             : ${green}${prefix}${nc}"
echo -e "Package URI        : ${green}${package_uri}${nc}"

function error ()
{
  echo -e "${red}An error happened.${nc}"
  echo -e "Please read log file: ${red}${log}${nc}."
  cat "${log}"
  exit 1
}

trap error ERR

echo -e -n "Downloading package ${green}${package_uri}${nc}... "
get "${package_uri}" "install-client.sh" \
  >> "${log}" 2>&1 \
  && echo -e "${green}success${nc}" \
  || echo -e "${red}failure${nc}"

chmod a+x install-client.sh

echo -e -n "Installing package to ${green}${prefix}${nc}... "
./install-client.sh --target "${prefix}" \
  >> "${log}" 2>&1 \
  && echo -e "${green}success${nc}" \
  || echo -e "${red}failure${nc}"

echo -e -n "Testing the cosy command... "
"${prefix}/bin/cosy" --server="ROOT_URI" --help \
  >> "${log}" 2>&1 \
  && echo -e "${green}success${nc}" \
  || echo -e "${red}failure${nc}"

echo "You can now try the following command:"
echo "  ${prefix}/bin/cosy: to run the cosy client"
]==]
