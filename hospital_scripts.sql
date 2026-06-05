
BEGIN
   FOR r IN (SELECT table_name FROM user_tables) LOOP
      EXECUTE IMMEDIATE 'DROP TABLE ' || r.table_name || ' CASCADE CONSTRAINTS';
   END LOOP;
END;
/

CREATE TABLE WING (
    Wing_Name VARCHAR2(50) PRIMARY KEY
);

CREATE TABLE EMPLOYEE (
    Staff_Number NUMBER PRIMARY KEY,
    First_Name VARCHAR2(50) NOT NULL,
    Last_Name VARCHAR2(50) NOT NULL,
    Emp_Type VARCHAR2(20) NOT NULL CHECK (Emp_Type IN ('Doctor', 'Nurse'))
);

CREATE TABLE WARD (
    Ward_Number NUMBER,
    Wing_Name VARCHAR2(50),
    Supervisor_Staff_Num NUMBER,
    CONSTRAINT PK_WARD PRIMARY KEY (Ward_Number, Wing_Name),
    CONSTRAINT FK_WARD_WING FOREIGN KEY (Wing_Name) REFERENCES WING(Wing_Name)
);

CREATE TABLE NURSE (
    Staff_Number NUMBER PRIMARY KEY,
    Ward_Number NUMBER NOT NULL,
    Wing_Name VARCHAR2(50) NOT NULL,
    CONSTRAINT FK_NURSE_EMP FOREIGN KEY (Staff_Number) REFERENCES EMPLOYEE(Staff_Number),
    CONSTRAINT FK_NURSE_WARD FOREIGN KEY (Ward_Number, Wing_Name) REFERENCES WARD(Ward_Number, Wing_Name)
);

ALTER TABLE WARD ADD CONSTRAINT FK_WARD_SUPERVISOR FOREIGN KEY (Supervisor_Staff_Num) REFERENCES NURSE(Staff_Number);

CREATE TABLE TEAM (
    Team_Code VARCHAR2(20) PRIMARY KEY,
    Urgent_Phone VARCHAR2(20) NOT NULL,
    Head_Consultant_Num NUMBER
);

CREATE TABLE DOCTOR (
    Staff_Number NUMBER PRIMARY KEY,
    Doc_Type VARCHAR2(20) NOT NULL CHECK (Doc_Type IN ('Consultant', 'Junior')),
    Team_Code VARCHAR2(20),
    CONSTRAINT FK_DOCTOR_EMP FOREIGN KEY (Staff_Number) REFERENCES EMPLOYEE(Staff_Number),
    CONSTRAINT FK_DOCTOR_TEAM FOREIGN KEY (Team_Code) REFERENCES TEAM(Team_Code)
);

CREATE TABLE MEDICAL_CONSULTANT (
    Staff_Number NUMBER PRIMARY KEY,
    Specialty VARCHAR2(50) NOT NULL,
    CONSTRAINT FK_CONSULTANT_DOC FOREIGN KEY (Staff_Number) REFERENCES DOCTOR(Staff_Number)
);


ALTER TABLE TEAM ADD CONSTRAINT FK_TEAM_HEAD FOREIGN KEY (Head_Consultant_Num) REFERENCES MEDICAL_CONSULTANT(Staff_Number);

CREATE TABLE JUNIOR_DOCTOR (
    Staff_Number NUMBER PRIMARY KEY,
    Designation VARCHAR2(30) NOT NULL,
    CONSTRAINT FK_JUNIOR_DOC FOREIGN KEY (Staff_Number) REFERENCES DOCTOR(Staff_Number)
);

CREATE TABLE PATIENT (
    Patient_ID NUMBER PRIMARY KEY,
    Patient_Name VARCHAR2(100) NOT NULL,
    Responsible_Consultant_Num NUMBER NOT NULL,
    CONSTRAINT FK_PATIENT_CONSULTANT FOREIGN KEY (Responsible_Consultant_Num) REFERENCES MEDICAL_CONSULTANT(Staff_Number)
);

CREATE TABLE TREATMENT (
    Patient_ID NUMBER,
    Doctor_Staff_Num NUMBER,
    Start_Date DATE,
    Reason VARCHAR2(200) NOT NULL,
    CONSTRAINT PK_TREATMENT PRIMARY KEY (Patient_ID, Doctor_Staff_Num, Start_Date),
    CONSTRAINT FK_TREATMENT_PATIENT FOREIGN KEY (Patient_ID) REFERENCES PATIENT(Patient_ID),
    CONSTRAINT FK_TREATMENT_DOCTOR FOREIGN KEY (Doctor_Staff_Num) REFERENCES DOCTOR(Staff_Number)
);

CREATE TABLE PRESCRIPTION (
    Prescription_Number NUMBER PRIMARY KEY,
    Patient_ID NUMBER NOT NULL,
    Doctor_Staff_Num NUMBER NOT NULL,
    CONSTRAINT FK_PRESCRIPTION_PATIENT FOREIGN KEY (Patient_ID) REFERENCES PATIENT(Patient_ID),
    CONSTRAINT FK_PRESCRIPTION_DOCTOR KEY (Doctor_Staff_Num) REFERENCES DOCTOR(Staff_Number)
);

CREATE TABLE MEDICAL_PROVIDER (
    Provider_ID NUMBER PRIMARY KEY,
    Provider_Name VARCHAR2(100) NOT NULL,
    Contact_Info VARCHAR2(200)
);

CREATE TABLE DRUG (
    Drug_Code VARCHAR2(20) PRIMARY KEY,
    Drug_Name VARCHAR2(100) NOT NULL,
    Drug_Substance VARCHAR2(100) NOT NULL,
    Recommended_Daily_Dose VARCHAR2(100),
    Quantity_In_Hand NUMBER NOT NULL CHECK (Quantity_In_Hand >= 0),
    Low_Level_Quantity NUMBER NOT NULL CHECK (Low_Level_Quantity >= 0),
    Quantity_To_Order NUMBER NOT NULL CHECK (Quantity_To_Order > 0),
    Provider_ID NUMBER NOT NULL,
    CONSTRAINT FK_DRUG_PROVIDER FOREIGN KEY (Provider_ID) REFERENCES MEDICAL_PROVIDER(Provider_ID)
);

CREATE TABLE PRESCRIPTION_LINE (
    Prescription_Number NUMBER,
    Drug_Code VARCHAR2(20),
    Quantity NUMBER NOT NULL CHECK (Quantity > 0),
    Daily_Dosage VARCHAR2(50),
    CONSTRAINT PK_PRESCRIPTION_LINE PRIMARY KEY (Prescription_Number, Drug_Code),
    CONSTRAINT FK_LINE_PRESCRIPTION FOREIGN KEY (Prescription_Number) REFERENCES PRESCRIPTION(Prescription_Number),
    CONSTRAINT FK_LINE_DRUG FOREIGN KEY (Drug_Code) REFERENCES DRUG(Drug_Code)
);

CREATE TABLE DRUG_ALERT_LOG (
    Log_ID NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Drug_Code VARCHAR2(20),
    Alert_Date TIMESTAMP,
    Current_Stock NUMBER,
    Low_Level_Limit NUMBER,
    Order_Quantity_Suggested NUMBER,
    Status VARCHAR2(20)
);





CREATE OR REPLACE TRIGGER TRG_CHECK_DRUG_STOCK
AFTER UPDATE OF Quantity_In_Hand ON DRUG
FOR EACH ROW
BEGIN
    IF :NEW.Quantity_In_Hand <= :OLD.Low_Level_Quantity THEN
        
        INSERT INTO DRUG_ALERT_LOG (
            Drug_Code, 
            Alert_Date, 
            Current_Stock, 
            Low_Level_Limit, 
            Order_Quantity_Suggested, 
            Status
        ) VALUES (
            :NEW.Drug_Code,
            SYSTIMESTAMP,
            :NEW.Quantity_In_Hand,
            :NEW.Low_Level_Quantity,
            :NEW.Quantity_To_Order,
            'Logged'
        );
        
    END IF;
END;
/







INSERT INTO WING (Wing_Name)
SELECT DISTINCT old_clinic_name FROM OLD_CLINIC WHERE old_clinic_name IS NOT NULL;

INSERT INTO WARD (Ward_Number, Wing_Name, Supervisor_Staff_Num)
SELECT old_ward_no, old_clinic_name, NULL FROM OLD_CLINIC;

INSERT INTO EMPLOYEE (Staff_Number, First_Name, Last_Name, Emp_Type)
SELECT 
    old_staff_id, 
    old_first_name, 
    old_last_name,
    CASE WHEN old_role IN ('Consultant', 'Junior', 'Doctor') THEN 'Doctor' ELSE 'Nurse' END
FROM OLD_STAFF;

INSERT INTO NURSE (Staff_Number, Ward_Number, Wing_Name)
SELECT old_staff_id, old_ward_no, old_clinic_name 
FROM OLD_STAFF 
WHERE old_role = 'Nurse';

UPDATE WARD w
SET w.Supervisor_Staff_Num = (
    SELECT old_staff_id 
    FROM OLD_STAFF os 
    WHERE os.old_ward_no = w.Ward_Number 
      AND os.old_clinic_name = w.Wing_Name 
      AND os.old_is_supervisor = 'Y' 
      AND ROWNUM = 1
)
WHERE EXISTS (
    SELECT 1 FROM OLD_STAFF os 
    WHERE os.old_ward_no = w.Ward_Number 
      AND os.old_clinic_name = w.Wing_Name 
      AND os.old_is_supervisor = 'Y'
);





INSERT INTO DOCTOR (Staff_Number, Doc_Type, Team_Code)
SELECT 
    old_staff_id, 
    CASE WHEN old_role = 'Consultant' THEN 'Consultant' ELSE 'Junior' END,
    NULL 
FROM OLD_STAFF 
WHERE old_role IN ('Consultant', 'Junior');



INSERT INTO MEDICAL_CONSULTANT (Staff_Number, Specialty)
SELECT old_staff_id, old_specialty 
FROM OLD_STAFF 
WHERE old_role = 'Consultant';



INSERT INTO TEAM (Team_Code, Urgent_Phone, Head_Consultant_Num)
SELECT 'TEAM_' || old_staff_id, old_phone, old_staff_id 
FROM OLD_STAFF 
WHERE old_role = 'Consultant';


UPDATE DOCTOR d
SET d.Team_Code = (
    SELECT 'TEAM_' || old_team_leader_id 
    FROM OLD_STAFF os 
    WHERE os.old_staff_id = d.Staff_Number
);



INSERT INTO JUNIOR_DOCTOR (Staff_Number, Designation)
SELECT old_staff_id, old_rank 
FROM OLD_STAFF 
WHERE old_role = 'Junior';

INSERT INTO PATIENT (Patient_ID, Patient_Name, Responsible_Consultant_Num)
SELECT old_pat_id, old_pat_name, old_assigned_consultant_id 
FROM OLD_PATIENT;

INSERT INTO TREATMENT (Patient_ID, Doctor_Staff_Num, Start_Date, Reason)
SELECT old_pat_id, old_doc_id, old_start_date, old_diagnosis 
FROM OLD_TREATMENT;

INSERT INTO MEDICAL_PROVIDER (Provider_ID, Provider_Name, Contact_Info)
SELECT DISTINCT old_prov_id, old_prov_name, old_prov_contact 
FROM OLD_DRUG;

INSERT INTO DRUG (Drug_Code, Drug_Name, Drug_Substance, Recommended_Daily_Dose, Quantity_In_Hand, Low_Level_Quantity, Quantity_To_Order, Provider_ID)
SELECT old_drug_code, old_drug_name, old_substance, old_dose, old_stock, old_min_limit, old_order_qty, old_prov_id 
FROM OLD_DRUG;

INSERT INTO PRESCRIPTION (Prescription_Number, Patient_ID, Doctor_Staff_Num)
SELECT DISTINCT old_presc_no, old_pat_id, old_doc_id 
FROM OLD_PRESCRIPTION;

INSERT INTO PRESCRIPTION_LINE (Prescription_Number, Drug_Code, Quantity, Daily_Dosage)
SELECT old_presc_no, old_drug_code, old_qty_ordered, old_dosage_schedule 
FROM OLD_PRESCRIPTION;

COMMIT;








CREATE ROLE c##role_doctor;
CREATE ROLE c##role_nurse;

GRANT SELECT, INSERT, UPDATE ON PATIENT TO c##role_doctor;
GRANT SELECT, INSERT, UPDATE ON TREATMENT TO c##role_doctor;
GRANT SELECT, INSERT, UPDATE, DELETE ON PRESCRIPTION TO c##role_doctor;
GRANT SELECT, INSERT, UPDATE, DELETE ON PRESCRIPTION_LINE TO c##role_doctor;
GRANT SELECT ON DRUG TO c##role_doctor;
GRANT SELECT ON TEAM TO c##role_doctor;

GRANT SELECT ON WING TO c##role_nurse;
GRANT SELECT ON WARD TO c##role_nurse;
GRANT SELECT ON EMPLOYEE TO c##role_nurse;
GRANT SELECT ON NURSE TO c##role_nurse;
GRANT SELECT ON PATIENT TO c##role_nurse;
GRANT SELECT ON DRUG TO c##role_nurse;
GRANT SELECT ON PRESCRIPTION TO c##role_nurse;
GRANT SELECT ON PRESCRIPTION_LINE TO c##role_nurse;

CREATE USER c##doctor_user IDENTIFIED BY "Password123!";
CREATE USER c##nurse_user IDENTIFIED BY "Password123!";

GRANT CREATE SESSION TO c##doctor_user;
GRANT CREATE SESSION TO c##nurse_user;

GRANT c##role_doctor TO c##doctor_user;
GRANT c##role_nurse TO c##nurse_user;




CREATE OR REPLACE VIEW VIEW_PATIENT_DETAILS AS
SELECT 
    p.Patient_ID,
    p.Patient_Name,
    e.First_Name AS Doctor_First_Name,
    e.Last_Name AS Doctor_Last_Name,
    mc.Specialty
FROM PATIENT p
JOIN MEDICAL_CONSULTANT mc ON p.Responsible_Consultant_Num = mc.Staff_Number
JOIN EMPLOYEE e ON mc.Staff_Number = e.Staff_Number;






CREATE OR REPLACE VIEW VIEW_LOW_STOCK_DRUGS AS
SELECT 
    d.Drug_Code,
    d.Drug_Name,
    d.Quantity_In_Hand,
    d.Low_Level_Quantity,
    d.Quantity_To_Order,
    mp.Provider_Name,
    mp.Contact_Info AS Provider_Contact
FROM DRUG d
JOIN MEDICAL_PROVIDER mp ON d.Provider_ID = mp.Provider_ID
WHERE d.Quantity_In_Hand <= d.Low_Level_Quantity;

CREATE OR REPLACE VIEW VIEW_WARD_MANAGEMENT AS
SELECT 
    w.Ward_Number,
    w.Wing_Name,
    e.First_Name AS Supervisor_First_Name,
    e.Last_Name AS Supervisor_Last_Name
FROM WARD w
LEFT JOIN NURSE n ON w.Supervisor_Staff_Num = n.Staff_Number
LEFT JOIN EMPLOYEE e ON n.Staff_Number = e.Staff_Number;


CREATE OR REPLACE FUNCTION FUNC_GET_PATIENT_COUNT (
    p_Wing_Name IN VARCHAR2
) RETURN NUMBER 
IS
    v_Count NUMBER := 0;
BEGIN
    SELECT COUNT(DISTINCT p.Patient_ID)
    INTO v_Count
    FROM PATIENT p
    WHERE EXISTS (
        SELECT 1 FROM WARD w 
        WHERE w.Wing_Name = p_Wing_Name
    );
    RETURN v_Count;
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0;
END;
/




CREATE OR REPLACE PROCEDURE PROC_DISCHARGE_PATIENT (
    p_Patient_ID IN NUMBER
) 
IS
BEGIN
    DELETE FROM PRESCRIPTION_LINE 
    WHERE Prescription_Number IN (
        SELECT Prescription_Number FROM PRESCRIPTION WHERE Patient_ID = p_Patient_ID
    );

    DELETE FROM PRESCRIPTION WHERE Patient_ID = p_Patient_ID;
    DELETE FROM TREATMENT WHERE Patient_ID = p_Patient_ID;
    DELETE FROM PATIENT WHERE Patient_ID = p_Patient_ID;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Ο ασθενής με ID ' || p_Patient_ID || ' πήρε εξιτήριο επιτυχώς.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Σφάλμα κατά την έκδοση εξιτηρίου: ' || SQLERRM);
END;
/