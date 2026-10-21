-- Run against the source while the DMS task is in CDC to see live changes replicate.
INSERT INTO orders (customer_id, amount)
SELECT 1 + floor(random() * 100)::int, round((random() * 500)::numeric, 2)
FROM generate_series(1, 10);

UPDATE orders SET status = 'PAID'
WHERE id IN (SELECT id FROM orders WHERE status = 'NEW' ORDER BY random() LIMIT 3);

DELETE FROM orders
WHERE id IN (SELECT id FROM orders WHERE status = 'SHIPPED' ORDER BY random() LIMIT 1);
