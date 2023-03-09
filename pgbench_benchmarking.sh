#!/bin/bash

# Set the database connection parameters
HOST="localhost"
PORT="5432"
DB_NAME="mydb"
USER="myuser"
PASSWORD="mypassword"

# Set the scale factor for generating the test data
SCALE_FACTOR=5000

# Create the test data with pgbench
pgbench -i -s $SCALE_FACTOR -h $HOST -p $PORT -U $USER -d $DB_NAME

# Run the test to generate 5GB of data
pgbench -c 10 -j 2 -t 1000000 -h $HOST -p $PORT -U $USER -d $DB_NAME

# Define the queries to test
QUERIES=(
    "SELECT COUNT(*) FROM pgbench_accounts WHERE abalance > 0;"
    "SELECT AVG(abalance) FROM pgbench_accounts WHERE abalance > 0;"
    "SELECT COUNT(*) FROM pgbench_tellers WHERE tbalance > 0;"
    "SELECT AVG(tbalance) FROM pgbench_tellers WHERE tbalance > 0;"
    "SELECT COUNT(*) FROM pgbench_branches WHERE bbalance > 0;"
    "SELECT AVG(bbalance) FROM pgbench_branches WHERE bbalance > 0;"
)

# Run each query and capture the average query time
for QUERY in "${QUERIES[@]}"; do
    AVG_TIME=$(pgbench -c 1 -j 1 -t 10 -h $HOST -p $PORT -U $USER -d $DB_NAME -q -P 5 -f <(echo "$QUERY") | awk '{print $4}')
    echo "Average time for query: $QUERY is $AVG_TIME ms"
done
