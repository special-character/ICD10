CREATE TABLE Patient (
	pID INTEGER PRIMARY KEY NOT NULL,
	email TEXT NOT NULL, 
	date_of_birth TEXT NOT NULL,
	f_name TEXT NOT NULL,
	l_name TEXT NOT NULL
	);
	
CREATE TABLE Place_of_service (
	placeID INTEGER PRIMARY KEY NOT NULL,
	place_description TEXT
	);
	
CREATE TABLE Appointment (
	aptID INTEGER PRIMARY KEY NOT NULL,
	date TEXT,
	placeID TEXT NOT NULL,
	FOREIGN KEY (placeID) REFERENCES Place_of_service (placeID) ON DELETE CASCADE ON UPDATE CASCADE
	);

CREATE TABLE Attends (
	pID INTEGER,
	aptID INTEGER,
	PRIMARY KEY (pID, aptID),
	FOREIGN KEY (pID) REFERENCES Patient(pID) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (aptID) REFERENCES Appointment(aptID) ON DELETE CASCADE ON UPDATE CASCADE
	);

CREATE TABLE Practice (
	mpID INTEGER PRIMARY KEY NOT NULL,
	name TEXT NOT NULL
	);
	
CREATE TABLE Doctor (
	dID INTEGER PRIMARY KEY NOT NULL,
	email TEXT NOT NULL,
	f_name TEXT NOT NULL,
	l_name TEXT NOT NULL,
	mpID INTEGER NOT NULL,
	FOREIGN KEY (mpID) REFERENCES Practice (mpID) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE Performs (
	dID INTEGER NOT NULL,
	aptID INTEGER NOT NULL,
	PRIMARY KEY (dID, aptID),
	FOREIGN KEY (dID) REFERENCES Doctor (dID) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (aptID) REFERENCES Appointment (aptID) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE Referred_by (
	pID INTEGER NOT NULL,
	dID INTEGER NOT NULL, 
	PRIMARY KEY (pID,dID),
	FOREIGN KEY (pID) REFERENCES Patient (pID) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (dID) REFERENCES Doctor (dID) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE Apt_type (
	apt_code INTEGER PRIMARY KEY NOT NULL,
	type_description TEXT,
	code_description TEXT
	);
	
CREATE TABLE Has_type (
	aptID INTEGER NOT NULL,
	apt_code INTEGER NOT NULL,
	PRIMARY KEY (aptID, apt_code),
	FOREIGN KEY (aptID) REFERENCES Appointment (atpID) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (apt_code) REFERENCES Apt_type (apt_code) ON DELETE CASCADE ON UPDATE CASCADE
	);
/*	
CREATE TABLE ICD9_condition (
	ICD9_code TEXT PRIMARY KEY NOT NULL,
	condition_name TEXT NOT NULL,
	favorite INTEGER
	);
*/

CREATE TABLE ICD10_condition (
	ICD10_code TEXT PRIMARY KEY NOT NULL,
	description_text TEXT,
	ICD9_code TEXT NOT NULL,
	condition_name TEXT NOT NULL,
	favorite INTEGER
	--FOREIGN KEY (ICD9_code) REFERENCES ICD9_condition (ICD9_code) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE Diagnosed_with (
	aptID INTEGER NOT NULL,
	ICD10_code INTEGER NOT NULL,
	PRIMARY KEY (aptID, ICD10_code),
	FOREIGN KEY (aptID) REFERENCES Appointment (aptID) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (ICD10_code) REFERENCES ICD10_condition (ICD10_code) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE Condition_location (
	LID INTEGER PRIMARY KEY NOT NULL,
	location_name TEXT
	);
	
CREATE TABLE Sub_location (
	LID INTEGER NOT NULL,
	parent_locationID INTEGER NOT NULL,
	PRIMARY KEY (LID, parent_locationID),
	FOREIGN KEY (LID) REFERENCES Condition_location (LID) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (parent_locationID) REFERENCES Condition_location(LID) ON DELETE CASCADE ON UPDATE CASCADE
	);
/*	
CREATE TABLE Affects (
	ICD9_code TEXT NOT NULL,
	LID INTEGER NOT NULL,
	PRIMARY KEY (ICD9_code, LID),
	FOREIGN KEY (ICD9_code) REFERENCES Condition (ICD9_code) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (LID) REFERENCES Condition_location (LID) ON DELETE CASCADE ON UPDATE CASCADE
	);	
*/	
CREATE TABLE Located_in (
	ICD10_code TEXT NOT NULL,
	LID INTEGER NOT NULL,
	PRIMARY KEY (ICD10_code, LID),
	FOREIGN KEY (ICD10_code) REFERENCES ICD10_condition (ICD10_code) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (LID) REFERENCES Condition_location (LID) ON DELETE CASCADE ON UPDATE CASCADE
	);
	/*
CREATE TABLE Symptom (
	sID INTEGER PRIMARY KEY NOT NULL,
	symptom_text TEXT
	);
	
CREATE TABLE Describes (
	ICD10_code TEXT NOT NULL,
	sID INTEGER NOT NULL,
	PRIMARY KEY (ICD10_code, sID),
	FOREIGN KEY (ICD10_code) REFERENCES ICD10_condition (ICD10_code) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (sID) REFERENCES Symptom (sID) ON DELETE CASCADE ON UPDATE CASCADE
	);
	*/