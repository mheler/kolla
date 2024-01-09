#!/bin/bash

mkdir -p "/run/openvswitch"
if [[ ! -e "/var/lib/openvswitch/conf.db" ]]; then
    ovsdb-tool create "/var/lib/openvswitch/conf.db"
fi

if ([ -f /var/lib/openvswitch/conf.db ] && [ `ovsdb-tool needs-conversion /var/lib/openvswitch/conf.db` == "yes" ]); then
    /usr/bin/ovsdb-tool convert /var/lib/openvswitch/conf.db
fi
