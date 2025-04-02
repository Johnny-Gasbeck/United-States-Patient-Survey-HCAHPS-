#Data Cleaning

# Creating table
CREATE TABLE hcahps_survey_altered (
    Facility_ID VARCHAR(20),
    Facility_Name VARCHAR(255),
    Address VARCHAR(255),
    City_Town VARCHAR(100),
    State VARCHAR(10),
    ZIP_Code VARCHAR(10),
    County_Parish VARCHAR(100),
    Telephone_Number VARCHAR(20),
    HCAHPS_Measure_ID VARCHAR(50),
    HCAHPS_Question TEXT,
    HCAHPS_Answer_Description TEXT,
    Patient_Survey_Star_Rating VARCHAR(10),
    Patient_Survey_Star_Rating_Footnote VARCHAR(10),
    HCAHPS_Answer_Percent VARCHAR(10),
    HCAHPS_Answer_Percent_Footnote VARCHAR(10),
    HCAHPS_Linear_Mean_Value VARCHAR(10),
    Number_of_Completed_Surveys VARCHAR(10),
    Number_of_Completed_Surveys_Footnote VARCHAR(10),
    Survey_Response_Rate_Percent VARCHAR(10),
    Survey_Response_Rate_Percent_Footnote VARCHAR(10),
    Start_Date TEXT,
    End_Date TEXT
);

#Loading data into table
LOAD DATA LOCAL INFILE '/Users/johnnyg/Library/Mobile Documents/com~apple~CloudDocs/Projects/Hospital Rating Project/HCAHPS-Hospital-Altered.csv'
INTO TABLE hcahps_survey_altered
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

#Checking to see if data was imported correctly 
SELECT *
FROM hcahps_survey_altered;

# Creating another table from the table that was imported
CREATE TABLE hospital_survey AS 
SELECT * FROM hcahps_survey_altered;

SELECT *
FROM hospital_survey;

#Identify and Fix Formatting Issues

#Filter out and retrive Zip_Code values that are not 5 digits long or do not match standard format for a U.S. zip code
SELECT ZIP_Code 
FROM hospital_survey 
WHERE CAST(ZIP_Code AS CHAR) NOT REGEXP '^[0-9]{5}$';
#0 rows returned

#Convert Start_Date and End_Date to proper DATE format:
UPDATE hospital_survey 
SET Start_Date = STR_TO_DATE(Start_Date, '%m/%d/%Y'),
    End_Date = STR_TO_DATE(End_Date, '%m/%d/%Y');

#Convert empty strings to Null for quantitative columns 
UPDATE hospital_survey 
SET Patient_Survey_Star_Rating = NULLIF(Patient_Survey_Star_Rating, ''),
    HCAHPS_Answer_Percent = NULLIF(HCAHPS_Answer_Percent, ''),
    HCAHPS_Linear_Mean_Value = NULLIF(HCAHPS_Linear_Mean_Value, ''),
    Number_of_Completed_Surveys = NULLIF(Number_of_Completed_Surveys, ''),
    Survey_Response_Rate_Percent = NULLIF(Survey_Response_Rate_Percent, '');

#Convert Numeric Fields to Correct Data Types to ensure that numbers are stored correctly and can be used for calculations
ALTER TABLE hospital_survey 
MODIFY COLUMN Patient_Survey_Star_Rating FLOAT NULL,
MODIFY COLUMN HCAHPS_Answer_Percent FLOAT NULL,
MODIFY COLUMN HCAHPS_Linear_Mean_Value FLOAT NULL,
MODIFY COLUMN Number_of_Completed_Surveys INT NULL,
MODIFY COLUMN Survey_Response_Rate_Percent FLOAT NULL;

#Confirm no non-numeric values are in these columns 
SELECT * FROM hospital_survey 
WHERE Patient_Survey_Star_Rating REGEXP '[^0-9.]'
   OR HCAHPS_Answer_Percent REGEXP '[^0-9.]'
   OR HCAHPS_Linear_Mean_Value REGEXP '[^0-9.]'
   OR Number_of_Completed_Surveys REGEXP '[^0-9]'
   OR Survey_Response_Rate_Percent REGEXP '[^0-9.]';


#To identify rows with blank or NULL values for Patient_Survey_Star_Rating, HCAHPS_Answer_Percent, and HCAHPS_Linear_Mean_Value
SELECT *
FROM hospital_survey
WHERE 
    COALESCE(NULLIF(TRIM(Patient_Survey_Star_Rating), ''), 'NULL') = 'NULL' AND
    COALESCE(NULLIF(TRIM(HCAHPS_Answer_Percent), ''), 'NULL') = 'NULL' AND
    COALESCE(NULLIF(TRIM(HCAHPS_Linear_Mean_Value), ''), 'NULL') = 'NULL';
#This returned 102123 rows

#To identify the footnote for why there are blank or NULL values for Patient_Survey_Star_Rating, HCAHPS_Answer_Percent, and HCAHPS_Linear_Mean_Value
SELECT DISTINCT(HCAHPS_Answer_Percent_Footnote)
FROM hospital_survey
WHERE 
    COALESCE(NULLIF(TRIM(Patient_Survey_Star_Rating), ''), 'NULL') = 'NULL' AND
    COALESCE(NULLIF(TRIM(HCAHPS_Answer_Percent), ''), 'NULL') = 'NULL' AND
    COALESCE(NULLIF(TRIM(HCAHPS_Linear_Mean_Value), ''), 'NULL') = 'NULL';
#Distinct footnotes of 1,5,19,(5,24)

#To delete rows with blank or NULL values for Patient_Survey_Star_Rating, HCAHPS_Answer_Percent, and HCAHPS_Linear_Mean_Value 
#because these rows have no quantitative values that can be used for analysis
DELETE FROM hospital_survey
WHERE 
    COALESCE(NULLIF(TRIM(Patient_Survey_Star_Rating), ''), 'NULL') = 'NULL' AND
    COALESCE(NULLIF(TRIM(HCAHPS_Answer_Percent), ''), 'NULL') = 'NULL' AND
    COALESCE(NULLIF(TRIM(HCAHPS_Linear_Mean_Value), ''), 'NULL') = 'NULL';
#Deleted 102123 rows

#Check for Duplicates
SELECT Facility_ID, HCAHPS_Measure_ID, Start_Date, End_Date, COUNT(*) 
FROM hospital_survey
GROUP BY Facility_ID, HCAHPS_Measure_ID, Start_Date, End_Date
HAVING COUNT(*) > 1;
# No duplicates 

SELECT *
FROM hospital_survey;

# Augmenting and Improving the Data Set 

#Create a census_data table
CREATE TABLE census_data (
    State VARCHAR(150),
    County VARCHAR(150),
    Population INT
);

#Import data file into MySQL
LOAD DATA LOCAL INFILE '/Users/johnnyg/Library/Mobile Documents/com~apple~CloudDocs/Projects/Hospital Rating Project/2024 County Populations.csv'
INTO TABLE census_data
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

#Checking the Data
SELECT *
FROM census_data;

#Create a new table 
CREATE TABLE county_population (
    State VARCHAR(250),
    County VARCHAR(250),
    Population INT,
    PRIMARY KEY (STATE,COUNTY)
);

SELECT *
FROM county_population;

#Insert Census Data into new table
INSERT INTO county_population (State, County, Population)
SELECT 
    TRIM(BOTH '''' FROM SUBSTRING_INDEX(State, ',', -1)),  -- Extract state
    TRIM(BOTH '''' FROM SUBSTRING_INDEX(State, ',', 1)),  -- Extract county_name
    NULLIF(TRIM(BOTH '''' FROM Population), '')  -- Replace empty population with NULL
FROM census_data;

#Remove the words "County" or "Parish" from the County column
UPDATE county_population
SET County = REPLACE(REPLACE(County, ' County', ''), ' Parish', '');

#Want County column to be in all uppercase to match the hospital_survey table
UPDATE county_population
SET County = UPPER(County);

SELECT *
FROM county_population;

#Convert State names into their two-letter abbreviations to match hospital_survey table
UPDATE county_population
SET State = CASE 
    WHEN TRIM(LOWER(State)) = 'alabama' THEN 'AL'
    WHEN TRIM(LOWER(State)) = 'alaska' THEN 'AK'
    WHEN TRIM(LOWER(State)) = 'arizona' THEN 'AZ'
    WHEN TRIM(LOWER(State)) = 'arkansas' THEN 'AR'
    WHEN TRIM(LOWER(State)) = 'california' THEN 'CA'
    WHEN TRIM(LOWER(State)) = 'colorado' THEN 'CO'
    WHEN TRIM(LOWER(State)) = 'connecticut' THEN 'CT'
    WHEN TRIM(LOWER(State)) = 'delaware' THEN 'DE'
    WHEN TRIM(LOWER(State)) = 'florida' THEN 'FL'
    WHEN TRIM(LOWER(State)) = 'georgia' THEN 'GA'
    WHEN TRIM(LOWER(State)) = 'hawaii' THEN 'HI'
    WHEN TRIM(LOWER(State)) = 'idaho' THEN 'ID'
    WHEN TRIM(LOWER(State)) = 'illinois' THEN 'IL'
    WHEN TRIM(LOWER(State)) = 'indiana' THEN 'IN'
    WHEN TRIM(LOWER(State)) = 'iowa' THEN 'IA'
    WHEN TRIM(LOWER(State)) = 'kansas' THEN 'KS'
    WHEN TRIM(LOWER(State)) = 'kentucky' THEN 'KY'
    WHEN TRIM(LOWER(State)) = 'louisiana' THEN 'LA'
    WHEN TRIM(LOWER(State)) = 'maine' THEN 'ME'
    WHEN TRIM(LOWER(State)) = 'maryland' THEN 'MD'
    WHEN TRIM(LOWER(State)) = 'massachusetts' THEN 'MA'
    WHEN TRIM(LOWER(State)) = 'michigan' THEN 'MI'
    WHEN TRIM(LOWER(State)) = 'minnesota' THEN 'MN'
    WHEN TRIM(LOWER(State)) = 'mississippi' THEN 'MS'
    WHEN TRIM(LOWER(State)) = 'missouri' THEN 'MO'
    WHEN TRIM(LOWER(State)) = 'montana' THEN 'MT'
    WHEN TRIM(LOWER(State)) = 'nebraska' THEN 'NE'
    WHEN TRIM(LOWER(State)) = 'nevada' THEN 'NV'
    WHEN TRIM(LOWER(State)) = 'new hampshire' THEN 'NH'
    WHEN TRIM(LOWER(State)) = 'new jersey' THEN 'NJ'
    WHEN TRIM(LOWER(State)) = 'new mexico' THEN 'NM'
    WHEN TRIM(LOWER(State)) = 'new york' THEN 'NY'
    WHEN TRIM(LOWER(State)) = 'north carolina' THEN 'NC'
    WHEN TRIM(LOWER(State)) = 'north dakota' THEN 'ND'
    WHEN TRIM(LOWER(State)) = 'ohio' THEN 'OH'
    WHEN TRIM(LOWER(State)) = 'oklahoma' THEN 'OK'
    WHEN TRIM(LOWER(State)) = 'oregon' THEN 'OR'
    WHEN TRIM(LOWER(State)) = 'pennsylvania' THEN 'PA'
    WHEN TRIM(LOWER(State)) = 'rhode island' THEN 'RI'
    WHEN TRIM(LOWER(State)) = 'south carolina' THEN 'SC'
    WHEN TRIM(LOWER(State)) = 'south dakota' THEN 'SD'
    WHEN TRIM(LOWER(State)) = 'tennessee' THEN 'TN'
    WHEN TRIM(LOWER(State)) = 'texas' THEN 'TX'
    WHEN TRIM(LOWER(State)) = 'utah' THEN 'UT'
    WHEN TRIM(LOWER(State)) = 'vermont' THEN 'VT'
    WHEN TRIM(LOWER(State)) = 'virginia' THEN 'VA'
    WHEN TRIM(LOWER(State)) = 'washington' THEN 'WA'
    WHEN TRIM(LOWER(State)) = 'west virginia' THEN 'WV'
    WHEN TRIM(LOWER(State)) = 'wisconsin' THEN 'WI'
    WHEN TRIM(LOWER(State)) = 'wyoming' THEN 'WY'
    ELSE TRIM(State) -- Keep the value unchanged if it doesn't match a known state
END;

#Rename Population to County_Population for clarification before joining tables
ALTER TABLE county_population
RENAME COLUMN Population TO County_Population;

SELECT *
FROM county_population;

SELECT *
FROM hospital_survey;

#Identify Columns
DESC county_population;
DESC hospital_survey;

#Left Join hospital_survey with county_population 
SELECT 
	hs.*, 
    cp.County_Population
FROM hospital_survey hs
LEFT JOIN county_population cp 
ON hs.County_Parish = cp.County AND hs.State = cp.State;

#Create table with LEFT JOIN of hospital_survey and county_population 
CREATE TABLE hs_population AS
SELECT 
	hs.*, 
    cp.County_Population
FROM hospital_survey hs
LEFT JOIN county_population cp 
ON hs.County_Parish = cp.County AND hs.State = cp.State;



#Checking table for accuracy
SELECT *
FROM hs_population;
