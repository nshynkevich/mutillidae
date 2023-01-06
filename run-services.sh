#!/bin/bash

for serv in "php8.1-fpm" "mysql" "apache2"; do
	sstat=$(pgrep "${serv}" | wc -l ); 
	if [ $sstat -gt 0 ]; then 
		echo "${serv} already running"; 
	else
		echo "${serv} starting .. "; 
		service ${serv} start; 
		echo "${serv} UP now"; fi ; done ; 

sleep infinity & wait