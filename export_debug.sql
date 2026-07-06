SELECT SQL_CALC_FOUND_ROWS 
                candidate.candidate_id AS candidateID,
                candidate.candidate_id AS exportID,
                candidate.is_hot AS isHot,
                candidate.date_modified AS dateModifiedSort,
                candidate.date_created AS dateCreatedSort,
            IF(candidate_joborder_submitted.candidate_joborder_id, 1, 0) AS submitted,
                                                IF(attachment_id, 1, 0) AS attachmentPresent,
                                                IF(old_candidate_id, 1, 0) AS duplicatePresent,
candidate.first_name AS firstName,
candidate.last_name AS lastName,
candidate.city AS city,
candidate.state AS state,
candidate.key_skills AS keySkills,
owner_user.first_name AS ownerFirstName,owner_user.last_name AS ownerLastName,CONCAT(owner_user.last_name, owner_user.first_name) AS ownerSort,
DATE_FORMAT(candidate.date_created, '%m-%d-%y') AS dateCreated,
DATE_FORMAT(candidate.date_modified, '%m-%d-%y') AS dateModified,
                                                        candidate.date_modified AS dateModifiedSort
            FROM
                candidate
            LEFT JOIN attachment
                                                        ON candidate.candidate_id = attachment.data_item_id
														AND attachment.data_item_type = 100
                                                    LEFT JOIN candidate_joborder AS candidate_joborder_submitted
                                                        ON candidate_joborder_submitted.candidate_id = candidate.candidate_id
                                                        AND candidate_joborder_submitted.status >= 400
                                                        AND candidate_joborder_submitted.site_id = 1
                                                        AND candidate_joborder_submitted.status != 650 LEFT JOIN candidate_duplicates 
                                                        ON candidate.candidate_id = 
                                                        candidate_duplicates.new_candidate_id
LEFT JOIN user AS owner_user ON candidate.owner = owner_user.user_id LEFT JOIN saved_list_entry
                                    ON saved_list_entry.data_item_type = 100
                                    AND saved_list_entry.data_item_id = candidate.candidate_id
                                    AND saved_list_entry.site_id = 1
            WHERE
                candidate.site_id = 1
            
            
            
            GROUP BY candidate.candidate_id
            
            ORDER BY dateModifiedSort DESC
            LIMIT 0, 15