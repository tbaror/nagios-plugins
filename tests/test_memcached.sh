#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-05-25 01:38:24 +0100 (Mon, 25 May 2015)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$srcdir/..";

. ./tests/utils.sh

echo "
# ============================================================================ #
#                               M e m c a c h e d
# ============================================================================ #
"

export MEMCACHED_VERSIONS="${@:-${MEMCACHED_VERSIONS:-latest 1.4}}"

MEMCACHED_HOST="${DOCKER_HOST:-${MEMCACHED_HOST:-${HOST:-localhost}}}"
MEMCACHED_HOST="${MEMCACHED_HOST##*/}"
MEMCACHED_HOST="${MEMCACHED_HOST%%:*}"
export MEMCACHED_HOST

export MEMCACHED_PORT=11211

check_docker_available

startupwait 1

test_memcached(){
    local version="$1"
    echo "Setting up Memcached $version test container"
    #launch_container "$DOCKER_IMAGE:$version" "$DOCKER_CONTAINER" $MEMCACHED_PORT
    VERSION="$version" docker-compose up -d
    memcached_port="`docker-compose port "$DOCKER_SERVICE" "$MEMCACHED_PORT" | sed 's/.*://'`"
    when_ports_available "$startupwait" "$MEMCACHED_HOST" "$memcached_port"
    hr
    echo "creating test Memcached key-value"
    echo -ne "add myKey 0 100 4\r\nhari\r\n" | nc "$MEMCACHED_HOST" "$memcached_port"
    echo done
    if [ -n "${NOTESTS:-}" ]; then
        return 0
    fi
    hr
    # MEMCACHED_HOST obtained via .travis.yml
    $perl -T ./check_memcached_write.pl -P "$memcached_port" -v
    hr
    $perl -T ./check_memcached_key.pl -P "$memcached_port" -k myKey -e hari -v
    hr
    $perl -T ./check_memcached_stats.pl -P "$memcached_port" -w 15 -c 20 -v
    hr
    #delete_container
    docker-compose down
    hr
    echo
}

for version in $(ci_sample $MEMCACHED_VERSIONS); do
    test_memcached $version
done
