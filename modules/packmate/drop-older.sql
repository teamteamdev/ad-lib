BEGIN;
SELECT id INTO TEMP tmp_streams FROM stream WHERE end_timestamp < (EXTRACt(EPOCH FROM NOW()) - @olderThan@) * 1000;
SELECT id INTO TEMP tmp_packets FROM packet WHERE stream_id IN (SELECT id FROM tmp_streams);

WITH
  tmp AS (DELETE FROM packet_matches WHERE packet_id IN (SELECT id FROM tmp_packets) RETURNING matches_id)
SELECT matches_id INTO TEMP tmp_matches FROM tmp;

DELETE FROM found_pattern WHERE id IN (SELECT matches_id FROM tmp_matches);
DELETE FROM packet WHERE id IN (SELECT id FROM tmp_packets);

DELETE FROM stream_found_patterns WHERE matched_streams_id IN (SELECT id FROM tmp_streams);
DELETE FROM stream WHERE id IN (SELECT id FROM tmp_streams);
COMMIT;
