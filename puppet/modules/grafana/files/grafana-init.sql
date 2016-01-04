INSERT INTO `dashboard` VALUES (1,11,'zuul','Zuul','{\"annotations\":{\"list\":[]},\"editable\":true,\"hideControls\":false,\"id\":1,\"links\":[],\"nav\":[{\"collapse\":false,\"enable\":true,\"notice\":false,\"now\":true,\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"status\":\"Stable\",\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"],\"type\":\"timepicker\"}],\"originalTitle\":\"Zuul\",\"rows\":[{\"collapse\":false,\"editable\":true,\"height\":\"250px\",\"panels\":[{\"aliasColors\":{},\"bars\":false,\"datasource\":\"Gnocchi\",\"editable\":true,\"error\":false,\"fill\":1,\"grid\":{\"leftLogBase\":1,\"leftMax\":null,\"leftMin\":null,\"rightLogBase\":1,\"rightMax\":null,\"rightMin\":null,\"threshold1\":null,\"threshold1Color\":\"rgba(216, 200, 27, 0.27)\",\"threshold2\":null,\"threshold2Color\":\"rgba(234, 112, 112, 0.22)\"},\"id\":1,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":2,\"links\":[],\"nullPointMode\":\"connected\",\"percentage\":false,\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"span\":6,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"aggregator\":\"std\",\"errors\":null,\"label\":\"patchset-created\",\"metric_name\":\"gerrit.event.patchset-created|c\",\"queryMode\":\"resource\",\"refId\":\"E\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_type\":\"generic\",\"target\":\"alias(stats.gauges.zuul.pipeline.tag.current_changes, \'tag\')\"},{\"aggregator\":\"std\",\"errors\":null,\"label\":\"comment-added\",\"metric_name\":\"gerrit.event.comment-added|c\",\"queryMode\":\"resource\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_type\":\"generic\",\"target\":\"\"},{\"aggregator\":\"std\",\"errors\":null,\"label\":\"change-merged\",\"metric_name\":\"gerrit.event.change-merged|c\",\"queryMode\":\"resource\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_type\":\"generic\",\"target\":\"\"}],\"timeFrom\":null,\"timeShift\":null,\"title\":\"Gerrit events\",\"tooltip\":{\"shared\":true,\"value_type\":\"cumulative\"},\"type\":\"graph\",\"x-axis\":true,\"y-axis\":true,\"y_formats\":[\"short\",\"short\"]},{\"aliasColors\":{},\"bars\":false,\"datasource\":\"Gnocchi\",\"editable\":true,\"error\":false,\"fill\":1,\"grid\":{\"leftLogBase\":1,\"leftMax\":null,\"leftMin\":null,\"rightLogBase\":1,\"rightMax\":null,\"rightMin\":null,\"threshold1\":null,\"threshold1Color\":\"rgba(216, 200, 27, 0.27)\",\"threshold2\":null,\"threshold2Color\":\"rgba(234, 112, 112, 0.22)\"},\"id\":2,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":2,\"links\":[],\"nullPointMode\":\"connected\",\"percentage\":false,\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"span\":6,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"aggregator\":\"sum\",\"errors\":null,\"label\":\"check\",\"metric_name\":\"zuul.pipeline.check.current_changes|g\",\"queryMode\":\"resource\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_search\":\"{\'=\': {\'id\': \'396cfeb2-be4c-48b5-a150-86420ba287b9\'}}\",\"resource_type\":\"generic\",\"target\":\"\"},{\"aggregator\":\"sum\",\"errors\":null,\"label\":\"gate\",\"metric_name\":\"zuul.pipeline.gate.current_changes|g\",\"queryMode\":\"resource\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_type\":\"generic\",\"target\":\"\"},{\"aggregator\":\"sum\",\"errors\":null,\"label\":\"periodic\",\"metric_name\":\"zuul.pipeline.periodic.current_changes|g\",\"queryMode\":\"resource\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_type\":\"generic\",\"target\":\"\"},{\"aggregator\":\"sum\",\"errors\":null,\"label\":\"post\",\"metric_name\":\"zuul.pipeline.post.current_changes|g\",\"queryMode\":\"resource\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_type\":\"generic\",\"target\":\"\"},{\"aggregator\":\"sum\",\"errors\":null,\"label\":\"tag\",\"metric_name\":\"zuul.pipeline.tag.current_changes|g\",\"queryMode\":\"resource\",\"resource_id\":\"f66370ee-be2a-451e-bf5d-45b9a554ce03\",\"resource_type\":\"generic\",\"target\":\"\"}],\"timeFrom\":null,\"timeShift\":null,\"title\":\"Zuul events\",\"tooltip\":{\"shared\":true,\"value_type\":\"cumulative\"},\"type\":\"graph\",\"x-axis\":true,\"y-axis\":true,\"y_formats\":[\"short\",\"short\"]}],\"title\":\"Row\"}],\"schemaVersion\":6,\"sharedCrosshair\":false,\"style\":\"dark\",\"tags\":[],\"templating\":{\"list\":[]},\"time\":{\"from\":\"now-6h\",\"to\":\"now\"},\"timezone\":\"browser\",\"title\":\"Zuul\",\"version\":11}',1,'0001-01-01 00:00:00','0001-01-01 00:00:00');

INSERT INTO `data_source` VALUES (1,1,0,'grafana','Grafana','proxy','http://localhost:8010/','','','',0,'','',1,'null','2015-11-12 12:16:17','2016-01-06 09:33:04'),(2,1,0,'gnocchi','Gnocchi','proxy','http://localhost:8041/','','','',0,'','',0,'{\"password\":\"\",\"username\":\"\"}','2016-01-06 09:33:23','2016-01-06 09:33:26');
