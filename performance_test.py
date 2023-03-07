import time
import psycopg2
import random
import string

# Set database connection parameters
conn_params = {
    'host': 'my-cluster-endpoint.postgres.database.azure.com',
    'port': 5432,
    'database': 'mydatabase',
    'user': 'myuser@my-cluster-endpoint',
    'password': 'mypassword'
}

# Connect to the database
conn = psycopg2.connect(**conn_params)
cur = conn.cursor()

# Set the number of rows to insert and query
num_rows = 100000  # adjust as needed to test different amounts of data
num_queries = 1000  # adjust as needed to test different query performance

# Generate and execute SQL insert statements
start_time = time.time()
for i in range(num_rows):
    # Generate random data for each column
    col1 = ''.join(random.choices(string.ascii_uppercase + string.digits, k=10))
    col2 = random.randint(1, 100)
    col3 = ''.join(random.choices(string.ascii_uppercase + string.digits, k=20))
    col4 = random.randint(1, 10000)

    # Construct the SQL statement
    sql = f"INSERT INTO mytable (col1, col2, col3, col4) VALUES ('{col1}', {col2}, '{col3}', {col4})"

    # Execute the SQL statement
    cur.execute(sql)

# Commit the changes
conn.commit()
insert_time = time.time() - start_time

# Generate and execute SQL select statements
start_time = time.time()
for i in range(num_queries):
    # Generate a random ID to query
    id = random.randint(1, num_rows)

    # Construct the SQL statement
    sql = f"SELECT * FROM mytable WHERE id = {id}"

    # Execute the SQL statement
    cur.execute(sql)

# Close the cursor and connection
select_time = time.time() - start_time
cur.close()
conn.close()

# Print the results
print(f"Inserted {num_rows} rows in {insert_time:.2f} seconds")
print(f"Executed {num_queries} queries in {select_time:.2f} seconds")
