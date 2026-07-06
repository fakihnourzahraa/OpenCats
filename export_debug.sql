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
candidate.gpa AS gpa,
candidate.nationality AS nationality,
candidate.source AS source,
extra_field0.value AS extra_field_value0
            FROM
                candidate
            LEFT JOIN extra_field AS extra_field0 ON candidate.candidate_id = extra_field0.data_item_id AND extra_field0.field_name = 'Testinggg' AND extra_field0.data_item_type = 100 LEFT JOIN saved_list_entry
                                    ON saved_list_entry.data_item_type = 100
                                    AND saved_list_entry.data_item_id = candidate.candidate_id
                                    AND saved_list_entry.site_id = 1
            WHERE
                candidate.site_id = 1
            
             AND candidate.candidate_id IN (2,3)
            
            GROUP BY candidate.candidate_id
            
            ORDER BY dateModifiedSort DESC
            