#!/bin/bash
psql -p 5413 -f tuid_test.sql --echo-all
