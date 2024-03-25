# BigQuery. Examples of Simple SQL Queries.

Ethereum blockchain data is available for exploration thanks to Google's service. All historical data is stored in a special public dataset that is updated daily. BigQuery is used for collecting analytics and aggregating data.

BigQuery is a tool that is part of the [Google Cloud Console](https://console.cloud.google.com/welcome?project=thermal-elixir-376710). It is a fully serverless enterprise data warehouse. It features built-in machine learning and business analytics functions that operate in the cloud and scale with your data. Data queries are made using SQL queries.

## Getting started

1. Open [Google Cloud Console](https://console.cloud.google.com/welcome?project=thermal-elixir-376710)
2. Find the BigQuery tool in the left sidebar
3. Create a project
4. After that, you can insert the code from the examples below into the special SQL query editor and run it. In response, the SQL queries will perform a certain selection and return data.

## Examples

1. Retrieving account balances sorted in descending order (Top richest accounts in the Ethereum network)

``` sql
SELECT
  address AS Account,
  CAST(eth_balance as NUMERIC) / 1000000000000000000 as Balance
FROM `bigquery-public-data.crypto_ethereum.balances`
ORDER BY eth_balance DESC
LIMIT 50
```

2. Get the first 50 tokens sorted by totalSupply in descending order

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

3. Get the number of transactions per year on the Ethereum network

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

