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


create FUNCTION dbo.checkPrimaryCard(@CustomerID INT)
returns INT
AS
BEGIN
	DECLARE @flag INT = 0;

	if EXISTS (SELECT
		*
	FROM CardDetails
	WHERE CustomerID = @CustomerID
	AND IsPrimary = 1)
BEGIN
SET @flag = 1
	end
	return @flag
END


CREATE FUNCTION dbo.checkavailability(@CarID int)
returns BIT
AS
BEGIN
	declare @bookid INT;
	DECLARE @starttime DATETIME;
	DECLARE @endtime DATETIME;
	DECLARE @isavailable BIT;
	DECLARE @status VARCHAR;

SELECT
	@bookid = BookingID
FROM Bookings
WHERE CarID = @carid

SELECT
	@starttime = BookingStartTime
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@endtime = BookingEndTime
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@status = Status
FROM Bookings
WHERE BookingID = @bookid

IF CURRENT_TIMESTAMP BETWEEN @starttime AND @endtime
BEGIN
SET @isavailable = 0
	end

	ELSE
	if @status in ('InProgress', 'Booked')
	begin
SET @isavailable = 0
	end

	RETURN @isavailable
END

CREATE FUNCTION dbo.calculateBillingAmount(@PaymentID INT)
returns DECIMAL
AS
BEGIN
	DECLARE @sum DECIMAL = 0;
	DECLARE @bookid INT;

SELECT
	@bookid = BookingID
FROM Bookings
WHERE @PaymentID = @PaymentID

SELECT
	@sum = RentalAmount + Penalty
FROM Bookings
WHERE BookingID = @bookid

RETURN @sum
END

-- TRIGGERS
CREATE TRIGGER dbo.SET_UPDATEDATE ON UserAuth AFTER UPDATE AS BEGIN
UPDATE UserAuth
SET UpdatedAt = CURRENT_TIMESTAMP;
END;


-- change it to insert as maintenanceid is auto inc primary key (should be composite key)
CREATE TRIGGER dbo.ResetCarMaintenance -- edit - include carid, only after update on service date
ON CarMaintenance
AFTER INSERT
AS
BEGIN
DECLARE @carid INT;
DECLARE @serDate DATETIME;


SELECT
	@carid = c.CarID
FROM Car c
INNER JOIN inserted i
	ON c.CarID = i.CarID;

UPDATE CarMaintenance
SET DueDate = DATEADD(YEAR, 1, ServiceDate)
   ,DueMiles = 1500
WHERE CarID = @carid
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

ALTER TRIGGER dbo.UpdateBookingsTable
ON dbo.Bookings
AFTER INSERT, UPDATE
AS
BEGIN
DECLARE @status VARCHAR;
DECLARE @bookid INT;
DECLARE @meterend INT;
DECLARE @meterstart INT;
DECLARE @carid INT;
DECLARE @meterrating INT;
DECLARE @pricepermile DECIMAL;
DECLARE @maxmilesperhr INT = 30;
DECLARE @cartierid INT;
DECLARE @bookingend DATETIME;
DECLARE @bookingstart DATETIME;
DECLARE @totalmiles INT;
DECLARE @allocatedmiles INT;
DECLARE @extratime DATETIME;
DECLARE @extratimepenalty DECIMAL;
DECLARE @ActualEndTime DATETIME;
DECLARE @penalty DECIMAL = 0;

SELECT
	@bookid = b.BookingID
FROM INSERTED i
FULL JOIN deleted d
	ON i.BookingID = d.BookingID;

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
	@cartierid = CarTierID
FROM Car
WHERE CarID = @carid

SELECT
	@meterrating = MeterRating
FROM Car
WHERE CarID = @carid

SELECT
	@bookingend = BookingEndTime
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@bookingstart = BookingStartTime
FROM Bookings
WHERE BookingID = @bookid

SELECT
	@ActualEndTime = ActualEndTime
FROM Bookings
WHERE BookingID = @bookid

SET @totalmiles = (@meterend - @meterstart)
SET @allocatedmiles = @maxmilesperhr * (@bookingend - @bookingstart)

	IF @status = 'Completed'
	BEGIN


UPDATE Car
SET MeterRating = MeterRating + (@meterend - @meterstart)
WHERE CarID = @carid

UPDATE CarMaintenance
SET DueMiles = DueMiles - (@meterend - @meterstart)
WHERE CarID = @carid

IF @totalmiles > @allocatedmiles
BEGIN
SET @penalty = @penalty + (@totalmiles - @allocatedmiles) * (SELECT
		ct.PricePerMile
	FROM Car c
		,CarTier ct
	WHERE ct.CarTierID = c.CarTierID)
			END
		IF @ActualEndTime > @bookingend
			BEGIN
SET @extratime = @ActualEndTime - @bookingend
SET @extratimepenalty = CAST(DATEPART(HOUR, @extratime) AS DECIMAL) * (SELECT
		PricePerHour
	FROM Car c
		,CarTier ct
	WHERE ct.CarTierID = c.CarTierID)

SET @penalty = @penalty + @extratimepenalty
			END

UPDATE Bookings
SET Penalty = @penalty
FROM Bookings
WHERE BookingID = @bookid
END

ELSE
IF @status = 'InProgress'
BEGIN
UPDATE Bookings
SET MeterStart = @meterrating
WHERE CarID = @carid

UPDATE RentalLocation
SET CurrentCapacity = CurrentCapacity - 1
WHERE RentalLocationID = (SELECT
		RentalLocationID
	FROM Car
	WHERE CarID = @carid)
END

IF @status = 'Booked'
BEGIN
UPDATE Bookings
SET RentalAmount = CAST((DATEPART(HOUR, BookingEndTime) - DATEPART(HOUR, BookingStartTime)) AS DECIMAL) * ct.PricePerHour
FROM Bookings b, Car c, CarTier ct
WHERE b.CarID = c.CarID
AND c.CarTierID = ct.CarTierID
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
   ,LicenseExpiry DATE NOT NULL CHECK (LicenseExpiry > DATEADD(MONTH, 6, CURRENT_TIMESTAMP))
   ,IsVerified BIT
   ,UserId INT NOT NULL REFERENCES UserAuth (UserId)
   ,CONSTRAINT LicenceNumberValidCheck CHECK (LicenseNumber LIKE '^[A-Z](?:\d[- ]*){14}$')
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
   ,CONSTRAINT cardExpiryCheck CHECK (ExpiryDate > DATEADD(MONTH, 6, CURRENT_TIMESTAMP))
   ,CONSTRAINT checkprimary CHECK (dbo.checkPrimaryCard(CustomerID) = 0)
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
   ,isAvailable AS dbo.checkavailability(CarID)
   ,RegistrationNumber VARCHAR NOT NULL
   ,DisableFriendly BIT
   ,RentalLocationID INT NOT NULL REFERENCES RentalLocation (RentalLocationID)
   ,MeterRating INT NOT NULL
   ,VendorID INT NOT NULL REFERENCES Vendor (VendorID)
);


CREATE TABLE CarMaintenance (
	MaintenanceID INT IDENTITY NOT NULL PRIMARY KEY
   ,ServiceDate DATETIME NOT NULL
   ,DueDate DATETIME
   ,DueMiles INT
   ,CarID INT NOT NULL REFERENCES Car (CarID)
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
   ,RentalAmount AS dbo.calculateRentalAmount(CarID)
   ,Penalty DECIMAL(8, 2)
   ,PaymentId INT REFERENCES Payment (PaymentId)
   ,CarID INT NOT NULL REFERENCES Car (CarID)
   ,ActualStartTime DATETIME
   ,ActualEndTime DATETIME
   ,BookingRating INTEGER
);

CREATE FUNCTION dbo.calculateRentalAmount (@CarID INT)
RETURNS DECIMAL
AS
BEGIN
DECLARE @sum INT = 0;
DECLARE @maxmilesperhr INT = 30;
DECLARE @cartierid INT;
DECLARE @status VARCHAR;

SELECT
	@cartierid = CarTierID
FROM Car
WHERE CarID = @carid

SELECT
	@status = Status
FROM Bookings
WHERE CarID = @carid

IF @status = 'Booked'
BEGIN
UPDATE Bookings
SET RentalAmount = CAST((DATEPART(HOUR, BookingEndTime) - DATEPART(HOUR, BookingStartTime)) AS DECIMAL) * ct.PricePerHour
FROM Bookings b, Car c, CarTier ct
WHERE b.CarID = c.CarID
AND c.CarTierID = ct.CarTierID
END
END

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
-- use HASHBYTES function to insert data  (https://www.mytecbits.com/microsoft/sql-server/sha-2-hashing) - completed

-- CARDETAILS
-- unique together on CardNumber and CustomerID - completed
-- cvv - encrypt - during insert

--CAR
-- make this a ercomputed column from Cartier - completed
-- update meterrating -> metrating + (meterend- meterstart) - completed
-- availability - complete

-- Renatl Location
-- current capacity - completed


-- BOOKINGS
-- trigger when inprogrss, get meterrating - completed
-- reduce miles for carmaintenance entity - completed
-- rentalamount - computed column - completed
-- penalty - create function -- actualendtime - bookingendtime * priceperhour or meterend - metertart * pricepermile - completed
-- create trigger to create paymentid - cancelled

-- Payment
-- Calculate Billing amount - completed

-- CArd Details
-- isprimary - unique for custid - completed
-- expirydate constarint should be more than 6 months - completed

-- Customer
-- License expiry - completed
-- isverified to false - function

-- Customer Membership
-- isactive- false if enddate > curr date