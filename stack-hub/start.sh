#!/bin/sh
python /app/app.py &
nginx -g 'daemon off;'
