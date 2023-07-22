# BigQuery. Examples of Simple SQL Queries.

Data from the Ethereum blockchain is available for exploration thanks to the Google service called BigQuery. All historical data is stored in a dedicated public dataset that is updated daily. BigQuery is used for analytics and data aggregation.

BigQuery is a tool that is part of the [Google Cloud Console](https://console.cloud.google.com/welcome?project=thermal-elixir-376710). It is a fully serverless enterprise data warehouse that offers built-in machine learning and business analytics capabilities. It operates in the cloud and scales seamlessly with your data. Data queries are performed using SQL statements.

## Getting started

1. Open the [Google Cloud Console](https://console.cloud.google.com/welcome?project=thermal-elixir-376710).
2. Find the BigQuery tool in the left side menu.
3. Create a project.
4. You can now copy and paste the code examples below into the dedicated SQL query editor and execute them. The SQL queries will fetch specific data and return the results.

## Examples

1. Retrieving account balances sorted in descending order (Top richest accounts in the Ethereum network):

``` sql
SELECT
  address AS Account,
  CAST(eth_balance as NUMERIC) / 1000000000000000000 as Balance
FROM `bigquery-public-data.crypto_ethereum.balances`
ORDER BY eth_balance DESC
LIMIT 50
```

2. Getting the first 50 tokens sorted by totalSupply in descending order:

``` sql
SELECT
  name,
  symbol,
  address,
  CAST(total_supply as  FLOAT64) as TotalSupply
FROM `bigquery-public-data.crypto_ethereum.tokens`
ORDER BY total_supply DESC
LIMIT 50
```

3. Get the number of transactions for a year in the Ethereum network.

``` sql
WITH daily_transactions AS (
  SELECT
    date(block_timestamp) AS Date,
    count(*) AS Count
  FROM `bigquery-public-data.crypto_ethereum.transactions`
  GROUP BY Date
)

SELECT
  EXTRACT(YEAR FROM date_trunc(Date, YEAR)) AS Year,
  CAST(SUM(Count) AS INT64) AS Count
FROM daily_transactions
GROUP BY Year
ORDER BY Year ASC
```
