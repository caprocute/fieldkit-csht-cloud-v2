UPDATE sensor_meta
SET viz = '[{"name": "D3TimeSeriesGraph", "disabled": false, "minimumGap": 3600, "thresholds": null}, {"name": "D3Map", "disabled": false, "thresholds": null}]'::jsonb
WHERE full_key = 'wh.floodnet.tideFeet';
