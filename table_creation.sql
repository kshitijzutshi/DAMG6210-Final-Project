USE Team6;

-- encryption for card details

CREATE MASTER KEY 
ENCRYPTION BY PASSWORD = 'Team6@dmdd';

CREATE CERTIFICATE TestCertificate 
WITH SUBJECT  = 'to_hide',
EXPIRY_DATE = '2025-08-26';

CREATE SYMMETRIC KEY randomkey
WITH ALGORITHM = AES_128
ENCRYPTION BY CERTIFICATE TestCertificate;

OPEN SYMMETRIC KEY randomkey 
DECRYPTION BY CERTIFICATE TestCertificate;

-- funtions 

CREATE FUNCTION ValidateEmail(@Email VARCHAR)
RETURNS INT 
BEGIN
 
	DECLARE @ISVALID INT
SET @ISVALID =
CASE
	WHEN @Email LIKE '%_@__%.__%' THEN 1
	ELSE 0
END
	RETURN @ISVALID
END;


CREATE FUNCTION CalculateAge(@DOB DATE)
RETURNS INT 
BEGIN
 
	DECLARE @age INT
SET @age = DATEDIFF(HOUR, @DOB, GETDATE()) / 8766
	RETURN @age
END;

CREATE FUNCTION CalculateMembershipEndDate(@STARTDATE DATE, @MEMBERSHIPID INT)
RETURNS DATE 
BEGIN
 
	DECLARE @MemDuration INT
 
	DECLARE @ENDDATE DATE
SELECT
	@MemDuration = Duration
FROM Membership
WHERE MembershipID = @MEMBERSHIPID
SET @ENDDATE = DATEADD(MONTH, @MemDuration, @STARTDATE)
 
	RETURN @ENDDATE
END;

CREATE FUNCTION CalculateMembershipCost(@MEMBERSHIPID INT)
RETURNS DECIMAL 
BEGIN
 
	DECLARE @MemCost DECIMAL
SELECT
	@MemCost = Duration * Price
FROM Membership
WHERE MembershipID = @MEMBERSHIPID
RETURN @MemCost
END;

CREATE FUNCTION getCarType(@CarTierID INT)
RETURNS VARCHAR 
BEGIN
	DECLARE @cartype varchar;
SELECT
	@cartype = TierName
FROM CarTier
WHERE CarTierID = @CarTierID;
RETURN @cartype;
END;

-- TRIGGERS
CREATE TRIGGER dbo.SET_UPDATEDATE ON UserAuth AFTER UPDATE AS BEGIN
UPDATE UserAuth
SET UpdatedAt = CURRENT_TIMESTAMP;
END;


CREATE TRIGGER dbo.ResetCarMaintenance
ON CarMaintenance
AFTER UPDATE
AS
BEGIN
UPDATE CarMaintenance
SET ServiceDate = DATEADD(YEAR, 1, ServiceDate)
   ,DueMiles = 1500
END

CREATE TRIGGER dbo.UpdateClosedTime
ON dbo.CustomerService
AFTER UPDATE
AS
BEGIN
DECLARE @status VARCHAR;
DECLARE @serid INT;
SELECT
	@status = cs1.ComplaintStatus
FROM CustomerService cs1
INNER JOIN inserted i
	ON cs1.ServiceID = i.ServiceID;
SELECT
	@serid = cs1.ServiceID
FROM CustomerService cs1
INNER JOIN inserted i
	ON cs1.ServiceID = i.ServiceID;

IF @status = 'Closed'
BEGIN
UPDATE CustomerService
SET CloseTime = CURRENT_TIMESTAMP
WHERE ServiceID = @serid
END;
END;

ALTER TRIGGER dbo.UpdateMeterRating
ON dbo.Bookings
AFTER UPDATE
AS
BEGIN
DECLARE @status VARCHAR;
DECLARE @bookid INT;
DECLARE @meterend INT;
DECLARE @meterstart INT;
DECLARE @carid INT;
DECLARE @meterrating INT;

SELECT
	@bookid = b.BookingID
FROM Bookings b
INNER JOIN inserted i
	ON b.BookingID = i.BookingID;

SELECT
	@status = Status
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@meterend = MeterEnd
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@meterstart = MeterStart
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@carid = CarId
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@meterrating = MeterRating
FROM Car
WHERE CarID = @carid

IF @status = 'Completed'
BEGIN
UPDATE Car
SET MeterRating = MeterRating + (@meterend - @meterstart)
WHERE CarID = @carid
END

ELSE
IF @status = 'InProgress'
BEGIN
UPDATE Bookings
SET MeterStart = @meterrating
WHERE CarID = @carid
END
END;

-- table creation

CREATE TABLE dbo.Membership (
	MembershipID INT IDENTITY NOT NULL PRIMARY KEY
   ,Duration INT NOT NULL
   ,Price INT NOT NULL
   ,Status BIT NOT NULL
   ,MembershipType VARCHAR(30) NOT NULL CHECK ([MembershipType] IN ('Standard', 'Premium', 'Executive')) DEFAULT 'Standard'
);

CREATE TABLE dbo.Employee (
	EmployeeID INT IDENTITY NOT NULL PRIMARY KEY
   ,FirstName VARCHAR(250) NOT NULL
   ,MiddleName VARCHAR(250)
   ,LastName VARCHAR(250) NOT NULL
   ,Designation VARCHAR(40)
   ,EmailID VARCHAR(40) NOT NULL
);
ALTER TABLE Employee ADD CONSTRAINT checkValidEmail CHECK (dbo.ValidateEmail(EmailID) = 1);


CREATE TABLE UserAuth (
	UserId INT IDENTITY NOT NULL PRIMARY KEY
   ,Username VARCHAR(20) NOT NULL
   ,Password VARBINARY
   ,CreatedAt DATETIME NOT NULL
   ,UpdatedAt DATETIME
);




CREATE TABLE RentalLocation (
	RentalLocationID INT IDENTITY NOT NULL PRIMARY KEY
   ,MaxCapacity INT
   ,CurrentCapacity INT
   ,StreetName VARCHAR(60) NOT NULL
   ,City VARCHAR(40) NOT NULL
   ,State VARCHAR(40) NOT NULL
   ,Zipcode INT NOT NULL
);


CREATE TABLE Vendor (
	VendorID INT IDENTITY NOT NULL PRIMARY KEY
   ,Name VARCHAR(60)
   ,IsVerified BIT
);


CREATE TABLE CarTier (
	CarTierID INT IDENTITY NOT NULL PRIMARY KEY
   ,TierName VARCHAR(40) NOT NULL
   ,PricePerHour DECIMAL(6, 2) NOT NULL
   ,BasicInsurance DECIMAL(7, 2) NOT NULL
   ,PricePerMile DECIMAL(5, 2) NOT NULL
   ,CollisionCoverage DECIMAL(7, 2) NOT NULL
   ,BodyCoverage DECIMAL(7, 2) NOT NULL
   ,MedicalCoverage DECIMAL(7, 2) NOT NULL
   ,
);


CREATE TABLE Customer (
	CustomerID INT IDENTITY NOT NULL PRIMARY KEY
   ,FirstName VARCHAR(250) NOT NULL
   ,MiddleName VARCHAR
   ,LastName VARCHAR(250) NOT NULL
   ,Age AS dbo.CalculateAge(DateOfBirth)
   ,StreetName VARCHAR(60) NOT NULL
   ,City VARCHAR(40) NOT NULL
   ,State VARCHAR(40) NOT NULL
   ,ZipCode INT NOT NULL
   ,EmailID VARCHAR(40) NOT NULL
   ,PhoneNumber VARCHAR NOT NULL
   ,DateOfBirth DATE NOT NULL
   ,LicenseNumber VARCHAR NOT NULL
   ,LicenseExpiry DATE NOT NULL
   ,IsVerified BIT
   ,UserId INT NOT NULL REFERENCES UserAuth (UserId)
);

ALTER TABLE Customer ADD CONSTRAINT checkValidEmailCustomer CHECK (dbo.ValidateEmail(EmailID) = 1);


CREATE TABLE CardDetails (
	CardID INT IDENTITY NOT NULL PRIMARY KEY
   ,NameOnCard VARCHAR(60) NOT NULL
   ,ExpiryDate DATETIME NOT NULL
   ,PaymentMethod VARCHAR NOT NULL CHECK ([PaymentMethod] IN ('Credit', 'Debit'))
   ,CVV INT NOT NULL
   ,CardNumber VARCHAR(20) NOT NULL
   ,IsPrimary BIT
   ,CustomerID INT NOT NULL REFERENCES Customer (CustomerID)
   ,
);
-- unique together on CardNumber and CustomerID 
ALTER TABLE dbo.CardDetails
ADD CONSTRAINT uq_cardNo_CustID UNIQUE (CardNumber, CustomerID);

CREATE TABLE Payment (
	PaymentID INT IDENTITY NOT NULL PRIMARY KEY
   ,CardID INT NOT NULL REFERENCES CardDetails (CardID)
   ,BillingAmount DECIMAL(7, 2) NOT NULL
   ,ProcessedAt DATETIME
   ,PaymentStatus VARCHAR NOT NULL CHECK ([PaymentStatus] IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'))
   ,
);


CREATE TABLE CustomerMembership (
	CustomerMembershipID INT IDENTITY NOT NULL PRIMARY KEY
   ,StartDate DATETIME NOT NULL
   ,EndDate AS dbo.CalculateMembershipEndDate(StartDate, MembershipID)
   ,isactive BIT
   ,MembershipCost AS dbo.CalculateMembershipCost(MembershipID)
   ,CustomerID INT NOT NULL REFERENCES Customer (CustomerID)
   ,MembershipID INT NOT NULL REFERENCES Membership (MembershipID)
);


CREATE TABLE Car (
	CarID INT IDENTITY NOT NULL PRIMARY KEY
   ,Model VARCHAR(60) NOT NULL
   ,Make VARCHAR(60) NOT NULL
   ,Color VARCHAR(20) NOT NULL
   ,CarTierID INT NOT NULL REFERENCES CarTier (CarTierID)
   ,ManufacturingYear INT NOT NULL
   ,SeatCapacity INT
   ,InsuranceStatus VARCHAR NOT NULL CHECK ([InsuranceStatus] IN ('ACTIVE', 'EXPIRED'))
   ,CarType AS dbo.getCarType(CarTierID)
   ,isAvailable BIT
   ,RegistrationNumber VARCHAR NOT NULL
   ,DisableFriendly BIT
   ,RentalLocationID INT NOT NULL REFERENCES RentalLocation (RentalLocationID)
   ,MeterRating INT NOT NULL
   ,VendorID INT NOT NULL REFERENCES Vendor (VendorID)
   ,
);


CREATE TABLE CarMaintenance (
	MaintenanceID INT IDENTITY NOT NULL PRIMARY KEY
   ,ServiceDate DATETIME NOT NULL
   ,DueDate AS DATEADD(YEAR, 1, ServiceDate)
   ,DueMiles INT
   ,CarID INT
   ,
);

CREATE TABLE VendorTransactions (
	VendorTransactionID INT IDENTITY NOT NULL PRIMARY KEY
   ,VendorID INT NOT NULL REFERENCES Vendor (VendorID)
   ,TransactionTime DATETIME
   ,CarID INT NOT NULL REFERENCES Car (CarID)
   ,TransactionValue DECIMAL(10, 2)
);


CREATE TABLE Bookings (
	BookingID INT IDENTITY NOT NULL PRIMARY KEY
   ,CustomerID INT NOT NULL REFERENCES Customer (CustomerID)
   ,Status VARCHAR NOT NULL CHECK ([status] IN ('Cancelled', 'Completed', 'InProgress')) DEFAULT 'Booked'
   ,BookingStartTime DATETIME NOT NULL
   ,BookingEndTime DATETIME NOT NULL
   ,MeterStart INT
   ,MeterEnd INT
   ,RentalAmount DECIMAL(8, 2)
   ,Penalty DECIMAL(8, 2)
   ,PaymentId INT NOT NULL REFERENCES Payment (PaymentId)
   ,CarID INT NOT NULL REFERENCES Car (CarID)
   ,ActualStartTime DATETIME
   ,ActualEndTime DATETIME
   ,BookingRating INTEGER
);

CREATE TABLE CustomerService (
	ServiceID INT IDENTITY NOT NULL PRIMARY KEY
   ,ComplaintStatus VARCHAR CHECK ([ComplaintStatus] IN ('Registered', 'In-Progress', 'Closed'))
   ,Rating INT
   ,IssueTitle VARCHAR NOT NULL
   ,IssueDescription VARCHAR NOT NULL
   ,CreatedTime AS CURRENT_TIMESTAMP
   ,CloseTime DATETIME
   ,BookingId INT NOT NULL REFERENCES Bookings (BookingId)
   ,EmployeeId INT NOT NULL REFERENCES Employee (EmployeeId)
);


-- TODO:

-- USERAUTH
-- use HASHBYTES function to insert data  (https://www.mytecbits.com/microsoft/sql-server/sha-2-hashing)

-- CARDETAILS
-- unique together on CardNumber and CustomerID - completed

--PAYMENT
-- computed column to calculate total amount

--CAR
--make this a computed column from Cartier - completed
--update meterrating -> meterrating + (meterend- meterstart) - completed

-- BOOKINGS
-- trigger when inprogrss, get meterrating - completed
-- rentalamount - computed column
-- reduce miles for carmaintenance entity
-- create function -- actualendtime - bookingendtime or meterend - metertart * pricepermile