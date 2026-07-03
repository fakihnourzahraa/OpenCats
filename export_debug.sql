SELECT SQL_CALC_FOUND_ROWS 
                candidate.candidate_id AS candidateID,
                candidate.candidate_id AS exportID,
                candidate.is_hot AS isHot,
                candidate.date_modified AS dateModifiedSort,
                candidate.date_created AS dateCreatedSort,
            candidate.first_name AS firstName,
candidate.last_name AS lastName,
candidate.email1 AS email1,
candidate.phone_home AS phoneHome
            FROM
                candidate
             LEFT JOIN saved_list_entry
                                    ON saved_list_entry.data_item_type = 100
                                    AND saved_list_entry.data_item_id = candidate.candidate_id
                                    AND saved_list_entry.site_id = 1
            WHERE
                candidate.site_id = 1
            
            
            
            GROUP BY candidate.candidate_id
            
            ORDER BY dateModifiedSort DESC
            LIMIT 0, 15