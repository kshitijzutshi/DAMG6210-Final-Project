-- encryption for card details

CREATE MASTER KEY 
ENCRYPTION BY PASSWORD = 'Team6@dmdd';

CREATE CERTIFICATE TestCertificate 
WITH SUBJECT  = 'to_hide',
EXPIRY_DATE = '2025-08-26';

CREATE SYMMETRIC KEY randomkey
WITH ALGORITHM = AES_128
ENCRYPTION BY CERTIFICATE TestCertificate ;

OPEN SYMMETRIC KEY randomkey 
DECRYPTION BY CERTIFICATE TestCertificate ;

-- funtions 

CREATE FUNCTION ValidateEmail(@Email VARCHAR)
RETURNS INT 
BEGIN 
	DECLARE @ISVALID INT 
	SET @ISVALID = CASE WHEN @Email LIKE '%_@__%.__%' THEN 1 ELSE 0 END
	RETURN @ISVALID
END


CREATE FUNCTION CalculateAge(@DOB DATE)
RETURNS INT 
BEGIN 
	DECLARE @age INT 
	SET @age = DATEDIFF(hour,@DOB,GETDATE())/8766
	RETURN @age
END

CREATE FUNCTION CalculateMembershipEndDate(@STARTDATE DATE, @MEMBERSHIPID INT)
RETURNS DATE 
BEGIN 
	DECLARE @MemDuration INT 
	DECLARE @ENDDATE DATE 
	SELECT @MemDuration = Duration from Membership where MembershipID=@MEMBERSHIPID
	SET @ENDDATE = DATEADD(MONTH, @MemDuration, @STARTDATE) 
	RETURN @ENDDATE
END

CREATE FUNCTION CalculateMembershipCost(@MEMBERSHIPID INT)
RETURNS DECIMAL 
BEGIN 
	DECLARE @MemCost DECIMAL
	SELECT @MemCost=Duration*Price from Membership where MembershipID=@MEMBERSHIPID
	RETURN @MemCost
END

-- table creation

CREATE TABLE dbo.Membership (
  MembershipID INT IDENTITY NOT NULL PRIMARY KEY,
  Duration INT NOT NULL,
  Price INT NOT NULL,
  Status BIT NOT NULL,
  MembershipType VARCHAR(30) NOT NULL CHECK ([MembershipType] IN('Standard', 'Premium', 'Executive')) DEFAULT 'Standard',
);

CREATE TABLE dbo.Employee (
  EmployeeID INT IDENTITY NOT NULL PRIMARY KEY,
  FirstName VARCHAR(250) NOT NULL,
  MiddleName VARCHAR(250),
  LastName VARCHAR(250),
  Designation VARCHAR(40),
  EmailID VARCHAR(40) NOT NULL,
);
ALTER TABLE Employee ADD CONSTRAINT checkValidEmail CHECK (dbo.ValidateEmail(EmailID) = 1); 


CREATE TABLE UserAuth (
  UserId INT IDENTITY NOT NULL PRIMARY KEY,
  Username VARCHAR(20) NOT NULL,
  Password VARBINARY, -- TODO: use HASHBYTES function to insert data (https://www.mytecbits.com/microsoft/sql-server/sha-2-hashing)
  CreatedAt DATETIME NOT NULL,
  UpdatedAt DATETIME, 
);

CREATE TRIGGER dbo.SET_UPDATEDAT ON UserAuth AFTER UPDATE AS BEGIN
	UPDATE UserAuth SET UpdatedAt = CURRENT_TIMESTAMP; 
END


CREATE TABLE RentalLocation (
  RentalLocationID INT IDENTITY NOT NULL PRIMARY KEY,
  MaxCapacity INT,
  CurrentCapacity INT,
  StreetName VARCHAR(60) NOT NULL,
  City VARCHAR(40) NOT NULL,
  State VARCHAR(40) NOT NULL,
  Zipcode INT NOT NULL,
);


CREATE TABLE Vendor (
  VendorID INT IDENTITY NOT NULL PRIMARY KEY,
  Name VARCHAR(60),
  IsVerified BIT
);


CREATE TABLE CarTier (
  CarTierID INT IDENTITY NOT NULL PRIMARY KEY,
  TierName VARCHAR(40) NOT NULL,
  PricePerHour DECIMAL(6,2) NOT NULL,
  BasicInsurance DECIMAL(7,2) NOT NULL,
  PricePerMile DECIMAL(5,2) NOT NULL,
  CollisionCoverage DECIMAL(7,2) NOT NULL,
  BodyCoverage DECIMAL(7,2) NOT NULL,
  MedicalCoverage DECIMAL(7,2) NOT NULL,
);


CREATE TABLE Customer (
  CustomerID INT IDENTITY NOT NULL PRIMARY KEY,
  FirstName VARCHAR(250),
  MiddleName VARCHAR,
  LastName VARCHAR(250),
  Age AS dbo.CalculateAge(DateOfBirth),
  StreetName VARCHAR(60) NOT NULL,
  City VARCHAR(40) NOT NULL,
  State VARCHAR(40) NOT NULL,
  ZipCode INT,
  EmailID VARCHAR(40) NOT NULL,
  PhoneNumber VARCHAR NOT NULL,
  DateOfBirth DATE NOT NULL,
  LicenseNumber VARCHAR,
  LicenseExpiry DATE,
  IsVerified BIT,
  UserId INT NOT NULL REFERENCES UserAuth(UserId) 
);

ALTER TABLE Customer ADD CONSTRAINT checkValidEmailCustomer CHECK (dbo.ValidateEmail(EmailID) = 1);


CREATE TABLE CardDetails (
  CardID INT IDENTITY NOT NULL PRIMARY KEY,
  NameOnCard VARCHAR(60) NOT NULL,
  ExpiryDate DATETIME NOT NULL,
  PaymentMethod VARCHAR NOT NULL CHECK ([PaymentMethod] IN('Credit', 'Debit')),
  CVV INT NOT NULL,
  CardNumber VARCHAR(20) NOT NULL, -- TODO: unique together on CardNumber and CustomerID 
  IsPrimary BIT,
  CustomerID INT NOT NULL REFERENCES Customer(CustomerID),
);


CREATE TABLE Payment (
  PaymentID INT IDENTITY NOT NULL PRIMARY KEY,
  CardID INT NOT NULL REFERENCES CardDetails(CardID),
  BillingAmount DECIMAL(7,2) NOT NULL,
  ProcessedAt DATETIME,
  PaymentStatus VARCHAR NOT NULL CHECK ([PaymentStatus] IN('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')),
);


CREATE TABLE CustomerMembership (
  CustomerMembershipID INT IDENTITY NOT NULL PRIMARY KEY,
  StartDate DATETIME NOT NULL,
  EndDate AS dbo.CalculateMembershipEndDate(StartDate, MembershipID),
  isactive BIT,
  MembershipCost AS dbo.CalculateMembershipCost(MembershipID),
  CustomerID INT NOT NULL REFERENCES Customer(CustomerID),
  MembershipID INT NOT NULL REFERENCES Membership(MembershipID)
);


CREATE TABLE Car (
  CarID INT IDENTITY NOT NULL PRIMARY KEY,
  Model VARCHAR(60) NOT NULL,
  Make VARCHAR(60) NOT NULL,
  Color VARCHAR(20) NOT NULL,
  CarTierID INT NOT NULL REFERENCES CarTier(CarTierID),
  ManufacturingYear INT NOT NULL,
  SeatCapacity INT,
  InsuranceStatus VARCHAR NOT NULL CHECK ([InsuranceStatus] IN('ACTIVE', 'EXPIRED')),
  CarType VARCHAR, --TODO: make this a computed column from Cartier
  isAvailable BIT,
  RegistrationNumber VARCHAR NOT NULL,
  DisableFriendly BIT,
  RentalLocationID INT NOT NULL REFERENCES RentalLocation(RentalLocationID),
  MeterRating INT NOT NULL,
  VendorID INT NOT NULL REFERENCES Vendor(VendorID),
);





-- end table creation

CREATE TABLE Car maintenance (
  MaintenanceID INT,
  DueDate DATETIME,
  ServiceDate DATETIME,
  DueMiles FLOAT,
  CarID INT,
  PRIMARY KEY (MaintenanceID),
  CONSTRAINT FK_Car maintenance.CarID
    FOREIGN KEY (CarID)
      REFERENCES Car(VendorID)
);

CREATE TABLE Bookings (
  BookingID INT,
  CustomerID INT,
  Status ENUM,
  BookingStartTime DATETIME,
  BookingEndTime DATETIME,
  MeterStart  INT,
  MeterEnd INT,
  RentalAmount FLOAT,
  Penalty FLOAT,
  PaymentId INT,
  CarID INT,
  ActualStartTime DATETIME,
  ActualEndTime DATETIME,
  BookingRating INTEGER,
  PRIMARY KEY (BookingID),
  CONSTRAINT FK_Bookings.MeterStart 
    FOREIGN KEY (MeterStart )
      REFERENCES Customer(UserId)
);


CREATE TABLE Customer Service (
  ServiceID INT,
  ComplaintStatus ENUM,
  Rating INT,
  IssueTitle VARCHAR,
  IssueDescription VARCHAR,
  CreatedTime DATETIME,
  CloseTime DATETIME,
  BookingId INT,
  EmployeeId INT,
  PRIMARY KEY (ServiceID),
  CONSTRAINT FK_Customer Service.EmployeeId
    FOREIGN KEY (EmployeeId)
      REFERENCES Bookings(Penalty)
);

CREATE TABLE VendorTransactions (
  VendorID INT,
  VendorTransactionID INT,
  TransactionTime DATETIME,
  CarID INT,
  TransactionValue FLOAT,
  PRIMARY KEY (VendorTransactionID)
);

