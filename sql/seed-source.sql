-- Sample schema and data for the source RDS PostgreSQL database.
-- Every table has a primary key: DMS needs one to replicate UPDATEs and DELETEs.

CREATE TABLE IF NOT EXISTS customers (
  id         serial PRIMARY KEY,
  name       text NOT NULL,
  email      text NOT NULL UNIQUE,
  country    text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id          bigserial PRIMARY KEY,
  customer_id int NOT NULL REFERENCES customers (id),
  amount      numeric(10, 2) NOT NULL,
  status      text NOT NULL DEFAULT 'NEW',
  created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO customers (name, email, country)
SELECT 'Customer ' || g,
       'customer' || g || '@example.com',
       (ARRAY['US', 'UK', 'NG', 'DE', 'FR'])[1 + g % 5]
FROM generate_series(1, 100) AS g
ON CONFLICT (email) DO NOTHING;

INSERT INTO orders (customer_id, amount, status)
SELECT 1 + g % 100,
       round((random() * 500)::numeric, 2),
       (ARRAY['NEW', 'PAID', 'SHIPPED'])[1 + g % 3]
FROM generate_series(1, 1000) AS g
WHERE NOT EXISTS (SELECT 1 FROM orders);
