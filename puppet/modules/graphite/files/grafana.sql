INSERT INTO "dashboard" VALUES(1,3,'zuul','Zuul','{"annotations":{"list":[]},"editable":true,"hideControls":false,"id":1,"links":[],"originalTitle":"Zuul","rows":[{"collapse":false,"editable":true,"height":"250px","panels":[{"aliasColors":{},"bars":false,"datasource":null,"editable":true,"error":false,"fill":1,"grid":{"leftLogBase":1,"leftMax":null,"leftMin":null,"rightLogBase":1,"rightMax":null,"rightMin":null,"threshold1":null,"threshold1Color":"rgba(216, 200, 27, 0.27)","threshold2":null,"threshold2Color":"rgba(234, 112, 112, 0.22)"},"id":1,"legend":{"avg":false,"current":false,"max":false,"min":false,"show":true,"total":false,"values":false},"lines":true,"linewidth":2,"links":[],"nullPointMode":"connected","percentage":false,"pointradius":5,"points":false,"renderer":"flot","seriesOverrides":[],"span":12,"stack":false,"steppedLine":false,"targets":[{"hide":false,"refId":"A","target":"alias(stats.gauges.zuul.pipeline.check.current_changes, ''check'')"},{"refId":"B","target":"alias(stats.gauges.zuul.pipeline.gate.current_changes, ''gate'')"},{"refId":"C","target":"alias(stats.gauges.zuul.pipeline.periodic.current_changes, ''periodic'')"}],"timeFrom":null,"timeShift":null,"title":"Zuul checks","tooltip":{"shared":true,"value_type":"cumulative"},"type":"graph","x-axis":true,"y-axis":true,"y_formats":["short","short"]}],"title":"Row"}],"schemaVersion":7,"sharedCrosshair":false,"style":"dark","tags":[],"templating":{"list":[]},"time":{"from":"now-1h","to":"now"},"timepicker":{"now":true,"refresh_intervals":["5s","10s","30s","1m","5m","15m","30m","1h","2h","1d"],"time_options":["5m","15m","1h","6h","12h","24h","2d","7d","30d"]},"timezone":"browser","title":"Zuul","version":3}',1,'0001-01-01 00:00:00','0001-01-01 00:00:00');
INSERT INTO "data_source" VALUES(1,1,0,'graphite','graphite','proxy','http://localhost:8010/','','','',0,'','',1,'null','2015-11-12 12:16:17','2015-11-12 12:16:22');
