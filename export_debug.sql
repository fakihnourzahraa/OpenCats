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
candidate.email1 AS email1,
candidate.email2 AS email2,
candidate.phone_home AS phoneHome,
candidate.phone_cell AS phoneCell,
candidate.phone_work AS phoneWork,
candidate.address AS address,
candidate.city AS city,
candidate.state AS state,
candidate.zip AS zip,
candidate.notes AS notes,
candidate.web_site AS webSite,
candidate.key_skills AS keySkills,
(
                                                    SELECT
                                                        CONCAT(
                                                            '<a href="index.php?m=joborders&amp;a=show&amp;jobOrderID=',
                                                            joborder.joborder_id,
                                                            '" title="',
                                                            joborder.title,
                                                            ' (',
                                                            company.name,
                                                            ')">',
                                                            candidate_joborder_status.short_description,
                                                            '</a>'
                                                        )
                                                    FROM
                                                        candidate_joborder
                                                    LEFT JOIN candidate_joborder_status
                                                        ON candidate_joborder_status.candidate_joborder_status_id = candidate_joborder.status
                                                    LEFT JOIN joborder
                                                        ON joborder.joborder_id = candidate_joborder.joborder_id
                                                    LEFT JOIN company
                                                        ON joborder.company_id = company.company_id
                                                    WHERE
                                                        candidate_joborder.candidate_id = candidate.candidate_id
                                                    ORDER BY
                                                        candidate_joborder.date_modified DESC
                                                    LIMIT 1
                                                ) AS lastStatus
                                                ,
(
                                                    SELECT
                                                        CONCAT(
                                                            candidate_joborder_status.short_description,
                                                            '<br />',
                                                            '<a href="index.php?m=companies&amp;a=show&amp;companyID=',
                                                            company.company_id,
                                                            '">',
                                                            company.name,
                                                            '</a> - ',
                                                            '<a href="index.php?m=joborders&amp;a=show&amp;jobOrderID=',
                                                            joborder.joborder_id,
                                                            '">',
                                                            joborder.title,
                                                            '</a>'
                                                        )
                                                    FROM
                                                        candidate_joborder
                                                    LEFT JOIN candidate_joborder_status
                                                        ON candidate_joborder_status.candidate_joborder_status_id = candidate_joborder.status
                                                    LEFT JOIN joborder
                                                        ON joborder.joborder_id = candidate_joborder.joborder_id
                                                    LEFT JOIN company
                                                        ON joborder.company_id = company.company_id
                                                    WHERE
                                                        candidate_joborder.candidate_id = candidate.candidate_id
                                                    ORDER BY
                                                        candidate_joborder.date_modified DESC
                                                    LIMIT 1
                                                ) AS lastStatusLong
                                                ,
candidate.source AS source,
DATE_FORMAT(candidate.date_available, '%m-%d-%y') AS dateAvailable,
candidate.current_employer AS currentEmployer,
candidate.current_pay AS currentPay,
candidate.desired_pay AS desiredPay,
candidate.can_relocate AS canRelocate,
owner_user.first_name AS ownerFirstName,owner_user.last_name AS ownerLastName,CONCAT(owner_user.last_name, owner_user.first_name) AS ownerSort,
DATE_FORMAT(candidate.date_created, '%m-%d-%y') AS dateCreated,
DATE_FORMAT(candidate.date_modified, '%m-%d-%y') AS dateModified,
DATE_FORMAT(saved_list_entry.date_created, '%m-%d-%y') AS dateAddedToList,
                                                     saved_list_entry.date_created AS dateAddedToListSort,
candidate.gpa AS gpa,
university.canonical_name AS universityCanonicalName,
                                                        university.short_name AS universityShortName,
candidate.nationality AS nationality,
(
        SELECT candidate_joborder_status.short_description
        FROM candidate_joborder
        LEFT JOIN candidate_joborder_status
            ON candidate_joborder_status.candidate_joborder_status_id = candidate_joborder.status
        WHERE candidate_joborder.candidate_id = candidate.candidate_id
        ORDER BY candidate_joborder.date_modified DESC
        LIMIT 1
    ) AS statusDescription,
(
                                                    SELECT TRIM(GROUP_CONCAT(' ',t2.title))	FROM candidate_tag t1
                                                    LEFT JOIN tag t2 ON t1.tag_id = t2.tag_id
                                                    WHERE t1.candidate_id = candidate.candidate_id
                                                    GROUP BY candidate_id
                                                    ) as tags
                                                    ,
extra_field0.value AS extra_field_value0,
extra_field1.value AS extra_field_value1,
extra_field2.value AS extra_field_value2,
extra_field3.value AS extra_field_value3,
extra_field4.value AS extra_field_value4
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
LEFT JOIN user AS owner_user ON candidate.owner = owner_user.user_id
LEFT JOIN university ON university.university_id = candidate.university_id
LEFT JOIN extra_field AS extra_field0 ON candidate.candidate_id = extra_field0.data_item_id AND extra_field0.field_name = 'Testinggg' AND extra_field0.data_item_type = 100
LEFT JOIN extra_field AS extra_field1 ON candidate.candidate_id = extra_field1.data_item_id AND extra_field1.field_name = 'Test2' AND extra_field1.data_item_type = 100
LEFT JOIN extra_field AS extra_field2 ON candidate.candidate_id = extra_field2.data_item_id AND extra_field2.field_name = 'Drop' AND extra_field2.data_item_type = 100
LEFT JOIN extra_field AS extra_field3 ON candidate.candidate_id = extra_field3.data_item_id AND extra_field3.field_name = 'Github' AND extra_field3.data_item_type = 100
LEFT JOIN extra_field AS extra_field4 ON candidate.candidate_id = extra_field4.data_item_id AND extra_field4.field_name = 'Tesr' AND extra_field4.data_item_type = 100 LEFT JOIN saved_list_entry
                                    ON saved_list_entry.data_item_type = 100
                                    AND saved_list_entry.data_item_id = candidate.candidate_id
                                    AND saved_list_entry.site_id = 1
            WHERE
                candidate.site_id = 1
            
             AND candidate.candidate_id IN (19,4,18,20,16,17,12,13,15,14,11,10,9,2,8)
            
            GROUP BY candidate.candidate_id
            
            ORDER BY dateModifiedSort DESC
            