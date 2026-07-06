SELECT SQL_CALC_FOUND_ROWS 
                candidate.candidate_id AS candidateID,
                candidate.candidate_id AS exportID,
                candidate.is_hot AS isHot,
                candidate.date_modified AS dateModifiedSort,
                candidate.date_created AS dateCreatedSort,
            candidate.first_name AS firstName,
candidate.last_name AS lastName,
DATE_FORMAT(candidate.date_created, '%m-%d-%y') AS dateCreated,
DATE_FORMAT(candidate.date_modified, '%m-%d-%y') AS dateModified,
                                                        candidate.date_modified AS dateModifiedSort,
candidate.gpa AS gpa,
candidate.nationality AS nationality,
candidate.source AS source,
extra_field3.value AS extra_field_value3,
extra_field4.value AS extra_field_value4,
extra_field5.value AS extra_field_value5,
extra_field2.value AS extra_field_value2
            FROM
                candidate
            LEFT JOIN extra_field AS extra_field3 ON candidate.candidate_id = extra_field3.data_item_id AND extra_field3.field_name = 'Test Dropdown' AND extra_field3.data_item_type = 100
LEFT JOIN extra_field AS extra_field4 ON candidate.candidate_id = extra_field4.data_item_id AND extra_field4.field_name = 'Test date' AND extra_field4.data_item_type = 100
LEFT JOIN extra_field AS extra_field5 ON candidate.candidate_id = extra_field5.data_item_id AND extra_field5.field_name = 'Test default' AND extra_field5.data_item_type = 100
LEFT JOIN extra_field AS extra_field2 ON candidate.candidate_id = extra_field2.data_item_id AND extra_field2.field_name = 'Test range' AND extra_field2.data_item_type = 100 LEFT JOIN saved_list_entry
                                    ON saved_list_entry.data_item_type = 100
                                    AND saved_list_entry.data_item_id = candidate.candidate_id
                                    AND saved_list_entry.site_id = 1
            WHERE
                candidate.site_id = 1
            
             AND candidate.candidate_id IN (19,18)
            
            GROUP BY candidate.candidate_id
            
            ORDER BY dateModifiedSort DESC
            