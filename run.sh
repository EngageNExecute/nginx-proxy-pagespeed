#!/bin/bash

docker run -ti --rm --name nginx-proxy-pagespeed -v /var/run/docker.sock:/tmp/docker.sock:ro engagenexecute/nginx-proxy-pagespeed ${@}
