ALTER TABLE fieldkit.module_meta ADD COLUMN ordering INT;

UPDATE fieldkit.module_meta SET ordering = 0;

UPDATE fieldkit.module_meta SET ordering = 100 WHERE key = 'fk.diagnostics';

ALTER TABLE fieldkit.module_meta ALTER COLUMN ordering SET NOT NULL;
