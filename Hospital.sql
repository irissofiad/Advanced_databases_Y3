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