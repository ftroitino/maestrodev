#!/bin/bash

echo "*** PAYMENT ENABLER STATUS ENVIRONMENT ***"
# Ensure working path...
cd $(dirname $(readlink -f $0))
echo "[INFO] Working path... $(pwd)"


function help()
{
  echo "The smoketest process"
  echo "Howto use:"
  echo "  $0 <enviromentToTest> [environmentTestConfigFile] [--help]"
  echo ""
  echo "Parameters:"
  echo "  <enviromentToTest> Environment to test"
  echo "  [environmentTestConfigFile] File of configuration environment tests. Default is use config inside this script at bottom"
  echo "  [--help] This help text"
  echo ""
}


function testParameters()
{
  help=$(echo $* | grep "\-\-help")
  if [ -n "$help" ]; then
    help
    exit 0
  fi
  if [ "$#" == "1" -o "$#" == "3" ]; then
    ENVIRONMENT_TO_TEST="$1"
    ENVIRONMENT_TEST_CONFIG_FILE="environment_test_config_file.conf"
    LINE_SEPARATOR=$(grep -n "##################### ENVIRONMENT CONFIG TEXT ############################" $0 | grep -v "grep" | sed s:"\:##################### ENVIRONMENT CONFIG TEXT ############################":"":g)
    sed 1,${LINE_SEPARATOR}d $0 > ${ENVIRONMENT_TEST_CONFIG_FILE}
    if [ "$#" == "3" ]; then
      PE_HOST="$2"
      PE_PORT="$3"
    fi
  else
    if [ "$#" == "2" ]; then
      ENVIRONMENT_TO_TEST="$1"
      if [ -f "$2" ]; then
        ENVIRONMENT_TEST_CONFIG_FILE="$2"
      else
        echo "[ERROR] File not found [$2]"
        return 1
      fi
    else
      echo "[ERROR] Incorrect number of parameters"
      help
      return 1
    fi
  fi
  return 0
}


function getEnvironmentConfig()
{
  ENVIRONMENT_CONFIG_TXT="$(cat ${ENVIRONMENT_TEST_CONFIG_FILE} | grep "^${ENVIRONMENT_TO_TEST}#|#")"
}


function init()
{
  PAUSE_SECONDS="10"
  testParameters $*
  errorCode=$?
  if [ "$errorCode" != "0" ]; then
    return $errorCode
  fi
}


function callHTTP()
{
  CALL_HTTP_RESULT_TEXT="$(curl -4sSiN -m 5 "$1" 2>&1)"
  CALL_HTTP_RESULT_CODE="$(echo "${CALL_HTTP_RESULT_TEXT}" | grep "HTTP/1.1 200 OK" | awk '{print $2}')"
  case ${CALL_HTTP_RESULT_CODE} in
    200)
      return 0
    ;;
    *)
      return 1
    ;;
  esac
}


function main()
{
  init $*
  errorCode=$?
  if [ "$errorCode" != "0" ]; then
    return $errorCode
  fi

  echo "[INFO] Environment Test Config File [${ENVIRONMENT_TEST_CONFIG_FILE}]"
  echo "[INFO] Environment request to test [${ENVIRONMENT_TO_TEST}]"

  # Obtain what all configuration for environment to test
  echo "[INFO] Finding configuration for environment [${ENVIRONMENT_TO_TEST}]"
  getEnvironmentConfig
  if [ "${ENVIRONMENT_CONFIG_TXT}" == "" ]; then
    echo "[ERROR] Not exist anything to test for environment [${ENVIRONMENT_TO_TEST}]"
    return 1
  fi
  echo "[INFO] Configuration exist, it is:"
  echo "${ENVIRONMENT_CONFIG_TXT}"

  echo "[INFO] Waiting ${PAUSE_SECONDS} seconds for init applications before testing"
  sleep ${PAUSE_SECONDS}

  GLOBAL_STATUS_CODE=0
  while read CONFIG_LINE
  do
    MY_ENVIRONMENT="$(awk 'BEGIN { FS = "[/#][/|][/#]" }; {print $1};' < <(echo "${CONFIG_LINE}"))"
    URL_TO_TEST="$(eval echo "$(awk 'BEGIN { FS = "[/#][/|][/#]" }; {print $2};' < <(echo "${CONFIG_LINE}"))")"
    echo ""
    callHTTP "${URL_TO_TEST}"
    A_STATUS_CODE=$?
    if [ "${A_STATUS_CODE}" == "0" ]; then
      printf "[INFO] For [${MY_ENVIRONMENT}] Testing URL: ${URL_TO_TEST}... OK\n"
      # Find software version
      [[ "${URL_TO_TEST}" =~ /version$ ]] && printf "[INFO] The software version is:\n%s\n" "${CALL_HTTP_RESULT_TEXT}"
      [[ "${URL_TO_TEST}" =~ /version/database$ ]] && printf "[INFO] Checking database connectivity...\n"
      if [[ "${URL_TO_TEST}" =~ /version/database$ ]]; then
        if [ "$(echo "${CALL_HTTP_RESULT_TEXT}" | grep "ORA\-")" == "" ]; then
          printf "[INFO] Database connectivity... OK\n"
        else
          printf "[ERROR] Database connectivity... FAILED\n"
          GLOBAL_STATUS_CODE=1
        fi
      fi
      [[ "${URL_TO_TEST}" =~ /version/database$ ]] && printf "[INFO] The database info is:\n%s\n" "${CALL_HTTP_RESULT_TEXT}"
    else
      printf "[ERROR] For [${MY_ENVIRONMENT}] Testing URL: ${URL_TO_TEST}... FAILED\n"
      GLOBAL_STATUS_CODE=1
      echo "${CALL_HTTP_RESULT_TEXT}"
    fi
  done <<< "${ENVIRONMENT_CONFIG_TXT}"
  echo ""

  return ${GLOBAL_STATUS_CODE}
}


main $*
exit $?


##################### ENVIRONMENT CONFIG TEXT ############################
#--------------+------------------------------------
# Enviroment   | URLS
#--------------+------------------------------------
qa#|#http://pe-qa-be.hi.inet:8080
qa#|#http://pe-qa-be.hi.inet:8080/payment/version
qa#|#http://pe-qa-be.hi.inet:8080/payment/version/database
qa#|#http://pe-qa-be.hi.inet:8080/payment/v2?_wadl
qa#|#http://pe-qa-be.hi.inet:8080/payment/v2/transactions?_wadl

qaint#|#http://pe-qaint-be.hi.inet:8080
qaint#|#http://pe-qaint-be.hi.inet:8080/payment/version
qaint#|#http://pe-qaint-be.hi.inet:8080/payment/version/database
qaint#|#http://pe-qaint-be.hi.inet:8080/payment/v2?_wadl
qaint#|#http://pe-qaint-be.hi.inet:8080/payment/v2/transactions?_wadl

clonmirror#|#http://pe-clonmirror-be.hi.inet:8080
clonmirror#|#http://pe-clonmirror-be.hi.inet:8080/payment/version
clonmirror#|#http://pe-clonmirror-be.hi.inet:8080/payment/version/database
clonmirror#|#http://pe-clonmirror-be.hi.inet:8080/payment/v2?_wadl
clonmirror#|#http://pe-clonmirror-be.hi.inet:8080/payment/v2/transactions?_wadl

localhost#|#http://localhost:8080
localhost#|#http://localhost:8080/payment/version
localhost#|#http://localhost:8080/payment/version/database
localhost#|#http://localhost:8080/payment/v2?_wadl
localhost#|#http://localhost:8080/payment/v2/transactions?_wadl

MaestroDev#|#http://${PE_HOST}:${PE_PORT}
MaestroDev#|#http://${PE_HOST}:${PE_PORT}/payment/version
MaestroDev#|#http://${PE_HOST}:${PE_PORT}/payment/version/database
MaestroDev#|#http://${PE_HOST}:${PE_PORT}/payment/v2?_wadl
MaestroDev#|#http://${PE_HOST}:${PE_PORT}/payment/v2/transactions?_wadl
