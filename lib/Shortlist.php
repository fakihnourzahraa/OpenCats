<?php

//rID = recruiterID
//cID = candidateID

class Shortlist
{
    private $_db;

    public function __construct()
    {
        $this->_db = DatabaseConnection::getInstance();
    }

    public function add($rID, $cID)
    {
        $query = "INSERT INTO shortlist (recruiter_id, candidate_id) 
                  VALUES ({$this->_db->makeQueryInteger($rID)}, {$this->_db->makeQueryInteger($cID)})";
        return ($this->_db->query($query));
    }

    public function remove($rID, $cID)
    {
        $query = "DELETE FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}
                  AND candidate_id = {$this->_db->makeQueryInteger($cID)}";
        return ($this->_db->query($query));
    }

    public function isShortlisted($rID, $cID)
    {
        $query = "SELECT COUNT(*) as count FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}
                  AND candidate_id = {$this->_db->makeQueryInteger($cID)}";
        $result = $this->_db->query($query);
        
        if (!$result)
            return false;
        $row = $this->_db->getAssoc();
        return (isset($row['count']) && $row['count'] > 0);
    }

    //get shortlisted
    public function getSL($rID)
    {
        $query = "SELECT candidate_id FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}";
        $result = $this->_db->query($query);
        
        if (!$result)
            return (array());
        
        $candidates = [];
        while (($row = $this->_db->getAssoc()))
        {
            $candidates[] = $row['candidate_id'];
        }
        return ($candidates);
    }
    
    public function getCount($rID)
    {
        $query = "SELECT COUNT(*) as count FROM shortlist
                  WHERE recruiter_id = {$this->_db->makeQueryInteger($rID)}";
        $result = $this->_db->query($query);
        
        if (!$result)
            return (0);
        
        $row = $this->_db->getAssoc();
        return (isset($row['count']) ? intval($row['count']) : 0);
    }
}
?>