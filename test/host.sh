#!/bin/bash

declare arg

for arg in '--alias' '--all-fqdns' '--boot' '--domain' '--fqdn' '--ip-address' '--all-ip-addresses' '--short' '--yp';do
    echo "hostname $(printf '%-19s:' $arg) $(hostname $arg)"
done
