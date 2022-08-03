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

-- Close the symmetric key
CLOSE SYMMETRIC KEY randomkey;
-- Drop the symmetric key
DROP SYMMETRIC KEY randomkey;
-- Drop the certificate
DROP CERTIFICATE TestCertificate;
--Drop the DMK
DROP MASTER KEY;

-- housekeeping

--DROP FUNCTION 
-- funtions 

CREATE FUNCTION ValidateEmail(@Email VARCHAR(100))
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
RETURNS VARCHAR (40)
BEGIN
	DECLARE @cartype varchar(40);
SELECT
	@cartype = TierName
FROM CarTier
WHERE CarTierID = @CarTierID;
RETURN @cartype;
END;


CREATE FUNCTION dbo.checkPrimaryCard(@CustomerID INT)
returns INT
AS
BEGIN
	DECLARE @flag INT = 0;

	SET @flag = CASE 	
		WHEN EXISTS (SELECT
			*
		FROM CardDetails
		WHERE CustomerID = @CustomerID
		AND IsPrimary = 1) THEN 1
		ELSE 0
	END
	return @flag
END;

 

CREATE FUNCTION dbo.checkavailability(@CarID int)
returns BIT
AS
BEGIN
	declare @bookid INT;
	DECLARE @starttime DATETIME;
	DECLARE @endtime DATETIME;
	DECLARE @isavailable BIT;
	DECLARE @status VARCHAR(100);

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
END;

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
END;

CREATE FUNCTION dbo.getMeterRating(@CarID INT)
RETURNS INT 
AS
BEGIN
	DECLARE @meterrating int;

	SELECT @meterrating = MeterRating
	from Car
	where CarID = @carid

	RETURN @meterrating
END;

-- TRIGGERS
CREATE TRIGGER dbo.SET_UPDATEDATE 
ON UserAuth 
AFTER UPDATE 
AS 
BEGIN
	UPDATE UserAuth
	SET UpdatedAt = CURRENT_TIMESTAMP;
END;



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
END;

CREATE TRIGGER dbo.UpdateClosedTime
ON dbo.CustomerService
AFTER UPDATE
AS
BEGIN
DECLARE @status VARCHAR(100);
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
	DECLARE @status VARCHAR(100);
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
	DECLARE @extratime INT;
	DECLARE @extratimepenalty DECIMAL;
	DECLARE @ActualEndTime DATETIME;
	DECLARE @penalty DECIMAL = 0;
	DECLARE @custid int;
	DECLARE @rentalamount DECIMAL;
	DECLARE @cardid int;
	DECLARE @paymentid int;

	SELECT
		@bookid = COALESCE(i.BookingID, d.BookingID)
	FROM INSERTED i
	FULL JOIN deleted d
		ON i.BookingID = d.BookingID;

	SELECT
		@status = Status
	FROM Bookings
	WHERE BookingID = @bookid

	SELECT
		@custid = CustomerID
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
	SET @allocatedmiles = @maxmilesperhr * (DATEPART(HOUR,@bookingend) - DATEPART(HOUR,@bookingstart))

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
						print '@totalmiles > @allocatedmiles'
						PRINT @penalty 
						PRINT @totalmiles
						PRINT @allocatedmiles
						DECLARE @temp DECIMAL;
						SELECT @temp =  ct.PricePerMile FROM Car c,CarTier ct
									WHERE c.CarID = @carid and ct.CarTierID = c.CarTierID
						print @temp
						SET @penalty = @penalty + (@totalmiles - @allocatedmiles) * (SELECT ct.PricePerMile FROM Car c,CarTier ct
							WHERE c.CarID = @carid and ct.CarTierID = c.CarTierID)
					END
				print @penalty
				IF @ActualEndTime > @bookingend
					BEGIN
						SET @extratime = DATEPART(HOUR,@ActualEndTime) - DATEPART(HOUR,@bookingend)
						SET @extratimepenalty = @extratime * (SELECT PricePerHour FROM Car c,CarTier ct
							WHERE c.CarID = @carid and ct.CarTierID = c.CarTierID)
						SET @penalty = @penalty + @extratimepenalty
					print '@ActualEndTime > @bookingend'
					print @extratime
					print @extratimepenalty
					END
				print @penalty
			UPDATE Bookings SET Penalty = @penalty FROM Bookings 
				WHERE BookingID = @bookid
		
	
			UPDATE Payment
			SET BillingAmount = ((SELECT RentalAmount from Bookings WHERE BookingID = @bookid) + @penalty),
				ProcessedAt = CURRENT_TIMESTAMP,
				PaymentStatus = 'COMPLETED'
			WHERE PaymentID = (SELECT PaymentId from Bookings WHERE BookingID = @bookid)
		END

	IF @status = 'InProgress'
		BEGIN
			UPDATE Bookings
			SET MeterStart = @meterrating
			WHERE CarID = @carid and BookingID = @bookid;

			UPDATE RentalLocation
			SET CurrentCapacity = CurrentCapacity - 1
			WHERE RentalLocationID = (SELECT
					RentalLocationID
			FROM Car
			WHERE CarID = @carid)
		END
		print @rentalamount
		PRINT 'inside trigger'
	IF @status = 'Booked'
		BEGIN
			select @rentalamount = (CAST((DATEPART(HOUR, b.BookingEndTime) - DATEPART(HOUR, b.BookingStartTime)) AS DECIMAL) * ct.PricePerHour) + ct.BasicInsurance + ct.CollisionCoverage + ct.BodyCoverage + ct.MedicalCoverage
				FROM Bookings b, Car c, CarTier ct
				WHERE b.BookingID = @bookid 
					and b.CarID = c.CarID
					AND c.CarTierID = ct.CarTierID
			PRINT @rentalamount
			PRINT 'inside if'
			
			UPDATE Bookings
			SET RentalAmount = @rentalamount
			WHERE BookingID = @bookid

			SELECT @cardid = CardID from CardDetails WHERE CustomerID = @custid

			INSERT INTO Payment VALUES(@cardid, @rentalamount, CURRENT_TIMESTAMP, 'PENDING')
			SELECT @paymentid = Scope_Identity()

			UPDATE Bookings
			set PaymentId = @paymentid
			WHERE BookingID = @bookid
		END
	PRINT @rentalamount
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
   ,Username VARCHAR(100) NOT NULL
   ,Password VARBINARY(300) NOT NULL
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
);


CREATE TABLE Customer (
	CustomerID INT IDENTITY NOT NULL PRIMARY KEY
   ,FirstName VARCHAR(250) NOT NULL
   ,MiddleName VARCHAR(250)
   ,LastName VARCHAR(250) NOT NULL
   ,Age AS dbo.CalculateAge(DateOfBirth)
   ,StreetName VARCHAR(60) NOT NULL
   ,City VARCHAR(40) NOT NULL
   ,State VARCHAR(40) NOT NULL
   ,ZipCode INT NOT NULL
   ,EmailID VARCHAR(40) NOT NULL
   ,PhoneNumber VARCHAR(30) NOT NULL
   ,DateOfBirth DATE NOT NULL
   ,LicenseNumber VARCHAR(17) NOT NULL
   ,LicenseExpiry DATE NOT NULL CHECK (LicenseExpiry > DATEADD(MONTH, 6, CURRENT_TIMESTAMP))
   ,IsVerified BIT
   ,UserId INT NOT NULL REFERENCES UserAuth (UserId)
   --,CONSTRAINT LicenceNumberValidCheck CHECK (LicenseNumber LIKE '^[A-Z](?:\d[- ]*){14}$')
);

ALTER TABLE Customer ADD CONSTRAINT checkValidEmailCustomer CHECK (dbo.ValidateEmail(EmailID) = 1);


CREATE TABLE CardDetails (
	CardID INT IDENTITY NOT NULL PRIMARY KEY
   ,NameOnCard VARCHAR(60) NOT NULL
   ,ExpiryDate DATETIME NOT NULL
   ,PaymentMethod VARCHAR(20) NOT NULL CHECK ([PaymentMethod] IN ('Credit', 'Debit'))
   ,CVV VARBINARY(300) NOT NULL
   ,CardNumber VARBINARY(300) NOT NULL
   ,IsPrimary BIT
   ,CustomerID INT NOT NULL REFERENCES Customer (CustomerID)
   ,CONSTRAINT cardExpiryCheck CHECK (ExpiryDate > DATEADD(MONTH, 6, CURRENT_TIMESTAMP))
   --,CONSTRAINT checkprimary CHECK (dbo.checkPrimaryCard(CustomerID) = 0)
);

-- unique together on CardNumber and CustomerID 
ALTER TABLE dbo.CardDetails
ADD CONSTRAINT uq_cardNo_CustID UNIQUE (CardNumber, CustomerID);


CREATE TABLE Payment (
	PaymentID INT IDENTITY NOT NULL PRIMARY KEY
   ,CardID INT NOT NULL REFERENCES CardDetails (CardID)
   ,BillingAmount DECIMAL(7, 2) NOT NULL
   ,ProcessedAt DATETIME
   ,PaymentStatus VARCHAR(20) NOT NULL CHECK ([PaymentStatus] IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'))
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
   ,InsuranceStatus VARCHAR(20) NOT NULL CHECK ([InsuranceStatus] IN ('ACTIVE', 'EXPIRED'))
   ,CarType AS dbo.getCarType(CarTierID)
   ,isAvailable BIT
   ,RegistrationNumber VARCHAR(20) NOT NULL
   ,DisableFriendly BIT
   ,RentalLocationID INT NOT NULL REFERENCES RentalLocation (RentalLocationID)
   ,MeterRating INT NOT NULL
   ,VendorID INT NOT NULL REFERENCES Vendor (VendorID)
);


CREATE TABLE CarMaintenance (
	MaintenanceID INT IDENTITY NOT NULL PRIMARY KEY
   ,ServiceDate as CURRENT_TIMESTAMP
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
   ,Status VARCHAR(30) NOT NULL CHECK ([status] IN ('Cancelled', 'Completed', 'InProgress', 'Booked')) DEFAULT 'Booked'
   ,BookingStartTime DATETIME NOT NULL
   ,BookingEndTime DATETIME NOT NULL
   ,MeterStart INT
   ,MeterEnd INT
   ,RentalAmount DECIMAL(9,2)
   ,Penalty DECIMAL(8, 2)
   ,PaymentId INT REFERENCES Payment (PaymentId)
   ,CarID INT NOT NULL REFERENCES Car (CarID)
   ,ActualStartTime DATETIME
   ,ActualEndTime DATETIME
   ,BookingRating INT
);


CREATE TABLE CustomerService (
	ServiceID INT IDENTITY NOT NULL PRIMARY KEY
   ,ComplaintStatus VARCHAR(20) CHECK ([ComplaintStatus] IN ('Registered', 'In-Progress', 'Closed'))
   ,Rating INT
   ,IssueTitle VARCHAR(250) NOT NULL
   ,IssueDescription VARCHAR(1000) NOT NULL
   ,CreatedTime AS CURRENT_TIMESTAMP
   ,CloseTime DATETIME
   ,BookingId INT NOT NULL REFERENCES Bookings (BookingId)
   ,EmployeeId INT NOT NULL REFERENCES Employee (EmployeeId)
);

-- HouseKeeeping
USE Team6;

DROP TABLE CustomerService;
DROP TABLE Bookings;
DROP TABLE VendorTransactions;
DROP TABLE CarMaintenance;
DROP TABLE Car;
DROP TABLE CustomerMembership;
DROP TABLE Payment;
DROP TABLE CardDetails;
DROP TABLE Customer;
DROP TABLE CarTier;
DROP TABLE Vendor;
DROP TABLE RentalLocation;
DROP TABLE UserAuth;
DROP TABLE Employee;
DROP TABLE Membership;


DELETE FROM CustomerService;
DELETE FROM Bookings;
DELETE FROM VendorTransactions;
DELETE FROM CarMaintenance;
DELETE FROM Car;
DELETE FROM CustomerMembership;
DELETE from Payment;
DELETE FROM CardDetails;
DELETE FROM Customer;
DELETE FROM CarTier;
DELETE FROM Vendor;
DELETE FROM RentalLocation;
DELETE FROM UserAuth;
DELETE FROM Employee;
DELETE FROM Membership;


-- INSERT STATEMENTS
SET IDENTITY_INSERT Team6.dbo.Membership ON;
GO
INSERT INTO Team6.dbo.Membership (MembershipID, Duration, Price, Status, MembershipType) 
values 
(100, 3, 100.00, 1, 'Standard'),
(101, 6, 150.00, 1, 'Standard'),
(102, 12, 200.00, 1, 'Standard'),
(103, 3, 200.00, 1, 'Premium'),
(104, 6, 300.00, 1, 'Premium'),
(105, 12, 350.00, 1, 'Premium'),
(106, 3, 300.00, 1, 'Executive'),
(107, 6, 360.00, 1, 'Executive'),
(108, 12, 400.00, 1, 'Executive'),
(109, 24,550.00, 1, 'Executive');
GO
SET IDENTITY_INSERT Team6.dbo.Membership OFF;
GO
SET IDENTITY_INSERT Team6.dbo.Employee ON;

GO
insert into Team6.dbo.Employee (EmployeeID, FirstName, MiddleName, LastName, Designation, EmailID)
values
(1000, 'Raina', 'Suresh', 'Rasu', 'Manager','sureshraina@gmail.com'),
(1001, 'Kunal', 'Ramesh', 'Ved', 'Customer Service','srk228@gmail.com'),
(1002, 'Sachin', 'Suresh', 'Sid', 'Front Desk','ssss56@gmail.com'),
(1003, 'Shweta', 'Billie', 'Kate', 'Front Desk','funman@gmail.com'),
(1004, 'Naina', 'Shiva', 'Shenoy', 'Manager','killiey@gmail.com'),
(1005, 'Jane', 'Priya', 'Bina', 'Manager','priya@gmail.com'),
(1006, 'Raj', 'Vikram', 'Mary', 'Manager','vikram@gmail.com'),
(1007, 'Karthik', 'R', 'Gopal', 'Front Desk','vik387@gmail.com'),
(1008, 'Rj', 'Khatari', 'Jose', 'Customer Service','756ram@gmail.com'),
(1009, 'Isabelle', 'Jerome', 'Josh', 'Customer Service','majo11@gmail.com')
GO
SET IDENTITY_INSERT Team6.dbo.Employee OFF;

GO
SET IDENTITY_INSERT Team6.dbo.UserAuth ON;
GO
INSERT INTO dbo.UserAuth (UserId, Username, Password, CreatedAt, UpdatedAt) VALUES 
(1001, 'NeilDavidson',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1002, 'VictoriaBerry',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1003, 'LeonardMorrison',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1004, 'JackGlover',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1005, 'DeirdrePeake',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1006, 'YvonneDuncan',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1007, 'CarlBower',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1008, 'MaxBrown',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1009, 'AbigailStewart',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(1010, 'ConnorKelly',EncryptByKey(Key_GUID(N'randomkey'),'123456789'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
GO
SET IDENTITY_INSERT Team6.dbo.UserAuth OFF;

GO
SET IDENTITY_INSERT Team6.dbo.RentalLocation ON;
GO
INSERT INTO RentalLocation (RentalLocationID, MaxCapacity, CurrentCapacity, StreetName, City, State, Zipcode) VALUES
  (3000, 100, 100, '183-3661 Magnis Road','San Diego', 'California', 94156),
  (3001, 100, 100, '728-9865 Aptent Rd.','Springfield','Boston',10237),
  (3002, 100, 100, '9040 In Rd.','Wichita','Prince Albert',30238),
  (3003, 100, 100, 'P.O. Box 881, 5272 Ut St.','West Jordan', 'Townsville',07687),
  (3004, 100, 100, '312-1840 Nec Road','Augusta', 'Tunja',620841),
  (3005, 100, 100, 'P.O. Box 631, 163 Luctus Avenue','Spokane', 'Bremen',13145),
  (3006, 100, 100, 'Ap #413-9706 Lorem. St.','Springfield', 'Gliwice',54138),
  (3007, 100, 100, '138-418 A, St.','Chattanooga','Kerikeri',87862),
  (3008, 100, 100, '7988 Eu, Road','West Jordan', 'Gorinchem',87329),
  (3009, 100, 100, 'P.O. Box 527, 6711 Eu Road','San Diego', 'Te Puke',59921);
GO
SET IDENTITY_INSERT Team6.dbo.RentalLocation OFF;

GO
SET IDENTITY_INSERT Team6.dbo.Vendor ON;
GO
INSERT INTO dbo.Vendor(VendorID, Name, IsVerified) VALUES
(2001, 'TDKMotors', 1),
(2002, 'SKMotors', 1),
(2003, 'GDKMotors', 1),
(2004, 'THKMotors', 1),
(2005, 'TPKMotors', 1),
(2006, 'TNTMotors', 1),
(2007, 'DFEMotors', 1),
(2008, 'METMotors', 1),
(2009, 'PowerMotors', 1),
(2010, 'MPDMotors', 1);
GO
SET IDENTITY_INSERT Team6.dbo.Vendor OFF;

GO
SET IDENTITY_INSERT Team6.dbo.CarTier ON;
GO
insert into Team6.dbo.CarTier (CarTierID, TierName, PricePerHour, BasicInsurance, PricePerMile, CollisionCoverage, BodyCoverage, MedicalCoverage)
values
(1000, 'Hatchback', 15.00,12.00,8.00,10.00,10.00,10.00),
(1001, 'Sedan', 17.00,15.00,12.00,11.00,12.00,12.00),
(1002, 'MPV', 19.00,17.00,16.00,13.00,13.00,13.00),
(1003, 'SUV', 21.00,19.00,20.00,15.00,14.00,14.00),
(1004, 'Crossover',23.00,23.00,24.00,17.00,17.00,17.00),
(1005, 'Sedan',24.00,25.00,25.00,19.00,17.00,17.00),
(1006, 'Coupe',27.00,27.00,32.00,21.00,18.00,18.00),
(1007, 'Convertible',29.00, 29.00,26.00,19.00,19.00,19.00);
GO
SET IDENTITY_INSERT Team6.dbo.CarTier OFF;

GO
SET IDENTITY_INSERT Team6.dbo.Customer ON;
GO
INSERT INTO Team6.dbo.Customer (CustomerID, FirstName, MiddleName, LastName, StreetName, City, State, ZipCode, EmailID, PhoneNumber, DateOfBirth, LicenseNumber, LicenseExpiry, IsVerified, UserId)
VALUES
  (100,'Carol','Orli Fry','Murphy','377-8230 Bibendum Street','Dublin','Oxfordshire',21187,'vitae@aol.com','(642) 974-6477','Aug 11, 1978','D6101-40706-60905','Feb 24, 2041',1, 1001),
  (101,'George','Deirdre Crosby','Hendrix','Ap #389-9346 Cras Ave','Marawi','East Kalimantan',48832,'sociosqu.ad@outlook.couk','1-611-231-7667','Mar 10, 1966','D6341-40706-60342','Jul 31, 2041',1, 1002),
  (102,'Daria','Stewart Hopper','Slater','P.O. Box 314, 4655 Eu St.','Gimcheon','Puglia',73481,'ultricies.sem@aol.edu','(291) 989-3887','May 23, 1975','F6671-43536-60097','Nov 6, 2040',1, 1003),
  (103,'Allegra','Dolan Hester','Blackwell','266-7187 Integer Rd.','Forchtenstein','New Brunswick',14727,'tortor@hotmail.couk','(746) 704-7825','Jun 27, 1967','Z6101-40706-60012','Dec 31, 2040',1, 1004),
  (104,'Vernon','Xander Allison','Davidson','Ap #323-8451 Egestas St.','Skegness','Xinan',51707,'justo@aol.com','1-138-557-3693','Dec 2, 1967','K6101-40706-60523','Jan 7, 2041',1, 1005),
  (105,'Keane','Jade Haynes','Hamilton','Ap #520-7983 Pellentesque Ave','Anseong','Vastra Gotalands lan',60026,'lobortis.augue.scelerisque@yahoo.ca','1-491-349-9113','Feb 1, 1962','H8101-40706-60082','Jul 24, 2041',1, 1006),
  (106,'Prescott','Meredith Cross','Schneider','540-1241 Magna. Road','Swat','Sicilia',47862,'nunc.id.enim@protonmail.edu','(426) 779-5386','Feb 5, 1969','M8001-40706-60661','Feb 24, 2041',1, 1007),
  (107,'Sage','Cameran Reed','Melton','P.O. Box 515, 2511 Sagittis St.','Bad Neuenahr-Ahrweiler','Derbyshire',04352,'pharetra@protonmail.couk','(916) 396-0879','Apr 23, 1973','B9801-40196-25419','May 13, 2041',1, 1008),
  (108,'Yasir','Shaine Craft','Haynes','P.O. Box 565, 8223 Aliquet Rd.','Barranca','Gilgit Baltistan',70992,'sit@hotmail.com','(320) 751-0213','Jan 2, 1964','X7601-40196-58465','Aug 27, 2040',1, 1009),
  (109,'Oren','Jerome Eaton','Sargent','9724 Ut Ave','Meppel','Selkirkshire',97956,'at.augue.id@outlook.edu','1-643-775-8358','Aug 20, 1967','C5321-72844-32746','Sep 15, 2040',1, 1010); 
SET IDENTITY_INSERT Team6.dbo.Customer OFF;

GO
SET IDENTITY_INSERT Team6.dbo.CardDetails ON;
GO
INSERT INTO Team6.dbo.CardDetails(CardID, NameOnCard, ExpiryDate, PaymentMethod, CVV, CardNumber, IsPrimary, CustomerID)
VALUES
  (7001,'Carol Murphy','Nov 16, 2023','Credit',EncryptByKey(Key_GUID(N'randomkey'),'795'),EncryptByKey(Key_GUID(N'randomkey'),'4556854473966842'),0, 100),
  (7002,'George Hendrix','Sep 16, 2023','Credit',EncryptByKey(Key_GUID(N'randomkey'),'991'),EncryptByKey(Key_GUID(N'randomkey'),'4556597422834757'),0, 101),
  (7003,'Daria Slater','Dec 12,2023', 'Debit',EncryptByKey(Key_GUID(N'randomkey'),'964'),EncryptByKey(Key_GUID(N'randomkey'),'4532845626224435'),0, 102),
  (7004,'Allegra Blackwell','Feb 01,2024','Credit',EncryptByKey(Key_GUID(N'randomkey'),'643'),EncryptByKey(Key_GUID(N'randomkey'),'4929426823241'),0, 103),
  (7005,'Vernon Davidson','April 24,2023', 'Debit',EncryptByKey(Key_GUID(N'randomkey'),'823'),EncryptByKey(Key_GUID(N'randomkey'),'4485669344742214'),0, 104),
  (7006,'Keane Hamilton','Oct 19, 2023', 'Credit',EncryptByKey(Key_GUID(N'randomkey'),'638'),EncryptByKey(Key_GUID(N'randomkey'),'4485824236973'),0, 105),
  (7007,'Prescott Schneider','Nov 26, 2023', 'Debit',EncryptByKey(Key_GUID(N'randomkey'),'481'),EncryptByKey(Key_GUID(N'randomkey'),'4929648576516573'),0, 106),
  (7008,'Sage Melton','May 01,2024', 'Credit',EncryptByKey(Key_GUID(N'randomkey'),'116'),EncryptByKey(Key_GUID(N'randomkey'),'4532721623584412'),0, 107),
  (7009,'Yasir Haynes','Dec 28, 2023', 'Debit',EncryptByKey(Key_GUID(N'randomkey'),'528'),EncryptByKey(Key_GUID(N'randomkey'),'4024007112275695'),0, 108),
  (7010,'Oren Sargent','Oct 11, 2023', 'Credit',EncryptByKey(Key_GUID(N'randomkey'),'524'),EncryptByKey(Key_GUID(N'randomkey'),'4539652722474333'),0, 109);
  --(7011,'Oren Sargent','Oct 11, 2023', 'Credit',EncryptByKey(Key_GUID(N'randomkey'),'524'),EncryptByKey(Key_GUID(N'randomkey'),'453923452722474333'),1, 109);
GO
SET IDENTITY_INSERT Team6.dbo.CardDetails OFF;


GO
SET IDENTITY_INSERT Team6.dbo.Car ON;
GO
INSERT INTO Team6.dbo.Car(CarID, Model, Make, Color, CarTierID, ManufacturingYear, SeatCapacity, 
	InsuranceStatus, isAvailable, RegistrationNumber, DisableFriendly, RentalLocationID, MeterRating, VendorID)
VALUES
 (5001, 'MX300', 'HONDA', 'RED', 1000, 2016, 4, 'ACTIVE', 1,'S6J 6E3', 1, 3003, 10500, 2002),
 (5002, 'CX600', 'KIA', 'WHITE', 1001, 2018, 4, 'ACTIVE', 1,'I5K 9O1', 0, 3001, 1500, 2007),
 (5003, 'A6000', 'LEXUS', 'BLACK', 1002, 2020, 4, 'ACTIVE', 1,'N6U 5B0', 1, 3005, 15000, 2008),
 (5004, 'ETIOS', 'TOYOTA', 'BLUE', 1003, 2012, 4, 'ACTIVE', 1,'W8V 7U4', 0, 3006, 8567, 2005),
 (5005, 'CIVIC', 'HONDA', 'RED', 1004, 2020, 4, 'ACTIVE', 1, 'T4R 7E4', 1, 3007, 20349, 2003),
 (5006, 'T3000', 'TOYOTA', 'RED', 1005, 2017, 4, 'EXPIRED',  1,'O2M 7Y5', 1, 3008, 25678, 2009),
 (5007, 'C3000', 'HONDA', 'WHITE', 1006, 2015, 4, 'ACTIVE',  1,'G2X 5E1', 0, 3009, 8000, 2010),
 (5008, 'INDICA', 'TATA', 'RED', 1007, 2012, 4, 'ACTIVE',  1, 'T8J 1Q5', 1, 3004, 4500, 2006),
 (5009, 'H1000', 'HONDA', 'BLACK', 1000, 2018, 4, 'ACTIVE',  1,'L1M 2Q9', 1, 3008, 3677, 2005),
 (5010, 'CITY', 'HONDA', 'BLACK', 1000, 2014, 4, 'ACTIVE',  1,'P5T 9Q8', 0, 3005, 66788, 2004); 
GO
SET IDENTITY_INSERT Team6.dbo.Car OFF;

GO
SET IDENTITY_INSERT Team6.dbo.VendorTransactions ON;
GO
INSERT INTO VendorTransactions(VendorTransactionID, VendorID, TransactionTime, CarID, TransactionValue) 
VALUES
(7800, 2002, '2016-05-01 12:36:30.123', 5001, 66000.50),
(7801, 2007, '2018-06-06 08:36:30.113', 5002, 56000.50),
(7802, 2008, '2020-02-12 06:26:40.163', 5003, 48500.50),
(7803, 2005, '2012-07-03 02:36:30.173', 5004, 33000.50),
(7804, 2003, '2020-08-07 12:36:20.123', 5005, 15000.50),
(7805, 2009, '2017-09-07 02:36:10.183', 5006, 34000.50),
(7806, 2010, '2015-02-02 12:36:30.163', 5007, 56500.50),
(7807, 2006, '2012-01-03 07:36:20.193', 5008, 36000.50),
(7808, 2005, '2018-08-08 05:36:15.113', 5009, 56500.50),
(7809, 2004, '2014-03-09 08:36:10.103', 5010, 23500.50);
SET IDENTITY_INSERT Team6.dbo.VendorTransactions OFF;

GO
SET IDENTITY_INSERT Team6.dbo.CustomerMembership ON;
GO
INSERT INTO Team6.dbo.CustomerMembership(CustomerMembershipID, StartDate, isactive , CustomerID, MembershipID) 
VALUES
(1000, '2022-05-01', 1,100, 104),
(1001, '2022-06-06', 1,101, 101),
(1002, '2022-02-12', 1,102, 106),
(1003, '2012-07-03', 1,103, 103),
(1004, '2021-08-07', 1,104, 107),
(1005, '2022-09-07', 1,105, 105),
(1006, '2022-02-02', 1,106, 108),
(1007, '2022-01-03', 1,107, 104),
(1008, '2022-08-08', 1,108, 108),
(1009, '2022-03-09', 1,109, 109);
SET IDENTITY_INSERT Team6.dbo.CustomerMembership OFF;

GO
SET IDENTITY_INSERT Team6.dbo.CarMaintenance ON;
GO
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1000, 5001);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1001, 5002);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1002, 5003);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1003, 5004);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1004, 5005);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1005, 5006);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1006, 5007);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1007, 5008);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1008, 5009);
INSERT INTO Team6.dbo.CarMaintenance(MaintenanceID, CarID)
VALUES
(1009, 5010);
GO
SET IDENTITY_INSERT Team6.dbo.CarMaintenance OFF;

GO
SET IDENTITY_INSERT Team6.dbo.Bookings ON;
GO
INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3000, 100, 'Booked', DATEADD(DAY, 20, CURRENT_TIMESTAMP), DATEADD(HOUR, 5, DATEADD(DAY, 20, CURRENT_TIMESTAMP)), 5001);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 20, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3000; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 20, CURRENT_TIMESTAMP)), BookingRating = 4, MeterEnd=10700
FROM Bookings
WHERE BookingID=3000;

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3001, 101, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5002);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3001; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 3, MeterEnd=1520
FROM Bookings
WHERE BookingID=3001;

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3002, 102, 'Booked', DATEADD(DAY, 25, CURRENT_TIMESTAMP), DATEADD(HOUR, 6, DATEADD(DAY, 25, CURRENT_TIMESTAMP)), 5002);

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3003, 101, 'Booked', DATEADD(DAY, 5, CURRENT_TIMESTAMP), DATEADD(HOUR, 4, DATEADD(DAY, 5, CURRENT_TIMESTAMP)), 5003);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 5, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3003; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 5 , CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=15400
FROM Bookings
WHERE BookingID=3003;

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3004, 103, 'Booked', DATEADD(DAY, 34, CURRENT_TIMESTAMP), DATEADD(HOUR, 6, DATEADD(DAY, 34, CURRENT_TIMESTAMP)), 5005);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 34, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3004; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 34, CURRENT_TIMESTAMP)), BookingRating = 3, MeterEnd=20380
FROM Bookings
WHERE BookingID=3004;

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3005, 104, 'Booked', DATEADD(DAY, 27, CURRENT_TIMESTAMP), DATEADD(HOUR, 4, DATEADD(DAY, 27, CURRENT_TIMESTAMP)), 5002);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 10, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3005; 

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3006, 105, 'Booked', DATEADD(DAY, 6, CURRENT_TIMESTAMP), DATEADD(HOUR, 7, DATEADD(DAY, 6, CURRENT_TIMESTAMP)), 5006);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 6, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3006; 

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3007, 106, 'Booked', DATEADD(DAY, 45, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 45, CURRENT_TIMESTAMP)), 5004);

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3008, 102, 'Booked', DATEADD(DAY, 30, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 30, CURRENT_TIMESTAMP)), 5003);

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3010, 107, 'Booked', DATEADD(DAY, 3, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 3, CURRENT_TIMESTAMP)), 5007);




	-- CAR ID 5008


INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3009, 101, 'Booked', DATEADD(DAY, 13, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 13, CURRENT_TIMESTAMP)), 5010);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 13, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3009; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1520
FROM Bookings
WHERE BookingID=3009;


-----------------------------------


GO
SET IDENTITY_INSERT Team6.dbo.Bookings ON;
GO
INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3011, 101, 'Booked', DATEADD(DAY, 13, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 13, CURRENT_TIMESTAMP)), 5008);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 13, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3011; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1520
FROM Bookings
WHERE BookingID=3011;

--------------------------------------


INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3012, 101, 'Booked', DATEADD(DAY, 13, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 13, CURRENT_TIMESTAMP)), 5009);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 13, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3012; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1520
FROM Bookings
WHERE BookingID=3012;

----------------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3013, 101, 'Booked', DATEADD(DAY, 13, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 13, CURRENT_TIMESTAMP)), 5008);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 13, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3013; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 6, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 4, MeterEnd=1530
FROM Bookings
WHERE BookingID=3013;

--------------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3014, 109, 'Booked', DATEADD(DAY, 13, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 13, CURRENT_TIMESTAMP)), 5009);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 13, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3014; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 8, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1556
FROM Bookings
WHERE BookingID=3014;

------------------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3015, 101, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5008);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3015; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 3, MeterEnd=1520
FROM Bookings
WHERE BookingID=3015;

--------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3016, 103, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5008);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3016; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1520
FROM Bookings
WHERE BookingID=3016;

---------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3017, 103, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5010);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3017; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 6, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 2, MeterEnd=1545
FROM Bookings
WHERE BookingID=3017;

-------------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3018, 103, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 3, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5010);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3018; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 4, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1542
FROM Bookings
WHERE BookingID=3018;

-------------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3019, 101, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5005);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3019; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 4, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1542
FROM Bookings
WHERE BookingID=3019;

------------------------------------------------


INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3020, 101, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 6, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5005);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3020; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 3, MeterEnd=1548
FROM Bookings
WHERE BookingID=3020;

-----------------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3021, 101, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 6, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5005);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 13, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3021; 

--UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), MeterEnd=1548
--FROM Bookings
--WHERE BookingID=3021;

---------------------------------------------

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3022, 101, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 6, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5010);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3022; 

--UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), MeterEnd=1548
--FROM Bookings
--WHERE BookingID=3021;

INSERT INTO Team6.dbo.Bookings(BookingID, CustomerID, Status, BookingStartTime, BookingEndTime, CarID)
VALUES
(3023, 105, 'Booked', DATEADD(DAY, 12, CURRENT_TIMESTAMP), DATEADD(HOUR, 6, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), 5010);

UPDATE Team6.dbo.Bookings SET Status='InProgress', ActualStartTime = DATEADD(DAY, 12, CURRENT_TIMESTAMP)
FROM Bookings
WHERE BookingID=3023; 

UPDATE Team6.dbo.Bookings SET Status='Completed', ActualEndTime = DATEADD(HOUR, 5, DATEADD(DAY, 12, CURRENT_TIMESTAMP)), BookingRating = 5, MeterEnd=1548
FROM Bookings
WHERE BookingID=3023;



SELECT * FROM Bookings

GO
SET IDENTITY_INSERT Team6.dbo.Bookings OFF;

GO
SET IDENTITY_INSERT Team6.dbo.CustomerService ON;
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9001,'Registered',2, 'Unable to book car for given date', 'What advantage is there in booking directly with an airline rather than through an agent? I have almost always booked with the airline but now have an agent whose price is around $50 cheaper than airline and airline does not have price match.
', DATEADD(HOUR, 1, getdate()), 3000,1000);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9003,'Registered',2, 'Card not working ending 6788', 'Does anyone know where Id find estimated prices from Atlanta. My vacation destination is up in the air at this point and Im flexible so Id like to find a listing of places that are cheap to fly. Mexico, carribean, central american are all good choices. Thanks in advance.
', DATEADD(HOUR, 2, getdate()), 3001,1001);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9004,'In-Progress',7, 'No car model available', 'Last night a guy travelling alone was moved from his seat into an exit row before takeoff.
', DATEADD(HOUR, 4, getdate()), 3002,1002);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9002,'In-Progress',9, 'Car rental price not available!', 'Next week we are off to Tunisia with Thomas Cook. . I know times are hard, but why do these companies insult our intelligence by claiming that the latest penny-pinching reduction in service is an Ã¢â‚¬Å“improvementÃ¢â‚¬Â�? Geoff
', DATEADD(HOUR, 5, getdate()), 3003,1003);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9005,'Closed',5, 'Is MX300 disable friendly?', 'Evening Just wondered if anyone had a valid discount code for the terminal 2 meet and greet parking. Thanks
', DATEADD(HOUR, 1, getdate()), 3004, 1004);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9006,'Closed',9, 'What is the make year for H1000?', 'Hi, As information to those who are frequent AA or One World alliance passengers and fly to/from/via LAX and Shanghai. 
', DATEADD(HOUR, 2, getdate()), 3005, 1005);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9007,'Registered',4, 'Customer name not showing in booking', 'Just a heads up for my fellow TripAdvisior travelers: Delta "Partners" with Alitalia out of Rome. 
', DATEADD(HOUR, 7, getdate()), 3006, 1006);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9008,'Registered',10, 'Unable to add card details', 'Can anyone help us decide on which card gives the most bang for your buck with regard to frequent flier miles. Wed like to be able to take advantage of using a credit card to accumulate miles to offset our air travel costs.
', DATEADD(HOUR, 4, getdate()), 3007, 1007);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9009,'In-Progress',9, 'Payment gateway error', 'I have heard that today travel companies have been informed that the Thompson Dreamliner from UK will not operate until late this year or, next year. Bookings for this aircraft now seem not to be available for 2013.
', DATEADD(HOUR, 7, getdate()), 3008, 1008);
INSERT INTO Team6.dbo.CustomerService(ServiceID, ComplaintStatus, Rating, IssueTitle, IssueDescription, CloseTime, BookingId, EmployeeId) VALUES
  (9010,'In-Progress',0, 'How to do Advanced booking?', 'There always seems to be scatch cards coming around on the package tour planes where we are told a percentage goes to a charity but does anybody know what percentage is actually given to the charity
',  DATEADD(HOUR, 8, getdate()), 3010, 1009);
SET IDENTITY_INSERT Team6.dbo.CustomerService OFF;

-- SELECT STATEMENTs 
SELECT * from Bookings;
SELECT * from Car;
SELECT * from CardDetails;
SELECT * from CarMaintenance;
SELECT * from CarTier;
SELECT * from Customer;
SELECT * from CustomerMembership;
SELECT * from CustomerService;
SELECT * from Employee;
SELECT * from Membership;
SELECT * from Payment;
SELECT * from RentalLocation;
SELECT * from UserAuth;
SELECT * from Vendor;
SELECT * from VendorTransactions;


-------------------------------------------------------------------------------------
---View to get number of cars  available for at a  Rental Location---------------------


CREATE VIEW view_NumberOfCarsAvailable
	AS
	SELECT rl.RentalLocationID , MaxCapacity, 
		CurrentCapacity, STRING_AGG(CAST(rl.StreetName as VARCHAR) + ', ' + CAST(rl.City as VARCHAR) + CAST(rl.State as VARCHAR) + CAST(rl.Zipcode as VARCHAR), ', ') as Address, count(c.CarID) as NumberOfCarsAvailable
	FROM RentalLocation rl
	INNER JOIN Car c
	on c.RentalLocationID = rl.RentalLocationID 
	WHERE c.isAvailable = 1
	Group by rl.RentalLocationID , MaxCapacity, CurrentCapacity

SELECT * FROM view_NumberOfCarsAvailable;

-- show no. of booking for a car in last 30 days
-- show relevant info for a car
	-- show no. of bookings
	-- show avg rating
	-- show total miles


---- View for checking number of bookings for a session ---- 
-- this can help car rental business for increasing or decreasing number of bookings being held per time period in order to increase profit


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


-- DATA insertion error
	-- Carddetails- Customerid - check, unique
	-- CUSTOMER - Emailid
	-- Employee - emailid


	--NEW TODO
	-- car
		-- isavailable change function to trigger
	-- carddetails - isprimary