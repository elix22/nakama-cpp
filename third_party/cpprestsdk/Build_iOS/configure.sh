#!/usr/bin/env bash
set -e

usage() {
    echo "Usage: configure.sh [-build_type type] [-deployment_target version] [-config_only] [-include_32bit] [-no_bitcode]"
    echo "       -build_type defines the CMAKE_BUILD_TYPE used. Defaults to Release."
    echo "       -deployment_target defines minimum iOS Deployment Target. The default is dependent on ios.toolchain.cmake and currently defaults to 8.0"
    echo "       -config_only only configures cmake (no make invoked)."
    echo "       -include_32bit includes the 32-bit arm architectures."
    echo "       -no_bitcode disables bitcode"
    echo "       -clean deletes build directory prior to configuring"
}

ABS_PATH="`dirname \"$0\"`"                 # relative
ABS_PATH="`( cd \"${ABS_PATH}\" && pwd )`"  # absolutized and normalized
# Make sure that the path to this file exists and can be retrieved!
if [ -z "${ABS_PATH}" ]; then
  echo "Could not fetch the ABS_PATH."
  exit 1
fi

CONFIG_ONLY=0
INCLUDE_32BIT=""
DISABLE_BITCODE=""
DEPLOYMENT_TARGET=""
CLEAN=0

# Command line argument parsing
while (( "$#" )); do
    case "$1" in
        -build_type)
            if [ "$#" -lt 2 ] || [[ "$2" == -* ]] ; then
                usage
                echo "Error: argument $1 expecting a value to follow."
                exit 1
            fi

            CPPRESTSDK_BUILD_TYPE=$2
            shift 2
            ;;
        -deployment_target)
            if [ "$#" -lt 2 ] || [[ "$2" == -* ]] ; then
                usage
                echo "Error: argument $1 expecting a value to follow."
                exit 1
            fi

            DEPLOYMENT_TARGET="-DDEPLOYMENT_TARGET=$2"
            shift 2
            ;;
        -config_only)
            CONFIG_ONLY=1
            shift 1
            ;;
        -include_32bit)
            INCLUDE_32BIT="-DINCLUDE_32BIT=ON"
            shift 1
            ;;
        -no_bitcode)
            DISABLE_BITCODE="-DDISABLE_BITCODE=ON"
            shift 1
            ;;
        -clean)
            CLEAN=1
            shift 1
            ;;
        *)
            usage
            echo "Error: unsupported argument $1"
            exit 1
            ;;
    esac
done

## Configuration
DEFAULT_BOOST_VERSION=1.67.0
DEFAULT_OPENSSL_VERSION=1.0.2o
BOOST_VERSION=${BOOST_VERSION:-${DEFAULT_BOOST_VERSION}}
OPENSSL_VERSION=${OPENSSL_VERSION:-${DEFAULT_OPENSSL_VERSION}}
CPPRESTSDK_BUILD_TYPE=${CPPRESTSDK_BUILD_TYPE:-Release}

############################ No need to edit anything below this line

## Set some needed variables
IOS_SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`

## Buildsteps below

## Fetch submodules just in case
git submodule update --init

## Build Boost

if [ ! -e $ABS_PATH/boost.framework ] && [ ! -d $ABS_PATH/boost ]; then
    if [ ! -d "${ABS_PATH}/Apple-Boost-BuildScript" ]; then
        git clone https://github.com/faithfracture/Apple-Boost-BuildScript ${ABS_PATH}/Apple-Boost-BuildScript
    fi
    pushd ${ABS_PATH}/Apple-Boost-BuildScript
    git checkout 1b94ec2e2b5af1ee036d9559b96e70c113846392
    BOOST_LIBS="thread chrono filesystem regex system random" ./boost.sh -ios -tvos --boost-version $BOOST_VERSION
    popd
    mv ${ABS_PATH}/Apple-Boost-BuildScript/build/boost/${BOOST_VERSION}/ios/framework/boost.framework ${ABS_PATH}
    mv ${ABS_PATH}/boost.framework/Versions/A/Headers ${ABS_PATH}/boost.headers
    mkdir -p ${ABS_PATH}/boost.framework/Versions/A/Headers
    mv ${ABS_PATH}/boost.headers ${ABS_PATH}/boost.framework/Versions/A/Headers/boost
fi

## Fetch CMake toolchain

if [ ! -e ${ABS_PATH}/ios-cmake/ios.toolchain.cmake ]; then
    if [ ! -d "${ABS_PATH}/ios-cmake" ]; then
        git clone https://github.com/leetal/ios-cmake ${ABS_PATH}/ios-cmake
    fi
    pushd ${ABS_PATH}/ios-cmake
    git checkout 2.1.2
    popd
fi

mkdir -p ${ABS_PATH}/build.${CPPRESTSDK_BUILD_TYPE}.ios
pushd ${ABS_PATH}/build.${CPPRESTSDK_BUILD_TYPE}.ios
cmake -DCMAKE_BUILD_TYPE=${CPPRESTSDK_BUILD_TYPE} .. ${INCLUDE_32BIT} ${DISABLE_BITCODE} ${DEPLOYMENT_TARGET}
if [ "$CONFIG_ONLY" -eq 0 ]; then
    make
    printf "\n\n===================================================================================\n"
    echo ">>>> The final library is available in 'build.${CPPRESTSDK_BUILD_TYPE}.ios/lib/libcpprest.a'"
    printf "===================================================================================\n\n"
else
    printf "\n\n===================================================================================\n"
    echo ">>>> Configuration complete. Run 'make' in 'build.${CPPRESTSDK_BUILD_TYPE}.ios' to build."
    printf "===================================================================================\n\n"
fi
popd
